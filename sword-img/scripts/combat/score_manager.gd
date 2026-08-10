class_name ScoreManager
extends Node

signal score_changed(total: int)
signal combo_changed(combo: int, multiplier: float)
signal combo_dropped

const COMBO_TIMEOUT := 2.5
const BASE_KILL_SCORE := 100
const HIT_SCORE := 10
const CRIT_BONUS := 25

var score: int = 0
var combo: int = 0
var best_combo: int = 0
var _combo_timer: float = 0.0


func _process(delta: float) -> void:
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_drop_combo()


func register_hit() -> void:
	_extend_combo()
	_add_score(HIT_SCORE)


func register_crit(score_mult: float = 1.0) -> void:
	_extend_combo()
	_extend_combo()
	var crit_score := int((HIT_SCORE + CRIT_BONUS) * 2.0 * score_mult)
	_add_score(crit_score)


func register_kill(score_mult: float = 1.0, was_crit: bool = false) -> void:
	_extend_combo()
	var crit_mult := 2.0 if was_crit else 1.0
	var kill_score := int(BASE_KILL_SCORE * get_multiplier() * score_mult * crit_mult)
	_add_score(kill_score)


func get_multiplier() -> float:
	if combo < 3:
		return 1.0
	if combo < 6:
		return 1.5
	if combo < 10:
		return 2.0
	if combo < 15:
		return 3.0
	return 4.0


func get_combo_time_remaining() -> float:
	return maxf(_combo_timer, 0.0)


func _extend_combo() -> void:
	combo += 1
	_combo_timer = COMBO_TIMEOUT
	if combo > best_combo:
		best_combo = combo
	combo_changed.emit(combo, get_multiplier())


func break_combo() -> void:
	if combo > 0:
		_drop_combo()


func _drop_combo() -> void:
	combo = 0
	_combo_timer = 0.0
	combo_dropped.emit()
	combo_changed.emit(0, 1.0)


func _add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
