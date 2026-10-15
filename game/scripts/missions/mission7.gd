extends MissionBase
## NV7 Inside Man: lái xe tới đón người cung cấp tin (i), chở anh ta tới nơi an toàn (e) trong khi xe Red Fangs truy đuổi.

const SKIN := "survivor1"
const BOARD := 120.0
const STOP_SPEED := 80.0

var _car: Vehicle  # xe đang chở người cung cấp tin
var _vince: Sprite2D
var _aboard := false


func _ready() -> void:
	car_near(city.player.global_position, "pickup", "car_green_4")  # xe bán tải trâu: chịu được xe truy đuổi
	_vince = track(Sprite2D.new())
	_vince.texture = load(Human.CHAR_DIR % [SKIN, "hold"])
	_vince.global_position = cell_pos("i")
	city.effects.add_child(_vince)
	Game.set_objective("M7_OBJ_PICKUP")
	mark(cell_pos("i"))


func _process(_delta: float) -> void:
	var v := city.player.vehicle
	if not _aboard:
		if v and v.velocity.length() < STOP_SPEED and v.global_position.distance_to(cell_pos("i")) < BOARD:
			_board(v)
		return
	if not is_instance_valid(_car) or _car.wrecked or _car.burning:
		failed.emit("M7_FAIL_VINCE")
		return
	if v != _car:
		if Game.objective != "M7_OBJ_BACK":
			Game.set_objective("M7_OBJ_BACK")
			mark(_car.global_position)
		return
	if Game.objective != "M7_OBJ_SAFE":
		Game.set_objective("M7_OBJ_SAFE")
		mark(cell_pos("e"))
	if _car.velocity.length() < STOP_SPEED and _car.global_position.distance_to(cell_pos("e")) < BOARD:
		completed.emit()


func _board(v: Vehicle) -> void:
	_aboard = true
	_car = v
	_car.set_meta("mission", true)
	_car.hp = maxf(_car.hp, Tuning.M7_CAR_HP)  # Rosa gia cố xe: chịu được một lúc đạn của xe truy đuổi
	_vince.queue_free()
	Sfx.play_at("door", v.global_position)
	Game.notice.emit(tr("NOTICE_FANGS_TAIL"))
	var behind := (v.global_position - cell_pos("e")).normalized()  # truy đuổi từ phía sau, không chặn đầu
	for i in Tuning.M7_CHASERS:
		var spot := v.global_position + behind.rotated((i - (Tuning.M7_CHASERS - 1) * 0.5) * 0.6) * Tuning.SPAWN_MIN_DIST
		var chaser := car_near(spot, "car", "car_black_3")
		chaser.set_meta("mission", true)
		var driver := ChaseDriver.new(city)
		driver.arrived.connect(_deploy)
		chaser.autopilot = driver
		chaser.has_npc_driver = true


## Xe truy đuổi bắt kịp thì thả bọn Red Fangs xuống bắn (một lần mỗi xe).
func _deploy(chaser: Vehicle) -> void:
	if chaser.has_meta("deployed"):
		return
	chaser.set_meta("deployed", true)
	for k in 2:
		var g: Gangster = track(city.spawn_npc(Gangster, chaser.exit_point() + Vector2(randf_range(-12, 12), randf_range(-12, 12))))
		g.alert()
