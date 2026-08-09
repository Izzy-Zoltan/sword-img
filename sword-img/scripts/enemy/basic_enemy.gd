class_name BasicEnemy
extends CharacterBody3D

const EnemyAnimatorScript = preload("res://scripts/enemy/enemy_animator.gd")
const EnemyCombatScript = preload("res://scripts/enemy/enemy_combat.gd")
const EnemyMovementScript = preload("res://scripts/enemy/enemy_movement.gd")

signal died

@export var speed: float = 2.2
@export var max_health: int = 1
@export var gravity: float = 20.0
@export var attack_range: float = 3.0
@export var attack_stop_buffer: float = 0.6
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.35
@export var idle_before_attack: float = 0.2
@export var idle_between_attacks: float = 0.2
@export_enum("left", "center", "right") var spawn_lane := "center"

@onready var hurt_area: Area3D = $HurtArea
@onready var _animation_player: AnimationPlayer = $GoblinModel/AnimationPlayer
@onready var _goblin_mesh: MeshInstance3D = $GoblinModel/Armature/Skeleton3D/Cube_002

var _health: int
var _hit_cooldown: float = 0.0
var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _idle_timer: float = 0.0
var _pre_attack_idle_timer: float = 0.0
var _is_winding_up: bool = false
var _is_idling_before_attack: bool = false
var _flash_timer: float = 0.0
var _stagger_timer: float = 0.0
var _is_dying: bool = false

var _animator: EnemyAnimator
var _combat: EnemyCombat
var _movement: EnemyMovement

func _ready() -> void:
	_health = max_health
	floor_stop_on_slope = true

	_animator = EnemyAnimatorScript.new()
	_combat = EnemyCombatScript.new()
	_movement = EnemyMovementScript.new()

	add_child(_animator)
	add_child(_combat)
	add_child(_movement)

	_animator.setup(_animation_player)
	_combat.setup(self, _animator, _goblin_mesh)
	_combat.connect_hurt_area(hurt_area)
	_movement.setup(self)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	var player := _get_player()
	if player == null:
		_animator.play_idle()
		return

	var is_moving := _movement.update(delta, player)
	if _stagger_timer > 0.0:
		return

	if is_moving:
		_animator.play_run()
		return

	_combat.update(delta, player)

func _get_player() -> Node3D:
	return get_tree().current_scene.get_node_or_null("Player") as Node3D
