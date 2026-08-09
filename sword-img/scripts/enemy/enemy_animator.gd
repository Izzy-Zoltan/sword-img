class_name EnemyAnimator
extends Node

var _animation_player: AnimationPlayer

func setup(animation_player: AnimationPlayer) -> void:
	_animation_player = animation_player

func play_run() -> void:
	if _animation_player == null:
		return
	var animation_name := _pick_animation(["Run", "run", "Walk", "walk", "Move", "move"])
	if animation_name == "":
		animation_name = _pick_animation(_animation_player.get_animation_list())
	if animation_name != "" and _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)

func play_idle() -> void:
	if _animation_player == null:
		return
	var animation_name := _pick_animation(["Idle", "idle", "Rest", "rest", "Stand", "stand"])
	if animation_name == "":
		_animation_player.stop()
		return
	if _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)

func play_attack(force: bool = false) -> void:
	if _animation_player == null:
		return
	var animation_name := _pick_animation(["Attack", "attack", "Slash", "slash", "Action", "action", "Hit", "hit"])
	if animation_name == "":
		play_idle()
		return
	if force or _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)

func _pick_animation(candidates: Array) -> StringName:
	for candidate in candidates:
		var name_string := String(candidate)
		if _animation_player.has_animation(name_string):
			return StringName(name_string)
	return ""
