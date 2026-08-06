class_name SwordMoveAnimator
extends Node

signal animation_finished(move: SwordMoveSystem.Move, snapshot: Dictionary)
signal slash_impact(move: SwordMoveSystem.Move, snapshot: Dictionary)
signal slash_pose_changed(progress: float, direction: Vector2)
signal charge_pose_changed(progress: float)

@export var settings: SwordCombatSettings

@onready var sword_pivot: Node3D = $"../SwordPivot"

var _active_move: SwordMoveSystem.Move = SwordMoveSystem.Move.IDLE
var _stroke_snapshot: Dictionary = {}
var _tween: Tween
var _guard_rotation := Vector2.ZERO
var _releasing_block := false
var _slash_stance := Vector2.ZERO
var _slash_start_position := Vector3.ZERO
var _slash_direction := Vector2.ZERO
var _slash_peak_rotation := Vector2.ZERO
var _neutral_position := Vector3.ZERO
var _slash_return_rotation := Vector2.ZERO
var _slash_return_position := Vector3.ZERO
var _charge_start_rotation := Vector2.ZERO
var _charge_start_position := Vector3.ZERO


func _ready() -> void:
	assert(settings != null, "SwordMoveAnimator requires SwordCombatSettings")
	_neutral_position = sword_pivot.position


func play_slash(
	slash_move: SwordMoveSystem.Move,
	start_rotation: Vector2,
	stroke_direction: Vector2,
	stroke_snapshot: Dictionary,
) -> void:
	_cancel_tween()
	_active_move = slash_move
	_stroke_snapshot = stroke_snapshot
	_slash_stance = _clamp_rotation(start_rotation)
	_slash_start_position = sword_pivot.position

	var direction := stroke_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _default_direction_for_move(slash_move)

	_slash_direction = direction
	_slash_peak_rotation = _clamp_rotation(_slash_stance + direction * (settings.slash_arc_angle + settings.slash_follow_through))
	if slash_move == SwordMoveSystem.Move.SLASH_DOWN:
		# A down slash deliberately reaches the bottom of its available travel.
		_slash_peak_rotation.x = -settings.pitch_limit

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_apply_slash_pose, 0.0, 1.0, settings.slash_strike_time).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_slash_impact)
	_tween.tween_method(_apply_slash_pose, 1.0, 0.72, settings.slash_settle_time).set_ease(Tween.EASE_OUT)
	_slash_return_rotation = _slash_stance.lerp(_slash_peak_rotation, 0.72)
	_slash_return_position = _slash_position_at(0.72)
	_tween.tween_method(_apply_slash_return, 0.0, 1.0, settings.slash_recover_time).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func play_charge_enter(start_rotation: Vector2) -> void:
	_cancel_tween()
	_active_move = SwordMoveSystem.Move.CHARGE
	_stroke_snapshot = {}
	_charge_start_rotation = _clamp_rotation(start_rotation)
	_charge_start_position = sword_pivot.position
	_guard_rotation = _clamp_rotation(settings.neutral_rotation + settings.charge_stance_offset)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_apply_charge_pose, 0.0, 1.0, settings.charge_enter_time).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func play_block_enter(start_rotation: Vector2) -> void:
	_cancel_tween()
	_active_move = SwordMoveSystem.Move.BLOCK
	_stroke_snapshot = {}
	_releasing_block = false
	_guard_rotation = _clamp_rotation(start_rotation + settings.block_guard_offset)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_apply_rotation, start_rotation, _guard_rotation, settings.block_enter_time).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_block_enter_finished, CONNECT_ONE_SHOT)


func maintain_block() -> void:
	if _active_move != SwordMoveSystem.Move.BLOCK or _releasing_block:
		return

	_apply_rotation(_guard_rotation)


func release_block() -> void:
	if _active_move != SwordMoveSystem.Move.BLOCK or _releasing_block:
		return

	_releasing_block = true
	var start_rotation := _clamp_rotation(Vector2(sword_pivot.rotation.x, sword_pivot.rotation.y))
	var rest_rotation := start_rotation - settings.block_guard_offset

	_cancel_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_method(_apply_rotation, start_rotation, _clamp_rotation(rest_rotation), settings.block_exit_time).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.finished.connect(_on_tween_finished, CONNECT_ONE_SHOT)


