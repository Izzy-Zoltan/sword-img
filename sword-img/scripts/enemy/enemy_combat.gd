class_name EnemyCombat
extends Node

const HitSparksScene := preload("res://scenes/vfx/hit_sparks.tscn")
const DeathSparksScene := preload("res://scenes/vfx/death_sparks.tscn")
const DamageLabelScene := preload("res://scenes/vfx/damage_label.tscn")

var _enemy: BasicEnemy
var _animator: EnemyAnimator

var _health: int = 0
var _hit_cooldown: float = 0.0
var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _idle_timer: float = 0.0
var _pre_attack_idle_timer: float = 0.0
var _is_winding_up: bool = false
var _is_idling_before_attack: bool = false

func setup(enemy: BasicEnemy, animator: EnemyAnimator, _mesh: MeshInstance3D) -> void:
	_enemy = enemy
	_animator = animator
	_health = enemy.max_health

func update(player: Node3D) -> void:
	if player == null:
		_animator.play_idle()
		return

	var distance_sq := _enemy.global_position.distance_squared_to(player.global_position)
	if _idle_timer > 0.0:
		_animator.play_idle()
		return

	var effective_range := _enemy.attack_range + _enemy.attack_stop_buffer
	if distance_sq <= effective_range * effective_range and _attack_timer <= 0.0:
		_handle_attack(player)
		return

	if _is_winding_up:
		_animator.play_attack(true)
		return

	_animator.play_idle()

func update_timers(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_windup_timer = maxf(_windup_timer - delta, 0.0)
	_idle_timer = maxf(_idle_timer - delta, 0.0)
	_pre_attack_idle_timer = maxf(_pre_attack_idle_timer - delta, 0.0)

func take_hit(source_lane: String, damage: int = 1) -> void:
	if _health <= 0 or _enemy._is_dying:
		return
	if _hit_cooldown > 0.0:
		return
	if source_lane != _enemy.spawn_lane:
		return
	_hit_cooldown = 0.2
	_take_damage(damage)

func _handle_attack(player: Node3D) -> void:
	if not _is_winding_up:
		if not _is_idling_before_attack:
			_is_idling_before_attack = true
			_pre_attack_idle_timer = _enemy.idle_before_attack
			_animator.play_idle()
			return

		if _pre_attack_idle_timer > 0.0:
			_animator.play_idle()
			return

		_is_idling_before_attack = false
		_is_winding_up = true
		_windup_timer = _enemy.attack_windup
		_animator.play_attack(true)
		return

	if _windup_timer <= 0.0:
		_is_winding_up = false
		_attack_timer = _enemy.attack_cooldown
		_idle_timer = _enemy.idle_between_attacks
		_animator.play_idle()
		if player.has_method("take_damage"):
			player.take_damage(_enemy.attack_damage)
		return

	_animator.play_attack(true)

func _take_damage(amount: int) -> void:
	if _enemy._is_dying:
		return

	_health -= amount
	_enemy._stagger_timer = 0.22

	if _enemy._outline != null:
		_enemy._outline.trigger_hit_flash()

	var player := _enemy.get_tree().current_scene.get_node_or_null("Player") as Node3D
	var push_dir := Vector3.BACK
	if player != null:
		if player.has_method("notify_slash_hit"):
			player.notify_slash_hit()
		push_dir = _enemy.global_position - player.global_position
		push_dir.y = 0.0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.BACK

	_enemy.velocity += push_dir * 8.5 + Vector3.UP * 3.0
	_spawn_hit_sparks(_enemy.global_position + Vector3(0, 1.0, 0), push_dir)
	var label_pos := _enemy.global_position + Vector3(0, 1.0, 0)
	var scene_root := _enemy.get_tree().current_scene
	if _health <= 0:
		DamageLabel.show_fatal(scene_root, label_pos)
	else:
		DamageLabel.show_damage(scene_root, label_pos, amount)

	if player != null:
		var sword_vfx := player.get_node_or_null("Camera3D/SwordVFX")
		if sword_vfx != null and sword_vfx.has_method("trigger_impact_shake"):
			sword_vfx.trigger_impact_shake(0.4)
			sword_vfx.trigger_hitstop(0.06)

	if _health <= 0:
		_die()

func _die() -> void:
	if _enemy._is_dying:
		return
	_enemy._is_dying = true

	var player := _enemy.get_tree().current_scene.get_node_or_null("Player") as Node3D
	var push_dir := Vector3.BACK
	if player != null:
		push_dir = (_enemy.global_position - player.global_position).normalized()

	_spawn_death_sparks(_enemy.global_position + Vector3(0, 1.0, 0), push_dir)

	var goblin_model := _enemy.get_node_or_null("GoblinModel")
	if goblin_model != null:
		var tween := _enemy.get_tree().create_tween().set_parallel(true)
		tween.tween_property(goblin_model, "scale", Vector3(1.4, 0.2, 1.4), 0.15).set_trans(Tween.TRANS_QUAD)
		tween.chain().tween_property(goblin_model, "scale", Vector3.ZERO, 0.1).set_trans(Tween.TRANS_QUAD)

	_enemy.died.emit()
	var timer := _enemy.get_tree().create_timer(0.25)
	timer.timeout.connect(_enemy.queue_free)

func _spawn_hit_sparks(pos: Vector3, hit_dir: Vector3) -> void:
	if not _enemy.is_inside_tree():
		return
	var particles := HitSparksScene.instantiate() as CPUParticles3D
	particles.global_position = pos
	particles.direction = hit_dir + Vector3.UP * 0.4

	_enemy.get_tree().current_scene.add_child(particles)

	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func _spawn_death_sparks(pos: Vector3, hit_dir: Vector3) -> void:
	if not _enemy.is_inside_tree():
		return
	var particles := DeathSparksScene.instantiate() as CPUParticles3D
	particles.global_position = pos
	particles.direction = hit_dir + Vector3.UP * 0.8

	_enemy.get_tree().current_scene.add_child(particles)

	particles.finished.connect(particles.queue_free)
	particles.emitting = true
