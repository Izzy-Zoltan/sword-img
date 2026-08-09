class_name EnemyCombat
extends Node

var _enemy: CharacterBody3D
var _animator: EnemyAnimator
var _font: Font
var _mesh_material: StandardMaterial3D

func setup(enemy: CharacterBody3D, animator: EnemyAnimator, mesh: MeshInstance3D) -> void:
	_enemy = enemy
	_animator = animator
	_font = load("res://Assets/PixelifySans-Bold.ttf")
	_mesh_material = mesh.get_active_material(0).duplicate()
	mesh.set_surface_override_material(0, _mesh_material)

func update(delta: float, player: Node3D) -> void:
	_update_timers(delta)
	_update_hit_flash(delta)

	if player == null:
		_animator.play_idle()
		return

	var distance_sq := _enemy.global_position.distance_squared_to(player.global_position)
	if _enemy._idle_timer > 0.0:
		_animator.play_idle()
		return

	if distance_sq <= _enemy.attack_range * _enemy.attack_range and _enemy._attack_timer <= 0.0:
		_handle_attack(player)
		return

	if _enemy._is_winding_up:
		_animator.play_attack(true)
		return

	_animator.play_idle()

func connect_hurt_area(hurt_area: Area3D) -> void:
	hurt_area.area_entered.connect(_on_area_entered)

func _update_timers(delta: float) -> void:
	_enemy._hit_cooldown = maxf(_enemy._hit_cooldown - delta, 0.0)
	_enemy._attack_timer = maxf(_enemy._attack_timer - delta, 0.0)
	_enemy._windup_timer = maxf(_enemy._windup_timer - delta, 0.0)
	_enemy._idle_timer = maxf(_enemy._idle_timer - delta, 0.0)
	_enemy._pre_attack_idle_timer = maxf(_enemy._pre_attack_idle_timer - delta, 0.0)
	_enemy._stagger_timer = maxf(_enemy._stagger_timer - delta, 0.0)

func _handle_attack(player: Node3D) -> void:
	if not _enemy._is_winding_up:
		if not _enemy._is_idling_before_attack:
			_enemy._is_idling_before_attack = true
			_enemy._pre_attack_idle_timer = _enemy.idle_before_attack
			_animator.play_idle()
			return

		if _enemy._pre_attack_idle_timer > 0.0:
			_animator.play_idle()
			return

		_enemy._is_idling_before_attack = false
		_enemy._is_winding_up = true
		_enemy._windup_timer = _enemy.attack_windup
		_animator.play_attack(true)
		return

	if _enemy._windup_timer <= 0.0:
		_enemy._is_winding_up = false
		_enemy._attack_timer = _enemy.attack_cooldown
		_enemy._idle_timer = _enemy.idle_between_attacks
		_animator.play_idle()
		if player.has_method("take_damage"):
			player.take_damage(_enemy.attack_damage)
		return

	_animator.play_attack(true)

func _on_area_entered(area: Area3D) -> void:
	if _enemy._health <= 0 or _enemy._is_dying:
		return
	if _enemy._hit_cooldown > 0.0:
		return
	if not (area is SwordHitbox or area is ChargedProjectile):
		return

	_enemy._hit_cooldown = 0.2
	_take_damage(1, area)

func _attack_lane(area: Area3D) -> String:
	if area is SwordHitbox:
		return (area as SwordHitbox).slash_lane
	return (area as ChargedProjectile).attack_lane

func _take_damage(amount: int, area: Area3D) -> void:
	if _enemy._is_dying:
		return

	_enemy._health -= amount
	_enemy._flash_timer = 0.16
	_enemy._stagger_timer = 0.22

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
	_spawn_damage_text(_enemy.global_position + Vector3(0, 1.0, 0), amount, _enemy._health <= 0)

	if player != null:
		var sword_vfx := player.get_node_or_null("Camera3D/SwordVFX")
		if sword_vfx != null and sword_vfx.has_method("trigger_impact_shake"):
			sword_vfx.trigger_impact_shake(0.4)
			sword_vfx.trigger_hitstop(0.06)

	if _enemy._health <= 0:
		_die()

func _update_hit_flash(delta: float) -> void:
	if _mesh_material == null:
		return
	if _enemy._flash_timer > 0.0:
		_enemy._flash_timer -= delta
		var ratio := clampf(_enemy._flash_timer / 0.16, 0.0, 1.0)
		_mesh_material.albedo_color = Color(1.0, 0.2, 0.2).lerp(Color(3.0, 2.5, 1.2), ratio)
		_mesh_material.emission = Color(0.55, 0.1, 0.1).lerp(Color(4.0, 3.0, 1.0), ratio)
	else:
		_mesh_material.albedo_color = Color(1.0, 0.2, 0.2)
		_mesh_material.emission = Color(0.55, 0.1, 0.1)

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
	var particles := CPUParticles3D.new()
	particles.global_position = pos
	particles.amount = 26
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = hit_dir + Vector3(0, 0.4, 0)
	particles.spread = 50.0
	particles.gravity = Vector3(0, -14.0, 0)
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 11.0
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 4.5
	mat.albedo_color = Color(1.0, 0.5, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = mat
	particles.emitting = true
	_enemy.get_tree().current_scene.add_child(particles)
	_enemy.get_tree().create_timer(0.45).timeout.connect(particles.queue_free)

func _spawn_death_sparks(pos: Vector3, hit_dir: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.global_position = pos
	particles.amount = 45
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = hit_dir + Vector3(0, 0.8, 0)
	particles.spread = 75.0
	particles.gravity = Vector3(0, -18.0, 0)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 16.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.35
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 5.0
	mat.albedo_color = Color(1.0, 0.7, 0.2)
	particles.material_override = mat
	particles.emitting = true
	_enemy.get_tree().current_scene.add_child(particles)
	_enemy.get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

func _spawn_damage_text(pos: Vector3, damage: int, is_fatal: bool) -> void:
	var label := Label3D.new()
	label.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0.6, randf_range(-0.15, 0.15))
	label.text = "FATAL!" if is_fatal else "-%d HP" % damage
	label.font = _font
	label.font_size = 56 if is_fatal else 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.9, 0.1) if is_fatal else Color(1.0, 0.25, 0.1)
	label.outline_render_priority = 1
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 1)
	_enemy.get_tree().current_scene.add_child(label)
	var tween := _enemy.get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.35, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector3.ONE, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)
