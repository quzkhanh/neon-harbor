extends MissionBase
## NV4 Tail Job: bám đuôi xe đưa tin của Red Fangs tới kho của chúng (w). Quá gần thì bị phát hiện, quá xa thì mất dấu.

var courier: Vehicle
var _car: Vehicle
var _close := 0.0


func _ready() -> void:
	_car = car_near(city.player.global_position, "car", "car_blue_2")
	courier = car_near(city.player.global_position + Vector2(0, -Tuning.TILE * 6), "car", "car_black_2")
	if courier.global_position.distance_to(_car.global_position) < Tuning.TILE * 2.0:
		courier.global_position += courier.forward() * Tuning.TILE * 3.0
	courier.set_meta("mission", true)
	courier.hp = Tuning.M4_COURIER_HP  # xe đưa tin lách dòng xe: va quẹt không được làm hỏng nhiệm vụ
	var driver := GotoDriver.new(city)
	driver.target = cell_pos("w")
	driver.ratio = Tuning.M4_COURIER_SPEED
	driver.waiting = true
	courier.autopilot = driver
	courier.has_npc_driver = true
	Game.set_objective("M4_OBJ_CAR")
	mark(_car.global_position)


func _process(delta: float) -> void:
	if not is_instance_valid(courier) or courier.wrecked or courier.burning:
		failed.emit("M4_FAIL_COURIER")
		return
	if not courier.autopilot is GotoDriver:  # lỡ bị cướp xe: coi như lộ
		failed.emit("M4_FAIL_SPOTTED")
		return
	var driver: GotoDriver = courier.autopilot
	if driver.waiting:
		if city.player.vehicle:
			driver.waiting = false
			unmark()
		return
	var me := city.player.vehicle.global_position if city.player.vehicle else city.player.global_position
	var dist := me.distance_to(courier.global_position)
	driver.ratio = Tuning.M4_COURIER_SPEED * (Tuning.M4_LAG_SLOWDOWN if dist > Tuning.M4_TOO_FAR * 0.6 else 1.0)  # tụt xa (kẹt xe): hắn chạy chậm lại
	_close = _close + delta if dist < Tuning.M4_TOO_CLOSE else 0.0
	if driver.arrived:
		completed.emit()
	elif _close > Tuning.M4_SPOT_TIME:
		failed.emit("M4_FAIL_SPOTTED")
	elif dist > Tuning.M4_TOO_FAR:
		failed.emit("M4_FAIL_LOST")
	else:
		Game.set_objective("M4_OBJ_CLOSE" if dist < Tuning.M4_TOO_CLOSE else ("M4_OBJ_FAR" if dist > Tuning.M4_TOO_FAR * 0.7 else "M4_OBJ_TAIL"))
