class_name WaveManager
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemies_remaining_changed(remaining: int)
signal intermission_started(seconds: float)
signal all_waves_cleared

@export_group("Spawning")
@export var enemy_scene: PackedScene
@export var spawn_distance: float = 8.0
@export var side_lane_offset: float = 10.0
@export var spawn_spread: float = 3.0

@export_group("Wave Progression")
@export var base_enemy_count: int = 3
@export var enemies_per_wave_increase: int = 1
@export var base_max_concurrent: int = 2
@export var concurrent_increase_per_wave: int = 1
@export var max_concurrent_cap: int = 8
@export var spawn_interval: float = 1.2
@export var intermission_time: float = 3.0
@export var max_waves: int = 0

@export_group("Stat Scaling")
@export var speed_increase_per_wave: float = 0.5
@export var health_increase_interval: int = 5
@export var health_increase_amount: int = 1
@export var damage_increase_interval: int = 10
@export var damage_increase_amount: int = 1
@export var cooldown_reduction_per_wave: float = 0.02
@export var min_attack_cooldown: float = 0.1

const SPAWN_LANES := ["left", "center", "right"]

var current_wave: int = 0
var enemies_alive: int = 0
var enemies_to_spawn: int = 0
var total_wave_enemies: int = 0
var _spawn_timer: float = 0.0
var _intermission_timer: float = 0.0
var _spawned_count: int = 0
var _is_intermission: bool = true
var _wave_active: bool = false
var _all_cleared: bool = false


func _ready() -> void:
	_start_intermission()


func _process(delta: float) -> void:
	if _all_cleared:
		return

	if _is_intermission:
		_intermission_timer -= delta
		if _intermission_timer <= 0.0:
			_begin_next_wave()
		return

	if not _wave_active:
		return

	if enemies_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_try_spawn_enemy()

	if enemies_to_spawn <= 0 and enemies_alive <= 0:
		_wave_active = false
		wave_completed.emit(current_wave)
		if max_waves > 0 and current_wave >= max_waves:
			_all_cleared = true
			all_waves_cleared.emit()
		else:
			_start_intermission()


func _start_intermission() -> void:
	_is_intermission = true
	_intermission_timer = intermission_time
	intermission_started.emit(intermission_time)


func _begin_next_wave() -> void:
	_is_intermission = false
	current_wave += 1
	total_wave_enemies = base_enemy_count + (current_wave - 1) * enemies_per_wave_increase
	enemies_to_spawn = total_wave_enemies
	enemies_alive = 0
	_spawn_timer = 0.0
	_wave_active = true
	wave_started.emit(current_wave)
	enemies_remaining_changed.emit(total_wave_enemies)


func _get_max_concurrent() -> int:
	var cap := base_max_concurrent + (current_wave - 1) * concurrent_increase_per_wave
	return mini(cap, max_concurrent_cap)


func _try_spawn_enemy() -> void:
	if enemies_to_spawn <= 0:
		return
	if enemies_alive >= _get_max_concurrent():
		return
	_spawn_enemy()


func _spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate() as Node3D
	var lane: String = SPAWN_LANES[_spawned_count % SPAWN_LANES.size()]

	if "spawn_lane" in enemy:
		enemy.spawn_lane = lane

	_apply_wave_scaling(enemy)

	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _spawn_position(lane)
	enemy.add_to_group("enemies")

	_spawned_count += 1
	enemies_to_spawn -= 1
	enemies_alive += 1

	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)


func _apply_wave_scaling(enemy: Node3D) -> void:
	var wave_index := current_wave - 1 

	if "speed" in enemy:
		enemy.speed += speed_increase_per_wave * wave_index

	if "max_health" in enemy and health_increase_interval > 0:
		var health_bonus := (wave_index / health_increase_interval) * health_increase_amount
		enemy.max_health += health_bonus

	if "attack_damage" in enemy and damage_increase_interval > 0:
		var damage_bonus := (wave_index / damage_increase_interval) * damage_increase_amount
		enemy.attack_damage += damage_bonus

	if "attack_cooldown" in enemy:
		var reduction := cooldown_reduction_per_wave * wave_index
		enemy.attack_cooldown = maxf(enemy.attack_cooldown - reduction, min_attack_cooldown)


func _on_enemy_died() -> void:
	enemies_alive = maxi(enemies_alive - 1, 0)
	var remaining := enemies_alive + enemies_to_spawn
	enemies_remaining_changed.emit(remaining)


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

	var dist := spawn_distance + randf() * spawn_spread
	return player.global_position + forward.normalized() * dist + right.normalized() * _lane_offset(lane) + Vector3.UP


func _lane_offset(lane: String) -> float:
	if lane == "left":
		return -side_lane_offset
	if lane == "right":
		return side_lane_offset
	return 0.0
