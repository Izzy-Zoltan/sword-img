class_name EnemyOutline
extends Node

const OUTLINE_SHADER := preload("res://shaders/enemy_outline.gdshader")
const SKIP_MESHES := ["cube_005"]

const HIT_FLASH_DURATION := 0.18
const SWORD_RANGE := 4.5
const BLEND_SPEED_IN := 6.0
const BLEND_SPEED_OUT := 4.0

const COLOR_DEFAULT := Color(0.05, 0.2, 0.05, 0.8)
const COLOR_IN_RANGE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_HIT := Color(1.0, 0.85, 0.2, 1.0)
const COLOR_ATTACKING := Color(1.0, 0.1, 0.05, 1.0)

const GLOW_DEFAULT := 2.0
const GLOW_IN_RANGE := 2.5
const GLOW_HIT := 5.0
const GLOW_ATTACKING := 3.5

const SCALE_DEFAULT := 1.03
const SCALE_IN_RANGE := 1.03
const SCALE_HIT := 1.05

var _material: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _enemy: EnemyController
var _range_blend := 0.0
var _hit_timer := 0.0
var _base_outline_color: Color = COLOR_DEFAULT


func setup(enemy: EnemyController, model_root: Node3D, outline_color: Color = COLOR_DEFAULT) -> void:
	_enemy = enemy
	_base_outline_color = outline_color
	_material = _create_material()
	_build_outline_meshes(model_root)


func update(delta: float) -> void:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_range_blend = move_toward(_range_blend, 1.0 if _is_in_range() else 0.0,
		delta * (BLEND_SPEED_IN if _is_in_range() else BLEND_SPEED_OUT))
	_sync_visuals()


func trigger_hit_flash() -> void:
	_hit_timer = HIT_FLASH_DURATION

func _is_in_range() -> bool:
	var player := _enemy.get_tree().current_scene.get_node_or_null("Player") as Node3D
	if player == null:
		return false
	return _enemy.global_position.distance_to(player.global_position) <= SWORD_RANGE


func _create_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("outline_color", _base_outline_color)
	mat.set_shader_parameter("glow_intensity", GLOW_DEFAULT)
	return mat


func _build_outline_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		if not _should_skip(node.name):
			_add_outline_for(node as MeshInstance3D)
	for child in node.get_children():
		_build_outline_meshes(child)


func _should_skip(mesh_name: String) -> bool:
	var lower := mesh_name.to_lower()
	for skip in SKIP_MESHES:
		if lower.contains(skip):
			return true
	return false


func _add_outline_for(original: MeshInstance3D) -> void:
	var outline := MeshInstance3D.new()
	outline.mesh = original.mesh
	outline.skeleton = original.skeleton
	outline.skin = original.skin
	outline.transform = original.transform
	outline.scale = original.scale * SCALE_DEFAULT

	var surfaces := original.mesh.get_surface_count() if original.mesh else 0
	for i in surfaces:
		outline.set_surface_override_material(i, _material)

	original.get_parent().add_child(outline)
	_meshes.append(outline)


func _sync_visuals() -> void:
	var hit_ratio := clampf(_hit_timer / HIT_FLASH_DURATION, 0.0, 1.0)
	var is_attacking := _enemy._combat._is_winding_up or _enemy._combat._is_idling_before_attack

	var base_color: Color
	var base_glow: float
	if is_attacking and hit_ratio <= 0.0:
		base_color = COLOR_ATTACKING
		base_glow = GLOW_ATTACKING
	else:
		base_color = _base_outline_color.lerp(COLOR_IN_RANGE, _range_blend)
		base_glow = lerpf(GLOW_DEFAULT, GLOW_IN_RANGE, _range_blend)

	var color := base_color.lerp(COLOR_HIT, hit_ratio)
	var glow := lerpf(base_glow, GLOW_HIT, hit_ratio)
	_material.set_shader_parameter("outline_color", color)
	_material.set_shader_parameter("glow_intensity", glow)

	var base_scale := lerpf(SCALE_DEFAULT, SCALE_IN_RANGE, _range_blend)
	var s := lerpf(base_scale, SCALE_HIT, hit_ratio)
	var scale_vec := Vector3(s, s, s)
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.scale = scale_vec
