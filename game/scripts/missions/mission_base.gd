class_name MissionBase
extends Node
## Cơ sở nhiệm vụ: marker mục tiêu, dọn dẹp; lớp con phát `completed` hoặc `failed(lý do)`.

signal completed
signal failed(reason_key: String)

var city: City
var _marker: Marker
var _spawned: Array = []  # không khai kiểu: có thể chứa node đã bị giải phóng


func mark(pos: Vector2, label_key := "") -> void:
	if _marker:
		_marker.queue_free()
	_marker = Marker.make(city.effects, pos, Palette.MARKER, label_key)


func unmark() -> void:
	if _marker:
		_marker.queue_free()
		_marker = null


func track(node: Node) -> Node:
	_spawned.append(node)
	return node


func cell_pos(ch: String) -> Vector2:
	return MapData.cell_center(city.data.find(ch))


func near(pos: Vector2, radius := Tuning.MISSION_RADIUS) -> bool:
	var p := city.player
	var at := p.vehicle.global_position if p.vehicle else p.global_position
	return at.distance_to(pos) < radius


func cleanup() -> void:
	unmark()
	for n in _spawned:
		if is_instance_valid(n) and not (n is Vehicle and n.is_player_driven()):
			n.queue_free()
