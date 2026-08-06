extends Node3D

const PROJECTILE_COLLIDER_SIZE := Vector3(1.6, 1.45, 0.3)
const PROJECTILE_OFFSET := 0.7

@export var settings: SwordCombatSettings

@onready var sword_pivot: Node3D = $Camera3D/SwordPivot
@onready var camera: Camera3D = $Camera3D
@onready var sword_mesh: MeshInstance3D = $Camera3D/SwordPivot/SwordMesh
@onready var sword_hitbox: Area3D = $Camera3D/SwordPivot/SwordHitbox
@onready var input_provider: SwordInputProvider = $MouseSwordInput
@onready var move_system: SwordMoveSystem = $SwordMoveSystem
@onready var move_animator: SwordMoveAnimator = $Camera3D/SwordMoveAnimator
@onready var sword_vfx: SwordVFX = $Camera3D/SwordVFX
@onready var _sword_material: StandardMaterial3D = sword_mesh.get_surface_override_material(0) as StandardMaterial3D

var _pivot_rotation := Vector2.ZERO
var _default_blade_color: Color
var _afterimages: Array[Dictionary] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_default_blade_color = _sword_material.albedo_color
	assert(settings != null, "SwordController requires SwordCombatSettings")

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
				_start_move_animation(new_move)


func _start_move_animation(new_move: SwordMoveSystem.Move) -> void:
	match new_move:
		SwordMoveSystem.Move.CHARGE:
			move_animator.play_charge_enter(_current_pivot_rotation())
		SwordMoveSystem.Move.BLOCK:
			move_animator.play_block_enter(_current_pivot_rotation())
		_:
			if move_system.last_committed_snapshot.get("charged", false):
				_fire_charged_projectile()
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
	move_system.notify_animation_finished(finished_move, snapshot)


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


func _fire_charged_projectile() -> void:
	var projectile := ChargedProjectile.new()

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = PROJECTILE_COLLIDER_SIZE
	collider.shape = shape
	projectile.add_child(collider)

	get_tree().current_scene.add_child(projectile)
	var direction := -sword_pivot.global_transform.basis.z
	projectile.global_position = sword_pivot.global_position + direction * PROJECTILE_OFFSET
	projectile.launch(direction)


func _set_blade_color(color: Color) -> void:
	_sword_material.albedo_color = color


func get_current_state_name() -> String:
	return SwordMoveSystem.get_state_name(move_system.state)
