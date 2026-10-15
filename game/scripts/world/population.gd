class_name Population
extends Node
## Giữ số người đi đường và xe tự lái quanh camera: sinh ngoài màn hình, xoá khi đi quá xa.
## Sau NV2 và trước khi xong NV9, Red Fangs canh gác trong lãnh địa của chúng (Tuning.GANG_TURF) và bắn khi thấy Jay.

const SPAWN_TRIES := 24
const CAR_CLEARANCE := 150.0
const START_CLEARANCE := 220.0
const STUCK_DESPAWN := 15.0  # xe tự lái bị chặn chừng này giây mà không ai nhìn thấy thì xoá (gỡ kẹt)

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


## Số người đi đường tối đa lúc này: theo giờ trong ngày (Tuning.PED_DENSITY).
func ped_cap() -> int:
	var table: Array = Tuning.PED_DENSITY
	for i in range(1, table.size()):
		if Game.clock <= table[i][0]:
			var t := inverse_lerp(table[i - 1][0], table[i][0], Game.clock)
			return roundi(Tuning.MAX_PEDS * lerpf(table[i - 1][1], table[i][1], t))
	return Tuning.MAX_PEDS


func peds() -> Array[Node]:
	return get_tree().get_nodes_in_group("peds")


func _fill(initial: bool) -> void:
	var budget := 99 if initial else 2
	while budget > 0 and peds().size() < ped_cap():
		budget -= 1
		var cell := pick_cell(_walk_cells, initial)
		if cell.x < 0:
			break
		city.spawn_npc(Pedestrian, MapData.cell_center(cell)).add_to_group("peds")
	if _turf_active() and get_tree().get_nodes_in_group("turf").size() < Tuning.MAX_TURF_GANG:
		var cell := pick_cell(_walk_cells, initial)
		if cell.x >= 0 and DataDB.district_at(cell) in Tuning.GANG_TURF:
			city.spawn_npc(Gangster, MapData.cell_center(cell)).add_to_group("turf")
	budget = 99 if initial else 1
	while budget > 0 and cars.size() < Tuning.MAX_CARS:
		budget -= 1
		var cell := pick_cell(_lane_cells, initial)
		if cell.x < 0 or _car_near(MapData.cell_center(cell)):
			continue
		var v := city.spawn_vehicle(DataDB.traffic_kind(), cell, Vector2(city.data.lane_dir(cell)).angle())
		v.autopilot = TrafficDriver.new(city.data, cell)
		v.has_npc_driver = true
		cars.append(v)


## Ô ngẫu nhiên trong vành đai quanh camera, ngoài khung hình (lúc khởi tạo: chỉ cần xa người chơi).
func pick_cell(cells: Array[Vector2i], initial: bool) -> Vector2i:
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


## Lãnh địa Red Fangs: sau NV2, trước khi xong NV9, và không trong lúc làm nhiệm vụ (nhiệm vụ tự cân số địch).
func _turf_active() -> bool:
	return 2 in Game.missions_done and not 9 in Game.missions_done and city.missions != null and city.missions.current == null


func _stuck(v: Vehicle) -> bool:
	return v.autopilot is TrafficDriver and v.autopilot.stuck_time() > STUCK_DESPAWN


func _despawn() -> void:
	var center := city.camera.get_screen_center_position()
	var view := city.view_rect().grow(Tuning.TILE)
	var surplus := peds().size() - ped_cap()  # trời về đêm: bớt dần người ngoài khung hình cho khớp mật độ
	for p in peds() + get_tree().get_nodes_in_group("turf"):
		var offscreen := not view.has_point(p.global_position)
		if offscreen and (p.global_position.distance_to(center) > Tuning.DESPAWN_DIST or (surplus > 0 and p.is_in_group("peds"))):
			surplus -= 1
			p.queue_free()
	cars = cars.filter(func(v: Variant) -> bool: return is_instance_valid(v))
	for v in cars.duplicate():
		if v.is_player_driven() or not v.has_npc_driver:
			cars.erase(v)
		elif not view.has_point(v.global_position) and (v.global_position.distance_to(center) > Tuning.DESPAWN_DIST or _stuck(v)):
			cars.erase(v)
			v.queue_free()
