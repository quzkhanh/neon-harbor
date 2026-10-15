extends MissionBase
## Việc phụ: tuần tra tự quản. Đang lái xe cảnh sát (không bị truy nã) thì có xe tội phạm bỏ chạy; làm xe đó hỏng
## nặng thì tên tội phạm nhảy ra chống trả, hạ hắn để nhận thưởng (mỗi tên sau thưởng nhiều hơn). Xuống xe là nghỉ.

const KINDS := ["car", "compact", "sports", "pickup"]

var reward := 0
var level := 0
var _cruiser: Vehicle
var _car: Vehicle
var _crook: Gangster
var _time := 0.0


func _ready() -> void:
	_cruiser = city.player.vehicle
	_next()


func _next() -> void:
	level += 1
	_time = Tuning.VIGILANTE_TIME
	_crook = null
	var from := _cruiser.global_position
	var cell := Vector2i(-1, -1)
	for i in 60:
		var c := MapData.world_to_cell(from + Vector2.from_angle(randf() * TAU) * randf_range(700.0, 1100.0))
		if city.data.lane_dir(c) != Vector2i.ZERO:
			cell = c
			break
	if cell.x < 0:
		cell = MapData.world_to_cell(from)
	_car = track(city.spawn_vehicle(KINDS[randi() % KINDS.size()], cell, Vector2(city.data.lane_dir(cell)).angle()))
	_car.set_meta("mission", true)
	_car.autopilot = FleeDriver.new(city)
	_car.has_npc_driver = true
	Game.notice.emit(tr("NOTICE_VIGILANTE_NEW"))


func _process(delta: float) -> void:
	if city.player.vehicle != _cruiser or Game.stars > 0:
		Game.notice.emit(tr("NOTICE_VIGILANTE_OFF"))
		completed.emit()
		return
	_time -= delta
	if _time <= 0.0:
		failed.emit("FAIL_TIME")
		return
	if _crook == null:
		Game.set_objective("VIGILANTE_OBJ_CAR", {"time": ceili(_time)})
		if not is_instance_valid(_car):
			_next()
			return
		mark(_car.global_position)
		if _car.wrecked or _car.burning or _car.hp < float(_car.spec.hp) * Tuning.VIGILANTE_DISABLE:
			_bail()
	else:
		Game.set_objective("VIGILANTE_OBJ_CROOK", {"time": ceili(_time)})
		if is_instance_valid(_crook):
			mark(_crook.global_position)


## Xe hỏng: tên tội phạm nhảy ra bắn trả.
func _bail() -> void:
	_car.autopilot = null
	_car.has_npc_driver = false
	_crook = track(city.spawn_npc(Gangster, _car.exit_point()))
	_crook.alert()
	_crook.died.connect(func(_h: Human) -> void:
		var pay := Tuning.VIGILANTE_REWARD * level
		reward += pay
		Game.add_money(pay)
		Game.bump("criminals")
		Game.deed("criminal")
		Sfx.play("cash")
		Game.notice.emit(I18n.fmt("NOTICE_CROOK_DOWN", {"money": I18n.money(pay)}))
		_next())
