class_name SwordVFX
extends Node

const AFTERIMAGE_FADE_SPEED := 8.0
const AFTERIMAGE_EMISSION_MULTIPLIER := 2.2

@export var settings: SwordCombatSettings

var camera: Camera3D
var sword_mesh: Node3D
var sword_pivot: Node3D
var _sword_material: StandardMaterial3D
var _default_blade_color: Color
var _default_emission_energy := 0.7
var _blade_flash := 0.0
var _afterimages: Array[Dictionary] = []
var _camera_rest_position := Vector3.ZERO
var _camera_rest_rotation := Vector3.ZERO

var _trauma: float = 0.0


func setup(camera_ref: Camera3D, sword_mesh_ref: Node3D, sword_pivot_ref: Node3D) -> void:
	assert(settings != null, "SwordVFX requires SwordCombatSettings")
	camera = camera_ref
	sword_mesh = sword_mesh_ref
	sword_pivot = sword_pivot_ref

	var mesh_instance := _find_mesh_instance(sword_mesh)
	if mesh_instance == null:
		push_error("SwordVFX could not find a MeshInstance3D on the sword model")
		return

	var material := mesh_instance.get_surface_override_material(0)
	if material == null:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)

	_sword_material = material as StandardMaterial3D
	_default_blade_color = _sword_material.albedo_color
	_default_emission_energy = _sword_material.emission_energy_multiplier
	_camera_rest_position = camera.position
	_camera_rest_rotation = camera.rotation


func tick(delta: float) -> void:
	_blade_flash = maxf(_blade_flash - delta * AFTERIMAGE_FADE_SPEED, 0.0)
	_sword_material.emission_energy_multiplier = _default_emission_energy + _blade_flash * AFTERIMAGE_EMISSION_MULTIPLIER
	_tick_afterimages(delta)

	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 3.2, 0.0)
		var shake := _trauma * _trauma
		var offset := Vector3(
			randf_range(-1.0, 1.0) * 0.14 * shake,
			randf_range(-1.0, 1.0) * 0.14 * shake,
			randf_range(-1.0, 1.0) * 0.08 * shake
		)
		camera.position = _camera_rest_position + offset


func trigger_impact_shake(intensity: float = 0.35) -> void:
	_trauma = clampf(_trauma + intensity, 0.0, 1.0)


func trigger_damage_shake(intensity: float = 0.5) -> void:
	# Stronger, more violent shake for taking damage
	_trauma = clampf(_trauma + intensity, 0.0, 1.2)


func trigger_hitstop(duration: float = 0.05) -> void:
	Engine.time_scale = 0.05
	if camera != null and camera.is_inside_tree():
		var timer := camera.get_tree().create_timer(duration, true, false, true)
		timer.timeout.connect(func(): Engine.time_scale = 1.0)
	else:
		Engine.time_scale = 1.0


func set_blade_color(color: Color) -> void:
	_sword_material.albedo_color = color


func reset_blade_color() -> void:
	_sword_material.albedo_color = _default_blade_color


func on_slash_impact(color: Color) -> void:
	_blade_flash = 1.0
	_spawn_slash_afterimage(color)


func on_slash_pose_changed(progress: float, direction: Vector2) -> void:
	camera.position = _camera_rest_position + Vector3(
		-direction.y * settings.slash_camera_shift * progress,
		-direction.x * settings.slash_camera_shift * 0.3 * progress,
		0.0,
	)
	camera.rotation = _camera_rest_rotation + Vector3(
		direction.x * settings.slash_camera_tilt * 0.45 * progress,
		direction.y * settings.slash_camera_tilt * 0.35 * progress,
		-direction.y * settings.slash_camera_tilt * progress,
	)


func on_charge_pose_changed(progress: float) -> void:
	camera.position = _camera_rest_position + Vector3(0.0, 0.012 * progress, settings.charge_camera_pullback * progress)
	camera.rotation = _camera_rest_rotation + Vector3(0.025 * progress, 0.0, 0.0)


func reset_camera_pose() -> void:
	camera.position = _camera_rest_position
	camera.rotation = _camera_rest_rotation


func _tick_afterimages(delta: float) -> void:
	for index in range(_afterimages.size() - 1, -1, -1):
		var afterimage := _afterimages[index]
		afterimage.life -= delta
		var material := afterimage.material as StandardMaterial3D
		var life_ratio := maxf(afterimage.life / maxf(settings.slash_afterimage_lifetime, 0.001), 0.0)
		var color := material.albedo_color
		color.a = settings.slash_afterimage_alpha * life_ratio
		material.albedo_color = color
		material.emission_energy_multiplier = 2.0 * material.albedo_color.a
		if afterimage.life <= 0.0:
			afterimage.mesh.queue_free()
			_afterimages.remove_at(index)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found

	return null


func _spawn_slash_afterimage(color: Color) -> void:
	var mesh_instance := _find_mesh_instance(sword_mesh)
	if mesh_instance == null:
		return

	var afterimage := MeshInstance3D.new()
	afterimage.mesh = mesh_instance.mesh
	afterimage.global_transform = mesh_instance.global_transform
	afterimage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, settings.slash_afterimage_alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.9
	material.no_depth_test = true
	afterimage.material_override = material

	get_tree().current_scene.add_child(afterimage)
	_afterimages.append({"mesh": afterimage, "material": material, "life": settings.slash_afterimage_lifetime})
