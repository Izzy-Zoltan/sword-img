extends Node3D

@onready var state_label: Label = $CanvasLayer/StateLabel
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var wave_label: Label = $CanvasLayer/WaveLabel
@onready var enemies_label: Label = $CanvasLayer/EnemiesLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var combo_label: Label = $CanvasLayer/ComboLabel
@onready var player: Node3D = $Player
@onready var wave_manager: WaveManager = $WaveManager
@onready var score_manager: ScoreManager = $ScoreManager

var move_system: SwordMoveSystem


func _ready() -> void:
	move_system = player.get_node("SwordMoveSystem") as SwordMoveSystem
	move_system.state_changed.connect(_on_state_changed)
	player.connect("health_changed", _on_health_changed)
	_on_state_changed(move_system.state)
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


func _on_state_changed(new_state: SwordMoveSystem.State) -> void:
	if new_state == SwordMoveSystem.State.SLASHING:
		state_label.text = "State: %s" % SwordMoveSystem.get_display_name(move_system.move)
		return
	state_label.text = "State: %s" % SwordMoveSystem.get_state_name(new_state)


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
