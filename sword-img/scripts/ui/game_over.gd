extends CanvasLayer

const FIELD_SCENE := preload("res://scenes/field.tscn")

var _active := false
var _accept_input := false
var _prompt_tween: Tween

@onready var score_value: Label = $Panel/ScoreValue
@onready var wave_value: Label = $Panel/WaveValue
@onready var combo_value: Label = $Panel/ComboValue
@onready var prompt: Label = $Panel/PromptLabel


func activate(score: int, wave: int, best_combo: int) -> void:
	_active = true
	_accept_input = false
	Engine.time_scale = 1.0
	score_value.text = "%d" % score
	wave_value.text = "%d" % wave
	combo_value.text = "%d" % best_combo
	visible = true
	_start_prompt_pulse()
	get_tree().create_timer(1.0).timeout.connect(func(): _accept_input = true)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _accept_input:
		return
	if event is InputEventMouseButton and event.pressed:
		_restart()
	elif event is InputEventKey and event.pressed:
		_restart()


func _restart() -> void:
	_active = false
	_accept_input = false
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	get_tree().change_scene_to_packed(FIELD_SCENE)


func _start_prompt_pulse() -> void:
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(prompt, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(prompt, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
