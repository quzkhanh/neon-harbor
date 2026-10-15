extends MissionBase
## NV8 Shipment: cướp xe bán tải chở hàng ở bãi đường ray (t) có Red Fangs canh; chạy khỏi bãi thì cảnh sát được báo
## (3 sao); cắt đuôi rồi đưa xe về gara.

const GARAGE_RADIUS := 120.0

var truck: Vehicle
var _stolen := false
var _start := Vector2.ZERO


func _ready() -> void:
	truck = car_near(cell_pos("t"), "pickup", "car_green_4")
	truck.set_meta("mission", true)
	truck.hp = Tuning.M8_TRUCK_HP  # xe chở tiền bọc thép
	_start = truck.global_position
	spawn_gang(city.data.find("t"), Tuning.M8_GUARDS)
	Game.set_objective("M8_OBJ_STEAL")
	mark(truck.global_position)


func _process(_delta: float) -> void:
	if not is_instance_valid(truck) or truck.wrecked or truck.burning:
		failed.emit("M8_FAIL_TRUCK")
		return
	var driving := city.player.vehicle == truck
	if driving and not _stolen and truck.global_position.distance_to(_start) > Tuning.M8_ALARM_DIST:
		_stolen = true
		Game.set_stars(3)
	if not _stolen:
		return
	var state := "M8_OBJ_BACK"
	if driving:
		state = "M3_OBJ_LOSE" if Game.stars > 0 else "M8_OBJ_GARAGE"
	if state != Game.objective:
		Game.set_objective(state)
		match state:
			"M8_OBJ_BACK":
				mark(truck.global_position)
			"M3_OBJ_LOSE":
				unmark()
			"M8_OBJ_GARAGE":
				mark(cell_pos("G"))
	if state == "M8_OBJ_GARAGE" and near(cell_pos("G"), GARAGE_RADIUS):
		city.player.exit_vehicle()
		completed.emit()
