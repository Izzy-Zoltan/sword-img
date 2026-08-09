class_name EnemyMovement
extends Node

var _enemy: CharacterBody3D

func setup(enemy: CharacterBody3D) -> void:
	_enemy = enemy

func update(delta: float, player: Node3D) -> bool:
	if _enemy == null or player == null:
		return false

	_face_player(player)
	_apply_gravity(delta)

	if _enemy._stagger_timer > 0.0:
		_handle_stagger(delta)
		return true

	var direction := player.global_position - _enemy.global_position
	direction.y = 0.0

	var distance_sq := direction.length_squared()
	var stop_distance := _enemy.attack_range + _enemy.attack_stop_buffer
	if distance_sq <= stop_distance * stop_distance:
		_stop(delta)
		return false

	_enemy._is_idling_before_attack = false
	direction = direction.normalized()
	_enemy.velocity.x = direction.x * _enemy.speed
	_enemy.velocity.z = direction.z * _enemy.speed
	_enemy.move_and_slide()
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
	_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.speed * 4.0 * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, 0.0, _enemy.speed * 4.0 * delta)
	_enemy.move_and_slide()

func _stop(delta: float) -> void:
	_enemy.velocity.x = move_toward(_enemy.velocity.x, 0.0, _enemy.speed * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, 0.0, _enemy.speed * delta)
	_enemy.move_and_slide()
