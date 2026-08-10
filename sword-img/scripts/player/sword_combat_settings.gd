class_name SwordCombatSettings
extends Resource

@export_group("Look")
@export var pitch_limit: float = 1.4
@export var yaw_limit: float = 1.8
@export var rotation_smoothing: float = 20.0
@export var neutral_rotation: Vector2 = Vector2(0.12, -0.08)
@export var slash_camera_shift: float = 0.045
@export var slash_camera_tilt: float = 0.055
@export var charge_camera_pullback: float = 0.075

@export_group("Slash")
@export var slash_start_speed: float = 2.0
@export var slash_min_angle: float = 0.32
@export_range(0.5, 1.0, 0.05) var cardinal_precision: float = 0.72
@export var slash_afterimage_lifetime: float = 0.12
@export var slash_afterimage_alpha: float = 0.25
@export var slash_strike_time: float = 0.14
@export var slash_settle_time: float = 0.09
@export var slash_recover_time: float = 0.24
@export var slash_arc_angle: float = 0.86
@export var slash_follow_through: float = 0.14
@export var slash_lunge_distance: float = 0.12
@export var slash_lateral_shift: float = 0.055
@export var slash_roll_angle: float = 0.12

@export_group("Charge and Block")
@export var charge_enter_time: float = 0.16
@export var charge_stance_offset: Vector2 = Vector2(0.18, -0.14)
@export var charge_pullback: float = 0.23
@export var charge_raise_height: float = 0.2
@export var block_enter_time: float = 0.16
@export var block_exit_time: float = 0.22
@export var block_guard_offset: Vector2 = Vector2(0.22, -0.05)
