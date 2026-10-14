extends MissionBase
## NV1 First Delivery: lên xe máy, chở gói hàng tới điểm hẹn trước khi hết giờ (màn dạy lái xe).

const BIKE_SEARCH := 200.0
const ARRIVE_RADIUS := 80.0

var bike: Vehicle
var time_left := Tuning.MISSION1_TIME
var _riding := false


func _ready() -> void:
	var spot := cell_pos("m")
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.kind == "moto" and not v.wrecked and v.global_position.distance_to(spot) < BIKE_SEARCH:
			bike = v
	if bike == null:
		bike = track(city.spawn_vehicle("moto", city.data.find("m"), -PI * 0.5))
	Game.set_objective("M1_OBJ_BIKE")
	mark(bike.global_position)


func _process(delta: float) -> void:
	if not is_instance_valid(bike) or bike.wrecked:
		failed.emit("M1_FAIL_BIKE")
		return
	var riding := city.player.vehicle == bike
	if riding != _riding:
		_riding = riding
		if riding:
			mark(cell_pos("d"))
		else:
			mark(bike.global_position)
			Game.set_objective("M1_OBJ_BIKE")
	if _riding:
		time_left -= delta
		Game.set_objective("M1_OBJ_DELIVER", {"time": ceili(time_left)})
		if near(cell_pos("d"), ARRIVE_RADIUS):
			completed.emit()
		elif time_left <= 0.0:
			failed.emit("M1_FAIL_LATE")
