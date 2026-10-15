class_name RoadIncidents
extends Node
## Thỉnh thoảng dựng một vụ va chạm xe trên đoạn đường thẳng gần Jay (RoadIncident), ngoài khung hình, để có kẹt xe có
## nguyên nhân thật: xe sau dồn lại bấm còi cho tới khi hai tài xế cãi xong và đi. Mỗi lúc chỉ một vụ; không dựng khi
## đang làm nhiệm vụ, đang bị truy nã hoặc Jay đã chết.

const FIRST_DELAY := Vector2(20.0, 40.0)
const EVERY := Vector2(50.0, 100.0)
const RETRY := 3.0
const STRAIGHT := 3  # đoạn đường thẳng (ô) mỗi bên chỗ va chạm, không có giao lộ
const CLEARANCE := 170.0  # không dựng gần xe khác (trừ xe sẽ đứng chờ phía sau)

var city: City
var _timer := randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
var _active: RoadIncident
var _lanes: Array[Vector2i] = []


func _init(c: City) -> void:
	city = c
	name = "RoadIncidents"


func _ready() -> void:
	for ch in MapData.LANES:
		_lanes.append_array(city.data.find_all(ch))


func _process(delta: float) -> void:
	if is_instance_valid(_active):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = RETRY
	if not _allowed():
		return
	var cell := city.population.pick_cell(_lanes, false)
	if cell.x >= 0 and _straight(cell) and not _crowded(MapData.cell_center(cell)):
		_stage(cell)
		_timer = randf_range(EVERY.x, EVERY.y)


func _allowed() -> bool:
	return city.player.alive and Game.stars == 0 and city.missions.current == null and not city.activities.busy()


func _straight(cell: Vector2i) -> bool:
	var d := city.data.lane_dir(cell)
	for k in range(-STRAIGHT, STRAIGHT + 1):
		if city.data.lane_dir(cell + d * k) != d:
			return false
	return true


func _crowded(pos: Vector2) -> bool:
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.global_position.distance_to(pos) < CLEARANCE:
			return true
	return false


func _stage(cell: Vector2i) -> void:
	var dir := Vector2(city.data.lane_dir(cell))
	var front := city.spawn_vehicle(DataDB.traffic_kind(), cell, dir.angle())
	var rear := city.spawn_vehicle(DataDB.traffic_kind(), cell, dir.angle())
	for v in [front, rear]:
		city.population.cars.append(v)
	_active = RoadIncident.new()
	_active.city = city
	add_child(_active)
	_active.start(front, rear, dir)
