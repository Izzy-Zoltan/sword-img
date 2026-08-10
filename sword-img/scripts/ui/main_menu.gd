extends Control

const FIELD_SCENE := preload("res://scenes/field.tscn")
const SLASH_THRESHOLD := 4.0

var _mouse_velocity_y := 0.0
var _last_mouse_y := 0.0
var _started := false
var _prompt_tween: Tween


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_prompt_pulse()


func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventMouseMotion:
		_mouse_velocity_y = event.relative.y

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if _started:
		return
	if _mouse_velocity_y > SLASH_THRESHOLD:
		_start_game()
	_mouse_velocity_y = 0.0


func _start_game() -> void:
	_started = true
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	var prompt := get_node("PromptLabel") as Label
	prompt.modulate.a = 0.0

	var overlay := ColorRect.new()
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): get_tree().change_scene_to_packed(FIELD_SCENE))


func _start_prompt_pulse() -> void:
	var prompt := get_node("PromptLabel") as Label
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(prompt, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
