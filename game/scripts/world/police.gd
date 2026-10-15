class_name Police
extends Node
## Truy nã: sinh cảnh sát (đi bộ, xe, đặc nhiệm, rào chắn, trực thăng) ngoài màn hình theo số sao;
## không bị thấy đủ lâu thì giảm sao. Chia lượt bắn: chỉ vài cảnh sát gần nhất trong tầm được nổ súng cùng lúc.

const COPS_PER_CAR := 2

var city: City
var unseen := 0.0
var heli: Helicopter
var roadblocks: Roadblocks
var _cars: Array = []  # không khai kiểu: có thể chứa xe đã bị giải phóng cho tới lần lọc kế tiếp
var _timer := 0.0
var _heli_cd := 0.0
var _turn_timer := 0.0


func _init(c: City) -> void:
	city = c
	name = "Police"
	roadblocks = Roadblocks.new(c)
	add_child(roadblocks)


func cops() -> Array[Node]:
	return get_tree().get_nodes_in_group("cops")


func _process(delta: float) -> void:
	_cars = _cars.filter(func(v: Variant) -> bool: return is_instance_valid(v))
	var stars := Game.stars
	for v in _cars:
		v.set_siren(stars > 0 and not v.wrecked and not v.is_player_driven())
	_update_heli(delta, stars)
	roadblocks.prune()
	if stars == 0 or not city.player.alive:
		unseen = 0.0
		_despawn_far(0.0)
		return
	roadblocks.tick(delta, stars)
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = Tuning.FIRE_TURN_EVERY
		_share_fire(stars)
	if _seen():
		unseen = 0.0
	else:
		unseen += delta
		if unseen > Tuning.LOSE_STAR_TIME[stars]:
			unseen = 0.0
			Game.lose_star()
	_timer -= delta
	if _timer <= 0.0:
		_timer = Tuning.POPULATION_TICK
		_despawn_far(Tuning.DESPAWN_DIST)
		_spawn(stars)


func _update_heli(delta: float, stars: int) -> void:
	_heli_cd -= delta
	if is_instance_valid(heli):
		if stars < Tuning.HELI_STARS or not city.player.alive:
			heli.leave()
		return
	if stars >= Tuning.HELI_STARS and _heli_cd <= 0.0 and city.player.alive:
		heli = Helicopter.new()
		heli.city = city
		heli.global_position = city.camera.get_screen_center_position() + Vector2.from_angle(randf() * TAU) * Tuning.SPAWN_MAX_DIST
		heli.downed.connect(func() -> void: _heli_cd = Tuning.HELI_RESPAWN)
		city.actors.add_child(heli)


func _seen() -> bool:
	if is_instance_valid(heli) and heli.sees_player():
		return true
	for c in cops():
		if c.sees_player():
			return true
	var target := city.player.global_position
	var space := city.get_world_2d().direct_space_state
	for v in _cars:
		if v.wrecked or v.is_player_driven() or v.global_position.distance_to(target) > Tuning.COP_SIGHT:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters2D.create(v.global_position, target, Tuning.LAYER_WORLD)).is_empty():
			return true
	return false


func _share_fire(stars: int) -> void:
	var target := city.player.vehicle.global_position if city.player.vehicle else city.player.global_position
	var in_range := cops().filter(func(c: Node) -> bool:
		return c.alive and c.global_position.distance_to(target) < Tuning.NPC_SHOOT_RANGE and c.can_see(target))
	in_range.sort_custom(func(a: Node, b: Node) -> bool:
		return a.global_position.distance_squared_to(target) < b.global_position.distance_squared_to(target))
	for c in cops():
		c.may_fire = false
	for i in mini(in_range.size(), Tuning.COP_SHOOTERS[stars]):
		in_range[i].may_fire = true


func _spawn(stars: int) -> void:
	var on_foot := cops().filter(func(c: Node) -> bool: return c.alive).size()
	var cars := _active("police")
	var vans := _active("swat")
	if on_foot < mini(Tuning.COPS_ON_FOOT[stars] + COPS_PER_CAR * cars + Tuning.SWAT_PER_VAN * vans, Tuning.MAX_COPS):
		var cell := _offscreen_cell(false)
		if cell.x >= 0:
			city.spawn_npc(Cop, MapData.cell_center(cell))
	if cars < Tuning.COP_CARS[stars]:
		_spawn_car("police")
	elif vans < Tuning.SWAT_VANS[stars]:
		_spawn_car("swat")


func _active(kind: String) -> int:
	return _cars.filter(func(v: Vehicle) -> bool: return v.kind == kind and v.autopilot is ChaseDriver and not v.wrecked).size()


func _spawn_car(kind: String) -> void:
	var cell := _offscreen_cell(true)
	if cell.x < 0:
		return
	var v := city.spawn_vehicle(kind, cell, Vector2(city.data.lane_dir(cell)).angle())
	var driver := ChaseDriver.new(city)
	driver.arrived.connect(_deploy, CONNECT_ONE_SHOT)
	v.autopilot = driver
	v.has_npc_driver = true
	_cars.append(v)


## Còn chỗ cho bao nhiêu cảnh sát còn sống (giới hạn chung cho cả người thả từ xe và rào chắn, giữ FPS).
func room() -> int:
	return Tuning.MAX_COPS - cops().filter(func(c: Node) -> bool: return c.alive).size()


func _deploy(v: Vehicle) -> void:
	var swat := v.kind == "swat"
	for i in maxi(mini(Tuning.SWAT_PER_VAN if swat else COPS_PER_CAR, room()), 0):
		city.spawn_npc(Swat if swat else Cop, v.exit_point() + Vector2(randf_range(-10, 10), randf_range(-10, 10)))


func _offscreen_cell(road: bool) -> Vector2i:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	var data := city.data
	for i in 30:
		var pos := center + Vector2.from_angle(randf() * TAU) * randf_range(Tuning.SPAWN_MIN_DIST, Tuning.SPAWN_MAX_DIST)
		var cell := MapData.world_to_cell(pos)
		var ok := data.lane_dir(cell) != Vector2i.ZERO if road else not data.is_solid(cell)
		if ok and data.in_bounds(cell) and not view.has_point(MapData.cell_center(cell)):
			return cell
	return Vector2i(-1, -1)


func _despawn_far(dist: float) -> void:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	for c in cops():
		var far: bool = c.global_position.distance_to(center) > dist and not view.has_point(c.global_position)
		if far and (dist > 0.0 or not c.alive or Game.stars == 0):
			c.queue_free()
	for v in _cars.duplicate():
		if is_instance_valid(v) and not v.is_player_driven() and v.global_position.distance_to(center) > maxf(dist, Tuning.DESPAWN_DIST) and not view.has_point(v.global_position):
			_cars.erase(v)
			v.queue_free()


func clear_all() -> void:
	roadblocks.clear_all()
	if is_instance_valid(heli):
		heli.queue_free()
	heli = null
	_heli_cd = 0.0
	for c in cops():
		c.queue_free()
	for v in _cars:
		if is_instance_valid(v) and not v.is_player_driven():
			v.queue_free()
	_cars.clear()
	unseen = 0.0
