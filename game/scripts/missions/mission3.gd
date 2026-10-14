extends MissionBase
## NV3 Harbor Heist: cướp xe mục tiêu ở bến cảng, cắt đuôi truy nã 2 sao, đưa xe về gara.

const GARAGE_RADIUS := 120.0

var car: Vehicle
var _stolen := false


func _ready() -> void:
	car = track(city.spawn_vehicle("sports", city.data.find("k"), 0.0))
	car.set_meta("mission", true)
	Game.set_objective("M3_OBJ_STEAL")
	mark(car.global_position)


func _process(_delta: float) -> void:
	if not is_instance_valid(car) or car.wrecked or car.burning:
		failed.emit("M3_FAIL_CAR")
		return
	var driving := city.player.vehicle == car
	if driving and not _stolen:
		_stolen = true
		Game.set_stars(2)
	if not _stolen:
		return
	var state := "M3_OBJ_BACK"
	if driving:
		state = "M3_OBJ_LOSE" if Game.stars > 0 else "M3_OBJ_GARAGE"
	if state != Game.objective:
		Game.set_objective(state)
		match state:
			"M3_OBJ_BACK":
				mark(car.global_position)
			"M3_OBJ_LOSE":
				unmark()
			"M3_OBJ_GARAGE":
				mark(cell_pos("G"))
	if state == "M3_OBJ_GARAGE" and near(cell_pos("G"), GARAGE_RADIUS):
		city.player.exit_vehicle()
		completed.emit()
