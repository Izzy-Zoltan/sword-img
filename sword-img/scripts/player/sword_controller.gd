extends Node3D

const PROJECTILE_COLLIDER_SIZE := Vector3(1.6, 1.45, 0.3)
const PROJECTILE_OFFSET := 0.7

@export var settings: SwordCombatSettings
@export var max_health: int = 5

signal health_changed(new_health)
signal died

var health: int

@onready var sword_pivot: Node3D = $Camera3D/SwordPivot
@onready var camera: Camera3D = $Camera3D
@onready var sword_mesh: Node3D = $Camera3D/SwordPivot/SwordMesh
@onready var sword_hitbox: Area3D = $Camera3D/SwordPivot/SwordHitbox
@onready var input_provider: SwordInputProvider = $MouseSwordInput
@onready var move_system: SwordMoveSystem = $SwordMoveSystem
@onready var move_animator: SwordMoveAnimator = $Camera3D/SwordMoveAnimator
@onready var sword_vfx: SwordVFX = $Camera3D/SwordVFX
@onready var _sword_material: StandardMaterial3D = null
@onready var font = load("res://Assets/PixelifySans-Bold.ttf")

var _pivot_rotation := Vector2.ZERO
var _default_blade_color: Color
var _afterimages: Array[Dictionary] = []
var _current_slash_hit: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(settings != null, "SwordController requires SwordCombatSettings")

	health = max_health
	health_changed.emit(health)

	_sword_material = _resolve_sword_material()
	_default_blade_color = _sword_material.albedo_color

	sword_vfx.setup(camera, sword_mesh, sword_pivot)

	move_system.move_changed.connect(_on_move_changed)
	move_system.slash_landed.connect(_on_slash_landed)
	move_animator.animation_finished.connect(_on_animation_finished)
	move_animator.slash_impact.connect(_on_slash_impact)
	move_animator.slash_pose_changed.connect(_on_slash_pose_changed)
	move_animator.charge_pose_changed.connect(_on_charge_pose_changed)

	_on_move_changed(move_system.move)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	var rot_delta := input_provider.get_rotation_delta()
	var blocking_input := input_provider.get_grip_strength() > 0.5

	if move_system.can_accept_input() and not move_animator.is_playing():
		_apply_mouse_rotation(rot_delta, blocking_input, delta)
	elif move_system.is_blocking():
		_update_block_state(blocking_input)

	if move_system.can_accept_input() and not move_animator.is_playing():
		_pivot_rotation = _current_pivot_rotation()


func _process(delta: float) -> void:
	sword_vfx.tick(delta)


func _toggle_mouse_capture() -> void:
	var next_mode := Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		next_mode = Input.MOUSE_MODE_VISIBLE
	Input.mouse_mode = next_mode


func _resolve_sword_material() -> StandardMaterial3D:
	var mesh_instance := _find_mesh_instance(sword_mesh)
	if mesh_instance == null:
		push_error("Sword model does not contain a MeshInstance3D")
		return StandardMaterial3D.new()

	var material := mesh_instance.get_surface_override_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)

	return material as StandardMaterial3D


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found

	return null


func _current_pivot_rotation() -> Vector2:
	return Vector2(sword_pivot.rotation.x, sword_pivot.rotation.y)


func _apply_mouse_rotation(rot_delta: Vector2, blocking_input: bool, delta: float) -> void:
	var stance_before_input := _current_pivot_rotation()
	_pivot_rotation.x = clampf(_pivot_rotation.x - rot_delta.y, -settings.pitch_limit, settings.pitch_limit)
	_pivot_rotation.y = clampf(_pivot_rotation.y - rot_delta.x, -settings.yaw_limit, settings.yaw_limit)

	var target := Vector3(_pivot_rotation.x, _pivot_rotation.y, 0.0)
	sword_pivot.rotation = sword_pivot.rotation.lerp(target, 1.0 - exp(-settings.rotation_smoothing * delta))

	move_system.update_gestures(_pivot_rotation, stance_before_input, rot_delta, delta, blocking_input)


func _update_block_state(blocking_input: bool) -> void:
	if blocking_input:
		move_animator.maintain_block()
	else:
		move_animator.release_block()


func _tick_afterimages(delta: float) -> void:
	for index in range(_afterimages.size() - 1, -1, -1):
		var afterimage := _afterimages[index]
		afterimage.life -= delta
		var material := afterimage.material as StandardMaterial3D
		var life_ratio := maxf(afterimage.life / maxf(settings.slash_afterimage_lifetime, 0.001), 0.0)
		var color := material.albedo_color
		color.a = settings.slash_afterimage_alpha * life_ratio
		material.albedo_color = color
		material.emission_energy_multiplier = 2.0 * material.albedo_color.a
		if afterimage.life <= 0.0:
			afterimage.mesh.queue_free()
			_afterimages.remove_at(index)


func notify_slash_hit() -> void:
	_current_slash_hit = true


