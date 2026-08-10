class_name SwordCharge
extends Node

signal charge_changed(points: int, max_points: int)

@export var hits_per_charge: int = 3

var charge_points: int = 0
var suppress_charge_gain: bool = false

var _sword_material: StandardMaterial3D
var _default_blade_color: Color
var _default_emission_energy := 0.0
var _move_system: SwordMoveSystem


func setup(sword_material: StandardMaterial3D, move_system: SwordMoveSystem) -> void:
	_sword_material = sword_material
	_default_blade_color = sword_material.albedo_color
	_default_emission_energy = sword_material.emission_energy_multiplier
	_move_system = move_system
	charge_changed.emit(charge_points, hits_per_charge)


func notify_slash_hit() -> void:
	if suppress_charge_gain:
		return
	if charge_points >= hits_per_charge:
		return
	charge_points += 1
	charge_changed.emit(charge_points, hits_per_charge)


func can_charge() -> bool:
	return charge_points >= hits_per_charge


func consume_charge() -> void:
	charge_points = 0
	charge_changed.emit(charge_points, hits_per_charge)


func update_glow() -> void:
	if _sword_material == null:
		return
	if charge_points >= hits_per_charge and _move_system.state == SwordMoveSystem.State.IDLE:
		var flash := maxf(sin(Time.get_ticks_msec() * 0.004), 0.0)
		var charge_color := Color(0.3, 0.9, 1.0)
		_sword_material.albedo_color = _default_blade_color.lerp(charge_color, flash)
		_sword_material.emission_enabled = flash > 0.1
		_sword_material.emission = charge_color * flash
		_sword_material.emission_energy_multiplier = _default_emission_energy + flash * 3.0
	elif _move_system.state == SwordMoveSystem.State.IDLE:
		_sword_material.albedo_color = _default_blade_color
		_sword_material.emission_energy_multiplier = _default_emission_energy
		_sword_material.emission_enabled = false
