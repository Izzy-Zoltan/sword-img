class_name MouseSwordInput
extends SwordInputProvider

@export var sensitivity: float = 0.004
@export var grip_mouse_button: MouseButton = MOUSE_BUTTON_RIGHT

var _rotation_delta: Vector2 = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotation_delta += event.relative * sensitivity


func get_rotation_delta() -> Vector2:
	var delta := _rotation_delta
	_rotation_delta = Vector2.ZERO
	return delta


func get_grip_strength() -> float:
	return 1.0 if Input.is_mouse_button_pressed(grip_mouse_button) else 0.0
