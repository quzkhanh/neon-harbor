class_name Population
extends Node
## Giữ số người đi đường và xe tự lái quanh camera: sinh ngoài màn hình, xoá khi đi quá xa.

const SPAWN_TRIES := 24
const CAR_CLEARANCE := 150.0
const START_CLEARANCE := 220.0

var city: City
var cars: Array = []  # không khai kiểu: có thể chứa xe đã bị giải phóng cho tới lần lọc kế tiếp
var _walk_cells: Array[Vector2i] = []
var _lane_cells: Array[Vector2i] = []
var _timer := 0.0


func _init(c: City) -> void:
	city = c
	name = "Population"


func _ready() -> void:
	for ch in ",:":
		_walk_cells.append_array(city.data.find_all(ch))
	for ch in MapData.LANES:
		_lane_cells.append_array(city.data.find_all(ch))
	_fill(true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = Tuning.POPULATION_TICK
		_despawn()
		_fill(false)


func peds() -> Array[Node]:
	return get_tree().get_nodes_in_group("peds")


func _fill(initial: bool) -> void:
	var budget := 99 if initial else 2
	while budget > 0 and peds().size() < Tuning.MAX_PEDS:
		budget -= 1
		var cell := _pick(_walk_cells, initial)
		if cell.x < 0:
			break
		city.spawn_npc(Pedestrian, MapData.cell_center(cell)).add_to_group("peds")
	budget = 99 if initial else 1
	while budget > 0 and cars.size() < Tuning.MAX_CARS:
		budget -= 1
		var cell := _pick(_lane_cells, initial)
		if cell.x < 0 or _car_near(MapData.cell_center(cell)):
			continue
		var v := city.spawn_vehicle("car", cell, Vector2(city.data.lane_dir(cell)).angle())
		v.autopilot = TrafficDriver.new(city.data, cell)
		v.has_npc_driver = true
		cars.append(v)


## Ô ngẫu nhiên trong vành đai quanh camera, ngoài khung hình (lúc khởi tạo: chỉ cần xa người chơi).
func _pick(cells: Array[Vector2i], initial: bool) -> Vector2i:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	for i in SPAWN_TRIES:
		var cell: Vector2i = cells[randi() % cells.size()]
		var pos := MapData.cell_center(cell)
		var d := pos.distance_to(center)
		if initial and d < Tuning.SPAWN_MAX_DIST and pos.distance_to(city.player.global_position) > START_CLEARANCE:
			return cell
		if not initial and d > Tuning.SPAWN_MIN_DIST and d < Tuning.SPAWN_MAX_DIST and not view.has_point(pos):
			return cell
	return Vector2i(-1, -1)


func _car_near(pos: Vector2) -> bool:
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(pos) < CAR_CLEARANCE:
			return true
	return false


func _despawn() -> void:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	for p in peds():
		if p.global_position.distance_to(center) > Tuning.DESPAWN_DIST and not view.has_point(p.global_position):
			p.queue_free()
	cars = cars.filter(func(v: Variant) -> bool: return is_instance_valid(v))
	for v in cars.duplicate():
		if v.is_player_driven() or not v.has_npc_driver:
			cars.erase(v)
		elif v.global_position.distance_to(center) > Tuning.DESPAWN_DIST and not view.has_point(v.global_position):
			cars.erase(v)
			v.queue_free()
