class_name EnemyMovement
extends Node

var _enemy: BasicEnemy

var _recovering_from_hit: bool = false

func setup(enemy: BasicEnemy) -> void:
	_enemy = enemy

func update(delta: float, player: Node3D) -> bool:
	if player == null:
		return false

	_face_player(player)
	_apply_gravity(delta)

	var direction := player.global_position - _enemy.global_position
	direction.y = 0.0
	var distance := direction.length()

	if _enemy._stagger_timer > 0.0:
		_recovering_from_hit = true
		_handle_stagger(delta)
		return true

	var min_stop := _enemy.attack_range * 0.6
	if distance < min_stop and distance > 0.01:
		var push_out := direction.normalized() * -1.0
		_enemy.velocity.x = push_out.x * _enemy.speed * 2.0
		_enemy.velocity.z = push_out.z * _enemy.speed * 2.0
		_enemy.move_and_slide()
		return false

	var stop_distance := _enemy.attack_range + _enemy.attack_stop_buffer
	if distance <= stop_distance:
		_recovering_from_hit = false
		_stop(delta)
		return false

	_enemy._combat._is_idling_before_attack = false
	var dir_norm := direction / distance

	var approach_factor := clampf((distance - stop_distance) / 2.0, 0.2, 1.0)
	var chase_speed := _enemy.speed * approach_factor

	_enemy.velocity.x = dir_norm.x * chase_speed
	_enemy.velocity.z = dir_norm.z * chase_speed
	_enemy.move_and_slide()
	_recovering_from_hit = false
	return true

func _face_player(player: Node3D) -> void:
	var look_target := Vector3(player.global_position.x, _enemy.global_position.y, player.global_position.z)
	if _enemy.global_position.distance_squared_to(look_target) > 0.001:
		_enemy.look_at(look_target, Vector3.UP)
		_enemy.rotate_y(PI)

func _apply_gravity(delta: float) -> void:
	if not _enemy.is_on_floor():
		_enemy.velocity.y -= _enemy.gravity * delta
	else:
		_enemy.velocity.y = 0.0

func _handle_stagger(delta: float) -> void:
	_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.speed * 3.0 * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, 0.0, _enemy.speed * 3.0 * delta)
	_enemy.move_and_slide()

func _stop(delta: float) -> void:
	_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.speed * 8.0 * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, 0.0, _enemy.speed * 8.0 * delta)
	_enemy.move_and_slide()
