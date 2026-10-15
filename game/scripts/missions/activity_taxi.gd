extends MissionBase
## Việc phụ: chạy taxi. Đang lái xe taxi thì có khách vẫy gần đó; dừng cạnh khách để đón, chở tới nơi trước khi hết
## giờ để nhận tiền (tới sớm có thêm tiền boa). Trễ thì khách bỏ đi, có khách khác. Xuống xe là nghỉ.

const SKINS := ["manBrown", "womanGreen", "survivor1", "manOld"]
const BOARD_RADIUS := 110.0
const STOP_SPEED := 70.0

var reward := 0
var _taxi: Vehicle
var _rider: Sprite2D
var _target := Vector2.ZERO
var _riding := false
var _time := 0.0
var _limit := 0.0
var _dist := 0.0


func _ready() -> void:
	_taxi = city.player.vehicle
	_new_fare()


func _new_fare() -> void:
	_riding = false
	_target = _sidewalk_near(Tuning.TAXI_PICKUP_RANGE)
	_rider = track(Sprite2D.new())
	_rider.texture = load(Human.CHAR_DIR % [SKINS[randi() % SKINS.size()], "hold"])
	_rider.global_position = _target
	_rider.rotation = (_taxi.global_position - _target).angle()
	city.effects.add_child(_rider)
	mark(_target)


func _sidewalk_near(range_px: Vector2) -> Vector2:
	var from := _taxi.global_position
	var best := from
	for i in 80:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(range_px.x, range_px.y)
		var cell := MapData.world_to_cell(from + off)
		if city.data.at(cell) == "," and MapData.DIRS.any(func(d: Vector2i) -> bool: return city.data.is_road(cell + d)):
			return MapData.cell_center(cell)
	return best


func _process(delta: float) -> void:
	if city.player.vehicle != _taxi or not is_instance_valid(_taxi) or _taxi.wrecked:
		Game.notice.emit(tr("NOTICE_TAXI_OFF"))
		completed.emit()
		return
	var stopped := _taxi.velocity.length() < STOP_SPEED
	if not _riding:
		Game.set_objective("TAXI_OBJ_PICKUP")
		if stopped and _taxi.global_position.distance_to(_target) < BOARD_RADIUS:
			_board()
		return
	_time -= delta
	Game.set_objective("TAXI_OBJ_DROP", {"time": ceili(maxf(_time, 0.0))})
	if _time <= 0.0:
		Game.notice.emit(tr("NOTICE_TAXI_LATE"))
		_new_fare()
	elif stopped and _taxi.global_position.distance_to(_target) < BOARD_RADIUS:
		var tip := Tuning.TAXI_TIP if _time > _limit * 0.5 else 0
		var pay := int(Tuning.TAXI_PAY_BASE + _dist * Tuning.TAXI_PAY_PER_PX) + tip
		reward += pay
		Game.add_money(pay)
		Game.bump("fares")
		Sfx.play("cash")
		Game.notice.emit(I18n.fmt("NOTICE_FARE", {"money": I18n.money(pay)}))
		_new_fare()


func _board() -> void:
	_rider.queue_free()
	_riding = true
	Sfx.play_at("door", _taxi.global_position)
	_target = _sidewalk_near(Tuning.TAXI_DROP_RANGE)
	_dist = _target.distance_to(_taxi.global_position)
	_limit = Tuning.TAXI_TIME_BASE + _dist / Tuning.TAXI_TIME_SPEED
	_time = _limit
	mark(_target)
