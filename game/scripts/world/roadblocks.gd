class_name Roadblocks
extends Node
## Từ Tuning.ROADBLOCK_STARS sao: định kỳ chặn đường phía trước xe người chơi (ngoài khung hình): một xe cảnh sát
## nằm ngang lòng đường, dải đinh trước nó, hai cảnh sát đứng hai bên. Rào chắn ở quá xa thì dọn.

var city: City
var _timer := Tuning.ROADBLOCK_EVERY * 0.5
var _blocks: Array = []  # mỗi phần tử: {"pos": Vector2, "nodes": Array}


func _init(c: City) -> void:
	city = c
	name = "Roadblocks"


func tick(delta: float, stars: int) -> void:
	if stars < Tuning.ROADBLOCK_STARS:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Tuning.ROADBLOCK_EVERY
	var v := city.player.vehicle
	if v and v.velocity.length() > Tuning.ROADBLOCK_MIN_SPEED and _blocks.size() < Tuning.MAX_ROADBLOCKS:
		var spot := find_spot(v.global_position, v.velocity)
		if not spot.is_empty():
			_build(spot)


## Đoạn đường thẳng hai làn phía trước theo hướng chạy, ngoài khung hình: {center, along, across} hoặc {}.
func find_spot(from: Vector2, velocity: Vector2) -> Dictionary:
	var d := Vector2i(signi(roundi(velocity.x)), 0) if absf(velocity.x) > absf(velocity.y) else Vector2i(0, signi(roundi(velocity.y)))
	var start := MapData.world_to_cell(from)
	var view := city.view_rect().grow(Tuning.TILE)
	for k in range(Tuning.ROADBLOCK_AHEAD.x, Tuning.ROADBLOCK_AHEAD.y):
		var cell := start + d * k
		var lane := city.data.lane_dir(cell)
		if lane != d and lane != -d:
			continue
		for side in [Vector2i(d.y, -d.x), Vector2i(-d.y, d.x)]:
			if city.data.lane_dir(cell + side) == -lane:
				var center := (MapData.cell_center(cell) + MapData.cell_center(cell + side)) * 0.5
				if not view.has_point(center):
					return {"center": center, "along": Vector2(d), "across": Vector2(side)}
	return {}


func _build(spot: Dictionary) -> void:
	var center: Vector2 = spot.center
	var along: Vector2 = spot.along
	var across: Vector2 = spot.across
	var car := city.spawn_vehicle("police", MapData.world_to_cell(center), across.angle())
	car.global_position = center
	city.police._cars.append(car)  # còi/đèn và dọn xe theo Police như xe cảnh sát khác
	var nodes: Array = [car, SpikeStrip.make(city.effects, center - along * Tuning.TILE * 1.6, across.angle(), Tuning.TILE * 2.0)]
	for s in [-1.0, 1.0].slice(0, maxi(city.police.room(), 0)):
		var pos: Vector2 = center + across * s * Tuning.TILE * 1.7 + along * Tuning.TILE * 0.6
		if city.data.is_solid(MapData.world_to_cell(pos)):
			pos = center + across * s * Tuning.TILE * 0.5 + along * Tuning.TILE * 1.6
		nodes.append(city.spawn_npc(Cop, pos))
	_blocks.append({"pos": center, "nodes": nodes})


func prune() -> void:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	for b in _blocks.duplicate():
		if b.pos.distance_to(center) > Tuning.DESPAWN_DIST and not view.has_point(b.pos):
			for n in b.nodes:
				if is_instance_valid(n) and not (n is Vehicle and n.is_player_driven()):
					n.queue_free()
			_blocks.erase(b)


func clear_all() -> void:
	for b in _blocks:
		for n in b.nodes:
			if is_instance_valid(n) and not (n is Vehicle and n.is_player_driven()):
				n.queue_free()
	_blocks.clear()
	_timer = Tuning.ROADBLOCK_EVERY * 0.5
