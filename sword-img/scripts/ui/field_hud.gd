extends Node3D

@onready var state_label: Label = $CanvasLayer/StateLabel
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var player: Node3D = $Player
var move_system: SwordMoveSystem


func _ready() -> void:
	move_system = player.get_node("SwordMoveSystem") as SwordMoveSystem
	move_system.state_changed.connect(_on_state_changed)
	player.health_changed.connect(_on_health_changed)
	_on_state_changed(move_system.state)
	_on_health_changed(_get_player_health())


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
