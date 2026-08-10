extends Node3D

const FIELD_SCENE := preload("res://scenes/field.tscn")
const FONT := preload("res://Assets/PixelifySans-Bold.ttf")
const SLASH_THRESHOLD := 0.02

@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var wave_label: Label = $CanvasLayer/WaveLabel
@onready var enemies_label: Label = $CanvasLayer/EnemiesLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var player: Node3D = $Player
@onready var wave_manager: WaveManager = $WaveManager
@onready var score_manager: ScoreManager = $ScoreManager

var move_system: SwordMoveSystem
var _game_over := false
var _game_over_accept := false
var _game_over_mouse_y := 0.0


func _ready() -> void:
	move_system = player.get_node("SwordMoveSystem") as SwordMoveSystem
	player.connect("health_changed", _on_health_changed)
	player.connect("died", _on_player_died)
	_on_health_changed(_get_player_health())

	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	wave_manager.intermission_started.connect(_on_intermission_started)
	wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)

	score_manager.score_changed.connect(_on_score_changed)
	score_manager.combo_changed.connect(_on_combo_changed)
	score_manager.combo_dropped.connect(_on_combo_dropped)

	wave_label.text = "Wave: --"
	enemies_label.text = "Get Ready!"
	score_label.text = "Score: 0"
	combo_label.text = ""


func _input(event: InputEvent) -> void:
	if not _game_over or not _game_over_accept:
		return
	if event is InputEventMouseMotion:
		_game_over_mouse_y += event.relative.y * 0.004
		if _game_over_mouse_y > SLASH_THRESHOLD:
			get_tree().change_scene_to_packed(FIELD_SCENE)


func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


func _get_player_health() -> int:
	if player.has_method("get_health"):
		return player.get_health()
	if player.has_method("take_damage"):
		return player.health
	return 0


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave: %d" % wave_number
	enemies_label.text = "Enemies: %d" % wave_manager.total_wave_enemies


func _on_wave_completed(_wave_number: int) -> void:
	enemies_label.text = "Wave Clear!"


func _on_enemies_remaining_changed(remaining: int) -> void:
	enemies_label.text = "Enemies: %d" % remaining


func _on_intermission_started(_seconds: float) -> void:
	enemies_label.text = "Next wave incoming..."


func _on_all_waves_cleared() -> void:
	wave_label.text = "ALL CLEAR!"
	enemies_label.text = "You Win!"


func _on_score_changed(total: int) -> void:
	score_label.text = "Score: %d" % total


func _on_combo_changed(combo: int, multiplier: float) -> void:
	if combo < 2:
		combo_label.text = ""
		return
	if multiplier > 1.0:
		combo_label.text = "%d Combo (x%.1f)" % [combo, multiplier]
	else:
		combo_label.text = "%d Combo" % combo


func _on_combo_dropped() -> void:
	combo_label.text = ""


func _on_player_died() -> void:
	_game_over = true
	_game_over_accept = false
	_game_over_mouse_y = 0.0
	Engine.time_scale = 1.0
	_show_game_over_overlay()
	get_tree().create_timer(1.0).timeout.connect(func(): _game_over_accept = true)


func _show_game_over_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)

	var bg := ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.01, 0.01, 0.03, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.93, 1.0).set_trans(Tween.TRANS_QUAD)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchors_preset = Control.PRESET_CENTER_TOP
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -250.0
	title.offset_right = 250.0
	title.offset_top = 80.0
	title.offset_bottom = 160.0
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 10)
	title.modulate.a = 0.0
	canvas.add_child(title)

	var score_text := Label.new()
	score_text.text = "Score: %d" % score_manager.score
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_text.anchors_preset = Control.PRESET_CENTER_TOP
	score_text.anchor_left = 0.5
	score_text.anchor_right = 0.5
	score_text.offset_left = -200.0
	score_text.offset_right = 200.0
	score_text.offset_top = 200.0
	score_text.offset_bottom = 260.0
	score_text.add_theme_font_override("font", FONT)
	score_text.add_theme_font_size_override("font_size", 42)
	score_text.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	score_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	score_text.add_theme_constant_override("outline_size", 8)
	score_text.modulate.a = 0.0
	canvas.add_child(score_text)

	var stats_text := Label.new()
	stats_text.text = "Wave: %d    Best Combo: %d" % [wave_manager.current_wave, score_manager.best_combo]
	stats_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_text.anchors_preset = Control.PRESET_CENTER_TOP
	stats_text.anchor_left = 0.5
	stats_text.anchor_right = 0.5
	stats_text.offset_left = -250.0
	stats_text.offset_right = 250.0
	stats_text.offset_top = 280.0
	stats_text.offset_bottom = 320.0
	stats_text.add_theme_font_override("font", FONT)
	stats_text.add_theme_font_size_override("font_size", 24)
	stats_text.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
	stats_text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	stats_text.add_theme_constant_override("outline_size", 6)
	stats_text.modulate.a = 0.0
	canvas.add_child(stats_text)

	var prompt := Label.new()
	prompt.text = "- Slash Down to Restart -"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchors_preset = Control.PRESET_CENTER_BOTTOM
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -250.0
	prompt.offset_right = 250.0
	prompt.offset_top = -120.0
	prompt.offset_bottom = -60.0
	prompt.add_theme_font_override("font", FONT)
	prompt.add_theme_font_size_override("font_size", 28)
	prompt.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.modulate.a = 0.0
	canvas.add_child(prompt)

	var fade := create_tween()
	fade.tween_property(title, "modulate:a", 1.0, 0.6).set_delay(0.5).set_trans(Tween.TRANS_QUAD)
	fade.tween_property(score_text, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD)
	fade.tween_property(stats_text, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD)
	fade.tween_property(prompt, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD)

	var pulse := create_tween().set_loops()
	pulse.tween_interval(2.5)
	pulse.tween_property(prompt, "modulate:a", 0.3, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
