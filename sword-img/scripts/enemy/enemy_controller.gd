class_name EnemyController
extends CharacterBody3D

const EnemyAnimatorScript = preload("res://scripts/enemy/enemy_animator.gd")
const EnemyCombatScript = preload("res://scripts/enemy/enemy_combat.gd")
const EnemyMovementScript = preload("res://scripts/enemy/enemy_movement.gd")
const EnemyOutlineScript = preload("res://scripts/enemy/enemy_outline.gd")

@export var speed: float = 2
@export var max_health: int = 1
@export var gravity: float = 20.0
@export var attack_range: float = 3.0
@export var attack_stop_buffer: float = 0.3
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.3
@export var attack_windup: float = 0.6
@export var idle_before_attack: float = 0.2
@export var idle_between_attacks: float = 0.2
@export_enum("left", "center", "right") var spawn_lane := "center"

@onready var _animation_player: AnimationPlayer = $GoblinModel/AnimationPlayer
@onready var _goblin_mesh: MeshInstance3D = $GoblinModel/Armature/Skeleton3D/Cube_002

@warning_ignore("unused_signal")
signal died

var _stagger_timer: float = 0.0
var _is_dying: bool = false

var _animator: EnemyAnimator
var _combat: EnemyCombat
var _movement: EnemyMovement
var _outline: EnemyOutline

func _ready() -> void:
	floor_stop_on_slope = true

	_animator = EnemyAnimatorScript.new()
	_combat = EnemyCombatScript.new()
	_movement = EnemyMovementScript.new()
	_outline = EnemyOutlineScript.new()

	add_child(_animator)
	add_child(_combat)
	add_child(_movement)
	add_child(_outline)

	_animator.setup(_animation_player)
	_combat.setup(self, _animator, _goblin_mesh)
	_movement.setup(self)
	_outline.setup(self, $GoblinModel)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_outline.update(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if _is_dying:
		move_and_slide()
		return

	var player := _get_player()
	if player == null:
		move_and_slide()
		_animator.play_idle()
		return

	var is_moving := _movement.update(delta, player)
	if _stagger_timer > 0.0:
		return

	if is_moving:
		_animator.play_run()
		return

	_combat.update(player)

func _update_timers(delta: float) -> void:
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	_combat.update_timers(delta)

func take_hit(source_lane: String, damage: int = 1) -> void:
	_combat.take_hit(source_lane, damage)



func _get_player() -> Node3D:
	return get_tree().current_scene.get_node_or_null("Player") as Node3D
