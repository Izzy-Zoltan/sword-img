class_name ChargedProjectile
extends Area3D

@export var speed := 28.0
@export var lifetime := 0.7
@export var arc_radius := 0.92
@export var arc_thickness := 0.22
@export var arc_degrees := 150.0

static var _cached_slash_mesh: Mesh
var _direction := Vector3.FORWARD
var _starting_lifetime := lifetime
var _material: StandardMaterial3D


func _ready() -> void:
	if _cached_slash_mesh == null:
		_cached_slash_mesh = _create_slash_mesh()
	connect("body_entered", Callable(self, "_on_body_entered"))


func launch(direction: Vector3) -> void:
	_direction = direction.normalized()
	look_at(global_position + _direction, Vector3.UP)
	_build_slash_wave()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	rotate_object_local(Vector3.FORWARD, delta * 1.8)
	lifetime -= delta
	var fade := maxf(lifetime / maxf(_starting_lifetime, 0.001), 0.0)
	if _material != null:
		var color := _material.albedo_color
		color.a = fade * 0.85
		_material.albedo_color = color
		_material.emission_energy_multiplier = 3.0 * fade
	var expansion := 1.0 + (1.0 - fade) * 0.24
	scale = Vector3.ONE * expansion
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(_body: Node3D) -> void:
	queue_free()


func _build_slash_wave() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _cached_slash_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true
	_material.emission = Color(0.12, 0.72, 1.0)
	_material.emission_energy_multiplier = 3.0
	mesh_instance.material_override = _material
	add_child(mesh_instance)


func _create_slash_mesh() -> Mesh:
	var slash_mesh := ImmediateMesh.new()
	slash_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	var segments := 12
	for index in range(segments + 1):
		var progress := float(index) / segments
		var angle := lerpf(-half_arc, half_arc, progress)
		var outer := Vector3(cos(angle), sin(angle), 0.0) * arc_radius
		var inner := Vector3(cos(angle), sin(angle), 0.0) * (arc_radius - arc_thickness)
		slash_mesh.surface_set_color(Color(0.18, 0.92, 1.0, 0.42))
		slash_mesh.surface_add_vertex(outer)
		slash_mesh.surface_set_color(Color(0.72, 0.98, 1.0, 0.9))
		slash_mesh.surface_add_vertex(inner)
	slash_mesh.surface_end()
	return slash_mesh
