class_name BasicEnemy
extends CharacterBody3D

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
@onready var font = load("res://Assets/PixelifySans-Bold.ttf")


@export_enum("left", "center", "right") var spawn_lane := "center"

var _health: int
var _hit_cooldown: float = 0.0
var _animation_player: AnimationPlayer
var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _idle_timer: float = 0.0
var _pre_attack_idle_timer: float = 0.0
var _is_winding_up: bool = false
var _is_idling_before_attack: bool = false

var _mesh_material: StandardMaterial3D
var _flash_timer: float = 0.0
var _stagger_timer: float = 0.0
var _is_dying: bool = false

static var _cached_hit_audio: AudioStreamWAV = null
static var _cached_death_audio: AudioStreamWAV = null
static var _cached_miss_audio: AudioStreamWAV = null


static func _get_hit_audio() -> AudioStreamWAV:
	if _cached_hit_audio != null:
		return _cached_hit_audio

	var sample_rate := 22050
	var duration := 0.14
	var num_samples := int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 26.0)
		var freq := 240.0 * exp(-t * 18.0) + 50.0
		var sine_val := sin(t * freq * TAU)
		var noise_val := randf_range(-1.0, 1.0)
		var mixed := (sine_val * 0.4 + noise_val * 0.6) * env
		var byte_val := int(clampf((mixed * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		pcm_data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	_cached_hit_audio = stream
	return _cached_hit_audio


static func _get_death_audio() -> AudioStreamWAV:
	if _cached_death_audio != null:
		return _cached_death_audio

	var sample_rate := 22050
	var duration := 0.25
	var num_samples := int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 14.0)
		var freq := 450.0 * exp(-t * 10.0) + 60.0
		var sine_val := sin(t * freq * TAU)
		var noise_val := randf_range(-1.0, 1.0)
		var mixed := (sine_val * 0.3 + noise_val * 0.7) * env
		var byte_val := int(clampf((mixed * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		pcm_data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	_cached_death_audio = stream
	return _cached_death_audio


static func _get_miss_audio() -> AudioStreamWAV:
	if _cached_miss_audio != null:
		return _cached_miss_audio

	var sample_rate := 22050
	var duration := 0.18
	var num_samples := int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(num_samples)

	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var env := sin(t / duration * PI)
		var noise_val := randf_range(-1.0, 1.0)
		var sine_val := sin(t * (130.0 - t * 450.0) * TAU)
		var mixed := (noise_val * 0.75 + sine_val * 0.25) * env * 0.4
		var byte_val := int(clampf((mixed * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		pcm_data[i] = byte_val

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	_cached_miss_audio = stream
	return _cached_miss_audio


func _ready() -> void:
	_health = max_health
	_animation_player = _find_animation_player(self)
	floor_stop_on_slope = true
	if has_node("HurtArea"):
		$HurtArea.area_entered.connect(_on_area_entered)

	var mesh_instance := _find_mesh_instance(self)
	if mesh_instance != null:
		_mesh_material = StandardMaterial3D.new()
		_mesh_material.albedo_color = Color(1.0, 0.2, 0.2)
		_mesh_material.emission_enabled = true
		_mesh_material.emission = Color(0.55, 0.1, 0.1)
		mesh_instance.material_override = _mesh_material


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found

	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null


func _play_run_animation() -> void:
	if _animation_player == null:
		return

	var animation_name := _pick_animation(["Run", "run", "Walk", "walk", "Move", "move"])
	if animation_name == "":
		animation_name = _pick_animation(_animation_player.get_animation_list())

	if animation_name != "":
		if _animation_player.current_animation != animation_name:
			_animation_player.play(animation_name)


func _play_idle_animation() -> void:
	if _animation_player == null:
		return

	var animation_name := _pick_animation(["Idle", "idle", "Rest", "rest", "Stand", "stand"])
	if animation_name == "":
		_animation_player.stop()
		return

	if _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)


func _play_attack_animation(force: bool = false) -> void:
	if _animation_player == null:
		return

	var animation_name := _pick_animation(["Attack", "attack", "Slash", "slash", "Action", "action", "Hit", "hit"])
	if animation_name == "":
		_play_idle_animation()
		return

	if force or _animation_player.current_animation != animation_name:
		_animation_player.play(animation_name)


func _pick_animation(candidates: Array) -> StringName:
	for candidate in candidates:
		var name_string := String(candidate)
		if _animation_player != null and _animation_player.has_animation(name_string):
			return StringName(name_string)

	return ""


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_windup_timer = maxf(_windup_timer - delta, 0.0)
	_idle_timer = maxf(_idle_timer - delta, 0.0)
	_pre_attack_idle_timer = maxf(_pre_attack_idle_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)

	_update_hit_flash(delta)

	if _is_dying:
		return

	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		_play_idle_animation()
		return

	var look_target := Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_squared_to(look_target) > 0.001:
		look_at(look_target, Vector3.UP)
		rotate_y(PI)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if _stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
		move_and_slide()
		return

	var direction := player.global_position - global_position
	direction.y = 0.0
	var distance_sq := direction.length_squared()
	var stop_distance_sq := (attack_range + attack_stop_buffer) * (attack_range + attack_stop_buffer)
	if distance_sq > stop_distance_sq:
		_is_idling_before_attack = false
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		move_and_slide()
		_play_run_animation()
		return

	velocity.x = move_toward(velocity.x, 0.0, speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, speed * delta)
	move_and_slide()

	if _idle_timer > 0.0:
		_play_idle_animation()
		return

	if distance_sq <= attack_range * attack_range and _attack_timer <= 0.0:
		if not _is_winding_up:
			if not _is_idling_before_attack:
				_is_idling_before_attack = true
				_pre_attack_idle_timer = idle_before_attack
				_play_idle_animation()
				return

			if _pre_attack_idle_timer > 0.0:
				_play_idle_animation()
				return

			_is_idling_before_attack = false
			_is_winding_up = true
			_windup_timer = attack_windup
			_play_attack_animation(true)
			return

		if _is_winding_up and _windup_timer <= 0.0:
			_is_winding_up = false
			_attack_timer = attack_cooldown
			_idle_timer = idle_between_attacks
			_play_idle_animation()
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
			return

	if _is_winding_up:
		_play_attack_animation(true)
		return

	if _idle_timer > 0.0:
		_play_idle_animation()
		return

	_play_idle_animation()


func _update_hit_flash(delta: float) -> void:
	if _mesh_material == null:
		return
	if _flash_timer > 0.0:
		_flash_timer -= delta
		var ratio := clampf(_flash_timer / 0.16, 0.0, 1.0)
		_mesh_material.albedo_color = Color(1.0, 0.2, 0.2).lerp(Color(3.0, 2.5, 1.2), ratio)
		_mesh_material.emission = Color(0.55, 0.1, 0.1).lerp(Color(4.0, 3.0, 1.0), ratio)
	else:
		_mesh_material.albedo_color = Color(1.0, 0.2, 0.2)
		_mesh_material.emission = Color(0.55, 0.1, 0.1)


func _on_area_entered(area: Area3D) -> void:
	if _health <= 0 or _is_dying:
		return
	if _hit_cooldown > 0.0:
		return
	if not (area is SwordHitbox or area is ChargedProjectile):
		return


	_hit_cooldown = 0.2
	_take_damage(1)


func _attack_lane(area: Area3D) -> String:
	if area is SwordHitbox:
		return (area as SwordHitbox).slash_lane
	return (area as ChargedProjectile).attack_lane


func _take_damage(amount: int) -> void:
	if _is_dying:
		return

	_health -= amount
	_flash_timer = 0.16
	_stagger_timer = 0.22

	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	var push_dir := Vector3.BACK
	if player != null:
		if player.has_method("notify_slash_hit"):
			player.notify_slash_hit()
		push_dir = (global_position - player.global_position)
		push_dir.y = 0.0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.BACK

	velocity += push_dir * 8.5 + Vector3.UP * 3.0

	_spawn_hit_sparks(global_position + Vector3(0, 1.0, 0), push_dir)
	_spawn_damage_text(global_position + Vector3(0, 1.0, 0), amount, _health <= 0)
	_play_hit_sound(false)

	if player != null:
		var sword_vfx := player.get_node_or_null("Camera3D/SwordVFX")
		if sword_vfx != null and sword_vfx.has_method("trigger_impact_shake"):
			sword_vfx.trigger_impact_shake(0.4)
			sword_vfx.trigger_hitstop(0.06)

	if _health <= 0:
		_die()

func _spawn_miss_particles(pos: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.global_position = pos
	particles.amount = 18
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.gravity = Vector3(0, -5.0, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.3

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.7, 0.8, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	particles.material_override = mat
	particles.emitting = true

	get_tree().current_scene.add_child(particles)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(particles.queue_free)


func _play_miss_sound() -> void:
	var audio_player := AudioStreamPlayer3D.new()
	audio_player.global_position = global_position
	audio_player.stream = _get_miss_audio()
	audio_player.unit_size = 12.0
	audio_player.pitch_scale = randf_range(0.95, 1.15)
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)


func _die() -> void:
	if _is_dying:
		return
	_is_dying = true

	var player := get_tree().current_scene.get_node_or_null("Player") as Node3D
	var push_dir := Vector3.BACK
	if player != null:
		push_dir = (global_position - player.global_position).normalized()

	_spawn_death_sparks(global_position + Vector3(0, 1.0, 0), push_dir)
	_play_hit_sound(true)

	var goblin_model := get_node_or_null("GoblinModel")
	if goblin_model != null:
		var tween := get_tree().create_tween().set_parallel(true)
		tween.tween_property(goblin_model, "scale", Vector3(1.4, 0.2, 1.4), 0.15).set_trans(Tween.TRANS_QUAD)
		tween.chain().tween_property(goblin_model, "scale", Vector3.ZERO, 0.1).set_trans(Tween.TRANS_QUAD)

	died.emit()
	var timer := get_tree().create_timer(0.25)
	timer.timeout.connect(queue_free)


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

	get_tree().current_scene.add_child(particles)
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(particles.queue_free)


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

	get_tree().current_scene.add_child(particles)
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(particles.queue_free)


func _spawn_damage_text(pos: Vector3, damage: int, is_fatal: bool) -> void:
	var label := Label3D.new()
	label.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0.6, randf_range(-0.15, 0.15))
	label.text = "FATAL!" if is_fatal else "-%d HP" % damage
	label.font = font 
	label.font_size = 56 if is_fatal else 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.9, 0.1) if is_fatal else Color(1.0, 0.25, 0.1)
	label.outline_render_priority = 1
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 1)

	get_tree().current_scene.add_child(label)

	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.35, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector3.ONE, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)


func _play_hit_sound(is_fatal: bool) -> void:
	var audio_player := AudioStreamPlayer3D.new()
	audio_player.global_position = global_position
	audio_player.stream = _get_death_audio() if is_fatal else _get_hit_audio()
	audio_player.unit_size = 15.0
	audio_player.pitch_scale = randf_range(0.9, 1.15) if not is_fatal else randf_range(0.75, 0.9)
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
