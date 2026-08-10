class_name SwordHitDetection
extends Node

const PROJECTILE_COLLIDER_SIZE := Vector3(1.6, 1.45, 0.3)
const PROJECTILE_OFFSET := 0.7
const SWORD_RANGE := 4.5

var _player: Node3D
var _camera: Camera3D
var _charge: SwordCharge
var current_slash_hit: bool = false


func setup(player: Node3D, camera: Camera3D, charge: SwordCharge) -> void:
	_player = player
	_camera = camera
	_charge = charge


func try_hit_enemies(lane: String) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		var dist := _player.global_position.distance_to(enemy.global_position)
		if dist > SWORD_RANGE:
			continue
		if enemy.has_method("take_hit"):
			enemy.take_hit(lane)


func fire_charged_projectile(slash_move: SwordMoveSystem.Move) -> void:
	_charge.consume_charge()

	var best_enemy: Node3D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D:
			var d := _player.global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy

	if best_enemy != null and best_enemy.has_method("take_hit"):
		var lane: String = best_enemy.get("spawn_lane") if "spawn_lane" in best_enemy else "center"
		_charge.suppress_charge_gain = true
		best_enemy.take_hit(lane, 3)
		_charge.suppress_charge_gain = false
		current_slash_hit = true

	var projectile := ChargedProjectile.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = PROJECTILE_COLLIDER_SIZE
	collider.shape = shape
	projectile.add_child(collider)
	get_tree().current_scene.add_child(projectile)
	var direction := _projectile_direction_for_slash(slash_move)
	var spawn_origin := _player.global_position + Vector3.UP * 1.0
	projectile.global_position = spawn_origin + direction * PROJECTILE_OFFSET
	projectile.launch(direction, "center")


static func slash_lane_for_move(slash_move: SwordMoveSystem.Move) -> String:
	match slash_move:
		SwordMoveSystem.Move.SLASH_LEFT:
			return "left"
		SwordMoveSystem.Move.SLASH_RIGHT:
			return "right"
		_:
			return "center"


func _projectile_direction_for_slash(_slash_move: SwordMoveSystem.Move) -> Vector3:
	var forward := -_camera.global_transform.basis.z
	var right := _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var best_enemy: Node3D = null
	var best_dist_sq := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D:
			var d := _player.global_position.distance_squared_to(enemy.global_position)
			if d < best_dist_sq:
				best_dist_sq = d
				best_enemy = enemy

	if best_enemy != null:
		var to_enemy := best_enemy.global_position - _player.global_position
		to_enemy.y = 0.0
		if to_enemy.length_squared() > 0.001:
			return to_enemy.normalized()

	return forward
