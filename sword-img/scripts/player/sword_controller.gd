extends Node3D

@export var settings: SwordCombatSettings

@onready var sword_pivot: Node3D = $Camera3D/SwordPivot
@onready var camera: Camera3D = $Camera3D
@onready var sword_mesh: Node3D = $Camera3D/SwordPivot/SwordMesh
@onready var input_provider: SwordInputProvider = $MouseSwordInput
@onready var move_system: SwordMoveSystem = $SwordMoveSystem
@onready var move_animator: SwordMoveAnimator = $Camera3D/SwordMoveAnimator
@onready var sword_vfx: SwordVFX = $Camera3D/SwordVFX
@onready var player_health: SwordHealth = $SwordHealth
@onready var player_charge: SwordCharge = $SwordCharge
@onready var hit_detection: SwordHitDetection = $SwordHitDetection

signal health_changed(new_health: int)
signal charge_changed(points: int, max_points: int)
@warning_ignore("unused_signal")
signal died

var _pivot_rotation := Vector2.ZERO
var _sword_material: StandardMaterial3D
var _default_blade_color: Color

var health: int:
	get: return player_health.health


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(settings != null, "SwordController requires SwordCombatSettings")

	_sword_material = _resolve_sword_material()
	_default_blade_color = _sword_material.albedo_color

	sword_vfx.setup(camera, sword_mesh, sword_pivot)
	player_charge.setup(_sword_material, move_system)
	hit_detection.setup(self, camera, player_charge)

	move_system.move_changed.connect(_on_move_changed)
	move_system.slash_landed.connect(_on_slash_landed)
	move_system.charge_check = player_charge.can_charge

	move_animator.animation_finished.connect(_on_animation_finished)
	move_animator.slash_impact.connect(_on_slash_impact)
	move_animator.slash_pose_changed.connect(_on_slash_pose_changed)
	move_animator.charge_pose_changed.connect(_on_charge_pose_changed)

	# Wire health
	player_health.died.connect(_on_died)
	player_health.health_changed.connect(func(h): health_changed.emit(h))

	# Wire charge
	player_charge.charge_changed.connect(func(p, m): charge_changed.emit(p, m))

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
	player_charge.update_glow()

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

func _on_move_changed(new_move: SwordMoveSystem.Move) -> void:
	if new_move == SwordMoveSystem.Move.IDLE:
		_set_blade_color(_default_blade_color)
		return

	_set_blade_color(SwordMoveSystem.get_move_color(new_move))

	match new_move:
		SwordMoveSystem.Move.CHARGE:
			_start_move_animation(new_move)
		SwordMoveSystem.Move.BLOCK:
			_start_move_animation(new_move)
		_:
			if move_system.is_slash_move(new_move):
				_start_move_animation(new_move)


func _start_move_animation(new_move: SwordMoveSystem.Move) -> void:
	if move_system.is_slash_move(new_move):
		hit_detection.current_slash_hit = false

	match new_move:
		SwordMoveSystem.Move.CHARGE:
			move_animator.play_charge_enter(_current_pivot_rotation())
		SwordMoveSystem.Move.BLOCK:
			move_animator.play_block_enter(_current_pivot_rotation())
		_:
			if move_system.last_committed_snapshot.get("charged", false):
				hit_detection.fire_charged_projectile(new_move)
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

	if move_system.is_slash_move(finished_move):
		call_deferred("_check_whiff_miss")

	move_system.notify_animation_finished(finished_move, snapshot)


func _check_whiff_miss() -> void:
	if not hit_detection.current_slash_hit:
		DamageLabel.show_miss(get_tree().current_scene, camera)


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
	hit_detection.try_hit_enemies(SwordHitDetection.slash_lane_for_move(slash_move))


func _on_slash_pose_changed(progress: float, direction: Vector2) -> void:
	sword_vfx.on_slash_pose_changed(progress, direction)


func _on_charge_pose_changed(progress: float) -> void:
	sword_vfx.on_charge_pose_changed(progress)


# --- Health callbacks ---

func _on_died() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_input(false)


# --- Public API (for enemy scripts) ---

func take_damage(amount: int) -> void:
	player_health.take_damage(amount)
	sword_vfx.trigger_damage_shake(0.55)


func notify_slash_hit() -> void:
	hit_detection.current_slash_hit = true
	player_charge.notify_slash_hit()


func on_hit_landed() -> void:
	sword_vfx.trigger_impact_shake(0.4)
	sword_vfx.trigger_hitstop(0.06)


# --- Utility ---

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


func _set_blade_color(color: Color) -> void:
	_sword_material.albedo_color = color


func get_current_state_name() -> String:
	return SwordMoveSystem.get_state_name(move_system.state)
