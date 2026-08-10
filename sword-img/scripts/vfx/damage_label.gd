class_name DamageLabel
extends Label3D

const _FONT := preload("res://Assets/PixelifySans-Bold.ttf")

static func show_damage(parent: Node, pos: Vector3, amount: int) -> void:
	_spawn(
		parent, pos,
		"-%d HP" % amount,
		44, 0.008,
		Color(1.0, 0.25, 0.1),
		5,
		1.2, 0.55,
		0.12
	)

static func show_fatal(parent: Node, pos: Vector3) -> void:
	_spawn(
		parent, pos,
		"FATAL!",
		56, 0.008,
		Color(1.0, 0.9, 0.1),
		5,
		1.2, 0.55,
		0.12
	)

static func show_miss(parent: Node, camera: Camera3D) -> void:
	var forward := -camera.global_transform.basis.z
	var pos := camera.global_position \
		+ forward * 2.2 \
		+ Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.15), 0.0)
	_spawn(
		parent, pos,
		"MISS",
		42, 0.007,
		Color(0.7, 0.8, 0.9, 0.8),
		5,
		0.6, 0.45,
		0.1,
		false
	)

static func _spawn(
	parent: Node,
	pos: Vector3,
	color: Color,
	rise_amount: float,
	duration: float,
	fade_delay: float,
	scale_pop: bool = true
) -> void:
	var label := DamageLabel.new()
	label.text = text
	label.font = _FONT
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_render_priority = 1
	label.outline_size = outline_size
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)

	parent.add_child(label)
	label.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))

	var tween := label.get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + rise_amount, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if scale_pop:
		tween.tween_property(label, "scale", Vector3.ONE * 1.35, 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(label, "scale", Vector3.ONE, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_delay(fade_delay)
	tween.chain().tween_callback(label.queue_free)
