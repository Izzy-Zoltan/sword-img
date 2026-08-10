class_name SwordHealth
extends Node

signal health_changed(new_health: int)
signal died

@export var max_health: int = 5

var health: int


func _ready() -> void:
	health = max_health
	health_changed.emit(health)


func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health = max(health - amount, 0)
	health_changed.emit(health)

	_flash_damage_screen()

	if health <= 0:
		died.emit()


func _flash_damage_screen() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	get_parent().add_child(canvas)

	var rect := ColorRect.new()
	rect.color = Color(0.8, 0.05, 0.0, 0.45)
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)

	var tween := get_tree().create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(canvas.queue_free)
