class_name SwordVFX
extends Node

const AFTERIMAGE_FADE_SPEED := 8.0
const AFTERIMAGE_EMISSION_MULTIPLIER := 2.2

@export var settings: SwordCombatSettings

var camera: Camera3D
var sword_mesh: MeshInstance3D
var sword_pivot: Node3D
var _sword_material: StandardMaterial3D
var _default_blade_color: Color
var _default_emission_energy := 0.7
var _blade_flash := 0.0
var _afterimages: Array[Dictionary] = []
var _camera_rest_position := Vector3.ZERO
var _camera_rest_rotation := Vector3.ZERO


func setup(camera_ref: Camera3D, sword_mesh_ref: MeshInstance3D, sword_pivot_ref: Node3D) -> void:
	assert(settings != null, "SwordVFX requires SwordCombatSettings")
	camera = camera_ref
	sword_mesh = sword_mesh_ref
	sword_pivot = sword_pivot_ref
	_sword_material = sword_mesh.get_surface_override_material(0) as StandardMaterial3D
	_default_blade_color = _sword_material.albedo_color
	_default_emission_energy = _sword_material.emission_energy_multiplier
	_camera_rest_position = camera.position
	_camera_rest_rotation = camera.rotation


func tick(delta: float) -> void:
	_blade_flash = maxf(_blade_flash - delta * AFTERIMAGE_FADE_SPEED, 0.0)
	_sword_material.emission_energy_multiplier = _default_emission_energy + _blade_flash * AFTERIMAGE_EMISSION_MULTIPLIER
	_tick_afterimages(delta)


func set_blade_color(color: Color) -> void:
	_sword_material.albedo_color = color


func reset_blade_color() -> void:
	_sword_material.albedo_color = _default_blade_color


func on_slash_impact(color: Color) -> void:
	_blade_flash = 1.0
	_spawn_slash_afterimage(color)


func on_slash_pose_changed(progress: float, direction: Vector2) -> void:
	camera.position = _camera_rest_position + Vector3(
		-direction.x * settings.slash_camera_shift * progress,
		direction.y * settings.slash_camera_shift * 0.3 * progress,
		0.0,
	)
	camera.rotation = _camera_rest_rotation + Vector3(
		-direction.y * settings.slash_camera_tilt * 0.45 * progress,
		direction.x * settings.slash_camera_tilt * 0.35 * progress,
		-direction.x * settings.slash_camera_tilt * progress,
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


func _spawn_slash_afterimage(color: Color) -> void:
	var afterimage := MeshInstance3D.new()
	afterimage.mesh = sword_mesh.mesh
	afterimage.global_transform = sword_mesh.global_transform
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
