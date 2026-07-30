extends Node3D

@export var pitch_limit: float = 1.4
@export var yaw_limit: float = 1.8
@export var rotation_smoothing: float = 20.0

@onready var sword_pivot: Node3D = $Camera3D/SwordPivot
@onready var sword_hitbox: Area3D = $Camera3D/SwordPivot/SwordHitbox
@onready var input_provider: SwordInputProvider = $MouseSwordInput
@onready var motion_sampler: SwordMotionSampler = $SwordMotionSampler

var _pivot_rotation := Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motion_sampler.swing_started.connect(_on_swing_started)
	motion_sampler.swing_ended.connect(_on_swing_ended)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var rot_delta := input_provider.get_rotation_delta()

	_pivot_rotation.x = clampf(_pivot_rotation.x - rot_delta.y, -pitch_limit, pitch_limit)
	_pivot_rotation.y = clampf(_pivot_rotation.y - rot_delta.x, -yaw_limit, yaw_limit)

	var target := Vector3(_pivot_rotation.x, _pivot_rotation.y, 0.0)
	sword_pivot.rotation = sword_pivot.rotation.lerp(target, 1.0 - exp(-rotation_smoothing * delta))

	motion_sampler.add_motion_sample(rot_delta, delta)


func _on_swing_started() -> void:
	sword_hitbox.set_active(true)


func _on_swing_ended(snapshot: Dictionary) -> void:
	sword_hitbox.set_active(false)
	print(
		"Swing ended | speed: %.2f | angle: %.2f | axis: %s" % [
			snapshot.peak_speed,
			snapshot.swing_angle,
			snapshot.dominant_axis,
		]
	)
