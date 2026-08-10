class_name SwordMoveSystem
extends Node

signal move_changed(new_move: Move)
signal state_changed(new_state: State)
signal slash_landed(snapshot: Dictionary)

enum State {
	IDLE,
	BLOCKING,
	CHARGED,
	SLASHING,
}

enum Move {
	IDLE,
	BLOCK,
	CHARGE,
	SLASH_LEFT,
	SLASH_RIGHT,
	SLASH_DOWN,
}

const STATE_NAMES: Dictionary = {
	State.IDLE: "Idle",
	State.BLOCKING: "Blocking",
	State.CHARGED: "Charged",
	State.SLASHING: "Slashing",
}

const MOVE_NAMES: Dictionary = {
	Move.IDLE: "Idle",
	Move.BLOCK: "Block",
	Move.CHARGE: "Charge",
	Move.SLASH_LEFT: "Slash Left",
	Move.SLASH_RIGHT: "Slash Right",
	Move.SLASH_DOWN: "Slash Down",
}

const MOVE_COLORS: Dictionary = {
	Move.IDLE: Color(0.72, 0.76, 0.82),
	Move.BLOCK: Color(0.55, 0.65, 0.85),
	Move.CHARGE: Color(0.35, 0.82, 1.0),
	Move.SLASH_LEFT: Color(0.95, 0.55, 0.45),
	Move.SLASH_RIGHT: Color(0.95, 0.55, 0.45),
	Move.SLASH_DOWN: Color(0.95, 0.7, 0.35),
}

const SLASH_MOVES := [Move.SLASH_LEFT, Move.SLASH_RIGHT, Move.SLASH_DOWN]

@export var settings: SwordCombatSettings

var state: State = State.IDLE
var move: Move = Move.IDLE
var pivot_angle: Vector2 = Vector2.ZERO
var last_committed_snapshot: Dictionary = {}
var last_stroke_direction: Vector2 = Vector2.ZERO
var last_stroke_start_rotation: Vector2 = Vector2.ZERO

var _stroke_accum := Vector2.ZERO
var _peak_speed := 0.0
var _tracking_slash := false
var _pending_move: Move = Move.IDLE
var _charged := false
var charge_check: Callable = Callable()


static func get_display_name(sword_move: Move) -> String:
	return MOVE_NAMES.get(sword_move, "Unknown")


static func get_state_name(sword_state: State) -> String:
	return STATE_NAMES.get(sword_state, "Unknown")


static func get_move_color(sword_move: Move) -> Color:
	return MOVE_COLORS.get(sword_move, MOVE_COLORS[Move.IDLE])


func _ready() -> void:
	assert(settings != null, "SwordMoveSystem requires SwordCombatSettings")


func can_accept_input() -> bool:
	return state == State.IDLE or state == State.CHARGED


func is_blocking() -> bool:
	return state == State.BLOCKING


func is_slashing() -> bool:
	return state == State.SLASHING


func is_charged() -> bool:
	return _charged


func is_slash_move(sword_move: Move) -> bool:
	return (
		sword_move == Move.SLASH_LEFT
		or sword_move == Move.SLASH_RIGHT
		or sword_move == Move.SLASH_DOWN
	)


func is_hitbox_active() -> bool:
	return is_slash_move(move)


func update_gestures(
	pivot_rotation: Vector2,
	stroke_start_rotation: Vector2,
	rotation_delta: Vector2,
	delta: float,
	blocking_input: bool,
) -> void:
	pivot_angle = pivot_rotation

	if not can_accept_input():
		if blocking_input and _pending_move == Move.IDLE:
			_pending_move = Move.BLOCK
		return

	if blocking_input and _pending_move == Move.IDLE and state != State.CHARGED:
		if charge_check.is_valid() and charge_check.call():
			_commit_move(Move.CHARGE)
		return

	var speed := rotation_delta.length() / maxf(delta, 0.0001)

	if speed >= settings.slash_start_speed:
		if not _tracking_slash:
			_tracking_slash = true
			_stroke_accum = Vector2.ZERO
			_peak_speed = 0.0
			last_stroke_start_rotation = stroke_start_rotation

		_stroke_accum += rotation_delta
		_peak_speed = maxf(_peak_speed, speed)

		if _stroke_accum.length() >= settings.slash_min_angle:
			_try_commit_slash()
	elif _tracking_slash:
		_try_commit_slash()
		_reset_slash_tracking()
	elif blocking_input:
		_commit_move(Move.BLOCK)


func notify_animation_finished(finished_move: Move, snapshot: Dictionary = {}) -> void:
	if move != finished_move:
		return
	if finished_move == Move.CHARGE:
		return

	if is_slash_move(finished_move):
		slash_landed.emit(snapshot)

	if _pending_move != Move.IDLE:
		var queued_move := _pending_move
		_pending_move = Move.IDLE
		_commit_move(queued_move)
		return

	_transition_to_state(State.IDLE, Move.IDLE)


func get_slash_snapshot(stroke: Vector2, peak: float, slash_move: Move) -> Dictionary:
	var dominant_axis := "neutral"
	if stroke.length_squared() > 0.001:
		dominant_axis = "vertical" if absf(stroke.y) > absf(stroke.x) else "horizontal"

	return {
		"move": get_display_name(slash_move),
		"peak_speed": peak,
		"swing_angle": stroke.length(),
		"dominant_axis": dominant_axis,
	}


func _try_commit_slash() -> void:
	var direction := _stroke_accum.normalized()
	var slash_move: Move
	if absf(direction.x) >= settings.cardinal_precision:
		slash_move = Move.SLASH_RIGHT if direction.x >= 0.0 else Move.SLASH_LEFT
	elif direction.y >= settings.cardinal_precision:
		slash_move = Move.SLASH_DOWN
	elif direction.y <= -settings.cardinal_precision:
		if state != State.CHARGED:
			if charge_check.is_valid() and charge_check.call():
				_commit_move(Move.CHARGE)
		else:
			_reset_slash_tracking()
		return
	else:
		_reset_slash_tracking()
		return

	last_stroke_direction = Vector2(_stroke_accum.y, -_stroke_accum.x)
	_commit_move(slash_move)


func _commit_move(new_move: Move) -> void:
	last_committed_snapshot = {}
	if is_slash_move(new_move):
		last_committed_snapshot = get_slash_snapshot(_stroke_accum, _peak_speed, new_move)
		last_committed_snapshot["charged"] = _charged
		_charged = false
	elif new_move == Move.CHARGE:
		_charged = true

	_reset_slash_tracking()
	_enter_move(new_move)


func _enter_move(new_move: Move) -> void:
	var next_state := _state_for_move(new_move)
	_transition_to_state(next_state, new_move)


func _state_for_move(sword_move: Move) -> State:
	if is_slash_move(sword_move):
		return State.SLASHING
	if sword_move == Move.BLOCK:
		return State.BLOCKING
	if sword_move == Move.CHARGE:
		return State.CHARGED
	return State.IDLE


func _transition_to_state(next_state: State, next_move: Move) -> void:
	if move == next_move and state == next_state and state != State.IDLE:
		return

	state = next_state
	move = next_move
	move_changed.emit(next_move)
	state_changed.emit(state)


func _reset_slash_tracking() -> void:
	_tracking_slash = false
	_stroke_accum = Vector2.ZERO
	_peak_speed = 0.0
