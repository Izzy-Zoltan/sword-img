class_name SwordHitbox
extends Area3D

var slash_lane := "center"


func set_active(active: bool) -> void:
	monitoring = active
	monitorable = active


func set_slash_lane(lane: String) -> void:
	slash_lane = lane