func _on_move_changed(new_move: SwordMoveSystem.Move) -> void:
	if new_move == SwordMoveSystem.Move.IDLE:
		_set_blade_color(_default_blade_color)
		sword_hitbox.set_active(false)
		return

	_set_blade_color(SwordMoveSystem.get_move_color(new_move))

	match new_move:
		SwordMoveSystem.Move.CHARGE:
			sword_hitbox.set_active(false)
			_start_move_animation(new_move)
		SwordMoveSystem.Move.BLOCK:
			_start_move_animation(new_move)
		_:
			sword_hitbox.set_active(move_system.is_hitbox_active())
			if move_system.is_slash_move(new_move):
				sword_hitbox.set_slash_lane(_slash_lane_for_move(new_move))
				_start_move_animation(new_move)


func _start_move_animation(new_move: SwordMoveSystem.Move) -> void:
	if move_system.is_slash_move(new_move):
		_current_slash_hit = false

	match new_move:
		SwordMoveSystem.Move.CHARGE:
			move_animator.play_charge_enter(_current_pivot_rotation())
		SwordMoveSystem.Move.BLOCK:
			move_animator.play_block_enter(_current_pivot_rotation())
		_:
			if move_system.last_committed_snapshot.get("charged", false):
				_fire_charged_projectile(new_move)
			move_animator.play_slash(
				new_move,
				_current_pivot_rotation(),
				move_system.last_stroke_direction,
				move_system.last_committed_snapshot,
			)


func _on_animation_finished(finished_move: SwordMoveSystem.Move, snapshot: Dictionary) -> void:
	if finished_move != SwordMoveSystem.Move.CHARGE:
		sword_vfx.reset_camera_pose()
	_pivot_rotation = _current_pivot_rotation()

	if move_system.is_slash_move(finished_move) and not _current_slash_hit:
		_trigger_whiff_miss()

	move_system.notify_animation_finished(finished_move, snapshot)


func _trigger_whiff_miss() -> void:
	var label := Label3D.new()
	var forward := -camera.global_transform.basis.z
	label.global_position = camera.global_position + forward * 2.2 + Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.15), 0)
	label.text = "MISS"
	label.font = font
	label.font_size = 42
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.7, 0.8, 0.9, 0.8)
	label.outline_render_priority = 1
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.8)

	get_tree().current_scene.add_child(label)

	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.6, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.1)
	tween.chain().tween_callback(label.queue_free)

func _on_slash_landed(snapshot: Dictionary) -> void:
	print(
		"Slash finished | move: %s | speed: %.2f | angle: %.2f | axis: %s | charged: %s" % [
			snapshot.move,
			snapshot.peak_speed,
			snapshot.swing_angle,
			snapshot.dominant_axis,
			snapshot.get("charged", false),
		]
	)


func _on_slash_impact(slash_move: SwordMoveSystem.Move, _snapshot: Dictionary) -> void:
	sword_vfx.on_slash_impact(SwordMoveSystem.get_move_color(slash_move))


func _on_slash_pose_changed(progress: float, direction: Vector2) -> void:
	sword_vfx.on_slash_pose_changed(progress, direction)


func _on_charge_pose_changed(progress: float) -> void:
	sword_vfx.on_charge_pose_changed(progress)


func _fire_charged_projectile(slash_move: SwordMoveSystem.Move) -> void:
	var projectile := ChargedProjectile.new()

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = PROJECTILE_COLLIDER_SIZE
	collider.shape = shape
	projectile.add_child(collider)

	get_tree().current_scene.add_child(projectile)
	var direction := _projectile_direction_for_slash(slash_move)
	var spawn_origin := global_position + Vector3.UP * 1.0
	projectile.global_position = spawn_origin + direction * PROJECTILE_OFFSET
	projectile.launch(direction, _slash_lane_for_move(slash_move))


func _slash_lane_for_move(slash_move: SwordMoveSystem.Move) -> String:
	match slash_move:
		SwordMoveSystem.Move.SLASH_LEFT:
			return "left"
		SwordMoveSystem.Move.SLASH_RIGHT:
			return "right"
		_:
			return "center"


func _projectile_direction_for_slash(slash_move: SwordMoveSystem.Move) -> Vector3:
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var spawn_dist := 8.0
	var side_offset := 3.0
	var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
	if spawner != null:
		if "spawn_distance" in spawner:
			spawn_dist = spawner.spawn_distance
		if "side_lane_offset" in spawner:
			side_offset = spawner.side_lane_offset

	var lane_offset := 0.0
	match slash_move:
		SwordMoveSystem.Move.SLASH_LEFT:
			lane_offset = -side_offset
		SwordMoveSystem.Move.SLASH_RIGHT:
			lane_offset = side_offset
		_:
			lane_offset = 0.0

	var direction := forward * spawn_dist + right * lane_offset
	return direction.normalized()


func _set_blade_color(color: Color) -> void:
	_sword_material.albedo_color = color


func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health = max(health - amount, 0)
	health_changed.emit(health)
	if health <= 0:
		died.emit()
		set_process(false)
		set_physics_process(false)
		set_process_input(false)


func get_current_state_name() -> String:
	return SwordMoveSystem.get_state_name(move_system.state)
