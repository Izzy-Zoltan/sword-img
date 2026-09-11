class_name ESP32SwordInput
extends SwordInputProvider

@export var udp_port: int = 4242
@export var gyro_sensitivity: float = 0.0001

var _rotation_delta := Vector2.ZERO
var _udp: PacketPeerUDP
var _connected := false


func _ready() -> void:
	_udp = PacketPeerUDP.new()
	_udp.bind(udp_port)
	print("[ESP32] Listening on UDP port %d" % udp_port)


func _process(_delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var packet := _udp.get_packet().get_string_from_utf8().strip_edges()
		if not _connected:
			_connected = true
			print("[ESP32] Connected - receiving data")
		_parse_packet(packet)


func _parse_packet(packet: String) -> void:
	if packet.begins_with("R:"):
		var parts := packet.substr(2).split(",")
		if parts.size() >= 3:
			var gx := parts[0].to_float()
			var gy := parts[1].to_float()
			var gz := parts[2].to_float()
			_rotation_delta.x += gz * gyro_sensitivity
			_rotation_delta.y += gx * gyro_sensitivity


func get_rotation_delta() -> Vector2:
	var delta := _rotation_delta
	_rotation_delta = Vector2.ZERO
	return delta

func is_esp32_connected() -> bool:
	return _connected


func _exit_tree() -> void:
	if _udp != null:
		_udp.close()