func is_playing() -> bool:
	return _active_move != SwordMoveSystem.Move.IDLE


func _on_block_enter_finished() -> void:
	maintain_block()


func _on_tween_finished() -> void:
	var finished_move := _active_move
	var snapshot := _stroke_snapshot
	_active_move = SwordMoveSystem.Move.IDLE
	_stroke_snapshot = {}
	_releasing_block = false

	if _is_slash_move(finished_move) and is_instance_valid(sword_pivot):
		_apply_rotation(settings.neutral_rotation)
		sword_pivot.position = _neutral_position
	animation_finished.emit(finished_move, snapshot)


func _cancel_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


const SLASH_MOVES := [
	SwordMoveSystem.Move.SLASH_LEFT,
	SwordMoveSystem.Move.SLASH_RIGHT,
	SwordMoveSystem.Move.SLASH_DOWN,
]

func _default_direction_for_move(slash_move: SwordMoveSystem.Move) -> Vector2:
	match slash_move:
		SwordMoveSystem.Move.SLASH_LEFT:
			return Vector2.LEFT
		SwordMoveSystem.Move.SLASH_RIGHT:
			return Vector2.RIGHT
		SwordMoveSystem.Move.SLASH_DOWN:
			return Vector2.DOWN
		_:
			return Vector2.RIGHT


func _is_slash_move(sword_move: SwordMoveSystem.Move) -> bool:
	return sword_move in SLASH_MOVES


func _apply_rotation(rotation_xy: Vector2) -> void:
	sword_pivot.rotation = Vector3(rotation_xy.x, rotation_xy.y, 0.0)


func _apply_slash_pose(progress: float) -> void:
	var rotation_xy := _slash_stance.lerp(_slash_peak_rotation, progress)

	sword_pivot.position = _slash_position_at(progress)
	var roll := -_slash_direction.x * sin(progress * PI) * settings.slash_roll_angle
	sword_pivot.rotation = Vector3(rotation_xy.x, rotation_xy.y, roll)
	slash_pose_changed.emit(progress, _slash_direction)


func _apply_slash_return(progress: float) -> void:
	var rotation_xy := _slash_return_rotation.lerp(settings.neutral_rotation, progress)
	sword_pivot.rotation = Vector3(rotation_xy.x, rotation_xy.y, 0.0)
	sword_pivot.position = _slash_return_position.lerp(_neutral_position, progress)
	slash_pose_changed.emit(lerpf(0.72, 0.0, progress), _slash_direction)


func _apply_charge_pose(progress: float) -> void:
	var rotation_xy := _charge_start_rotation.lerp(_guard_rotation, progress)
	sword_pivot.rotation = Vector3(rotation_xy.x, rotation_xy.y, 0.0)
	var charge_position := _neutral_position + Vector3(0.0, 0.0, settings.charge_pullback)
	sword_pivot.position = _charge_start_position.lerp(charge_position, progress)
	charge_pose_changed.emit(progress)


func _slash_position_at(progress: float) -> Vector3:
	var base_progress := sin(progress * PI)
	var reach := base_progress * settings.slash_lunge_distance
	var lateral := base_progress * settings.slash_lateral_shift
	var horizontal_boost := 1.0
	var vertical_boost := 1.0

	if absf(_slash_direction.x) > 0.5:
		horizontal_boost = 3.2
		vertical_boost = 1.2
		reach *= 1.5
	else:
		reach *= 1.1

	lateral *= horizontal_boost
	var vertical_offset := _slash_direction.y * lateral * 0.45 * vertical_boost
	return _slash_start_position + Vector3(-_slash_direction.x * lateral, vertical_offset, -reach)


func _on_slash_impact() -> void:
	slash_impact.emit(_active_move, _stroke_snapshot)


func _clamp_rotation(rotation_xy: Vector2) -> Vector2:
	return Vector2(
		clampf(rotation_xy.x, -settings.pitch_limit, settings.pitch_limit),
		clampf(rotation_xy.y, -settings.yaw_limit, settings.yaw_limit),
	)
