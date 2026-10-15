class_name MissionBase
extends Node
## Cơ sở nhiệm vụ: marker mục tiêu, dọn dẹp; lớp con phát `completed` hoặc `failed(lý do)`.

signal completed
signal failed(reason_key: String)

var city: City
var _marker: Marker
var _mark_label := ""
var _spawned: Array = []  # không khai kiểu: có thể chứa node đã bị giải phóng


func mark(pos: Vector2, label_key := "") -> void:
	if _marker and label_key == _mark_label:  # cùng nhãn: chỉ dời vòng (mục tiêu di động gọi mỗi frame)
		_marker.global_position = pos
		return
	_mark_label = label_key
	if _marker:
		_marker.queue_free()
	_marker = Marker.make(city.effects, pos, Palette.MARKER, label_key)


func marker() -> Marker:
	return _marker


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


## Xe đỗ trên làn đường gần `pos` nhất (tìm trong `cells` ô), quay theo hướng làn.
func car_near(pos: Vector2, kind: String, sprite := "", cells := 12) -> Vehicle:
	var c0 := MapData.world_to_cell(pos)
	for r in range(1, cells):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and city.data.lane_dir(c) != Vector2i.ZERO:
					return track(city.spawn_vehicle(kind, c, Vector2(city.data.lane_dir(c)).angle(), sprite))
	return track(city.spawn_vehicle(kind, c0, 0.0, sprite))


## Toán Red Fangs canh quanh ô `center` (các ô đi được cách nhau 2 ô, gần trước xa sau).
func spawn_gang(center: Vector2i, count: int, ring := 3) -> Array[Gangster]:
	var spots: Array[Vector2i] = []
	for dy in range(-ring, ring + 1):
		for dx in range(-ring, ring + 1):
			var c := center + Vector2i(dx, dy) * 2
			if city.data.is_ped_walkable(c) or c == center:
				spots.append(c)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_to(center) < b.distance_to(center))
	var out: Array[Gangster] = []
	for i in count:
		out.append(track(city.spawn_npc(Gangster, MapData.cell_center(spots[i % spots.size()]))))
	return out


func cleanup() -> void:
	unmark()
	for n in _spawned:
		if is_instance_valid(n) and not (n is Vehicle and n.is_player_driven()):
			n.queue_free()
