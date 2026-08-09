extends Node

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var max_active_enemies: int = 1
@export var spawn_distance: float = 8.0
@export var side_lane_offset: float = 3.0

const SPAWN_LANES := ["left", "center", "right"]

var _spawn_timer: float = 0.0
var _active_enemies: int = 0
var _spawned_total: int = 0


func _ready() -> void:
	call_deferred("_spawn_enemy")


func _process(delta: float) -> void:
	if _active_enemies >= max_active_enemies:
		return
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_spawn_enemy()


func _spawn_enemy() -> void:
	if enemy_scene == null:
		return
	if _active_enemies >= max_active_enemies:
		return
	var enemy := enemy_scene.instantiate() as Node3D
	var lane: String = SPAWN_LANES[_spawned_total % SPAWN_LANES.size()]
	add_child(enemy)
	enemy.global_position = _spawn_position(lane)
	if "spawn_lane" in enemy:
		enemy.spawn_lane = lane
	enemy.add_to_group("enemies")
	_active_enemies += 1
	_spawned_total += 1
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	_active_enemies = maxi(_active_enemies - 1, 0)
	_spawn_enemy()


func _spawn_position(lane: String) -> Vector3:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		return Vector3(_lane_offset(lane), 1.0, -spawn_distance)

	var camera := player.get_node_or_null("Camera3D") as Camera3D
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		forward = -camera.global_transform.basis.z
		right = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	return player.global_position + forward.normalized() * spawn_distance + right.normalized() * _lane_offset(lane) + Vector3.UP


func _lane_offset(lane: String) -> float:
	if lane == "left":
		return -side_lane_offset
	if lane == "right":
		return side_lane_offset
	return 0.0
