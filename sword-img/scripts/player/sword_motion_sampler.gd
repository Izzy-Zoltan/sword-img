class_name SwordMotionSampler
extends Node

signal swing_started
signal swing_ended(snapshot: Dictionary)

enum State { IDLE, SWINGING }

@export var swing_start_speed_threshold: float = 2.5
@export var swing_end_speed_threshold: float = 0.9

var state: State = State.IDLE
var angular_speed: float = 0.0
var swing_direction: Vector2 = Vector2.ZERO
var swing_angle_accum: float = 0.0
var peak_speed: float = 0.0
var time_in_swing: float = 0.0


func add_motion_sample(rotation_delta: Vector2, delta: float) -> void:
	var safe_delta := maxf(delta, 0.0001)
	var speed := rotation_delta.length() / safe_delta
	angular_speed = speed

	if rotation_delta.length() > 0.001:
		swing_direction = rotation_delta.normalized()

	match state:
		State.IDLE:
			if speed >= swing_start_speed_threshold:
				_begin_swing(speed)
		State.SWINGING:
			time_in_swing += delta
			swing_angle_accum += rotation_delta.length()
			peak_speed = maxf(peak_speed, speed)
			if speed <= swing_end_speed_threshold:
				_end_swing()


func _begin_swing(speed: float) -> void:
	state = State.SWINGING
	swing_angle_accum = 0.0
	peak_speed = speed
	time_in_swing = 0.0
	swing_started.emit()


func _end_swing() -> void:
	var snapshot := get_snapshot()
	state = State.IDLE
	swing_ended.emit(snapshot)


func get_snapshot() -> Dictionary:
	var dominant_axis := "neutral"
	if swing_direction.length_squared() > 0.001:
		dominant_axis = "vertical" if absf(swing_direction.y) > absf(swing_direction.x) else "horizontal"

	return {
		"peak_speed": peak_speed,
		"swing_angle": swing_angle_accum,
		"swing_direction": swing_direction,
		"time_in_swing": time_in_swing,
		"dominant_axis": dominant_axis,
	}
