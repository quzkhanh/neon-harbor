extends MissionBase
## Việc phụ: giao hàng từ trạm J. Chuỗi Tuning.DELIVERY_DROPS đơn tới vỉa hè trước cửa các toà nhà; mỗi đơn cộng
## thêm thời gian theo quãng đường và trả tiền ngay; giao đủ chuỗi được thưởng thêm. Hết giờ là thất bại.

const ARRIVE := 70.0

var reward := 0
var _doors: Array[Vector2i] = []
var _target := Vector2.ZERO
var _done := 0
var _time := 0.0
var _pay := 0


func _ready() -> void:
	for cell in city.data.find_all(","):
		if MapData.DIRS.any(func(d: Vector2i) -> bool: return city.data.at(cell + d) == "#"):
			_doors.append(cell)
	_next_drop()


func _next_drop() -> void:
	var from := _player_pos()
	var best := Vector2.INF
	for i in 80:
		var pos := MapData.cell_center(_doors[randi() % _doors.size()])
		var d := pos.distance_to(from)
		if d > Tuning.DELIVERY_RANGE.x and d < Tuning.DELIVERY_RANGE.y:
			best = pos
			break
		if best == Vector2.INF or absf(d - Tuning.DELIVERY_RANGE.x) < absf(best.distance_to(from) - Tuning.DELIVERY_RANGE.x):
			best = pos
	_target = best
	var dist := _target.distance_to(from)
	_time += Tuning.DELIVERY_TIME_BASE + dist / Tuning.DELIVERY_TIME_SPEED
	_pay = int(Tuning.DELIVERY_PAY_BASE + dist * Tuning.DELIVERY_PAY_PER_PX)
	mark(_target)


func _player_pos() -> Vector2:
	return city.player.vehicle.global_position if city.player.vehicle else city.player.global_position


func _process(delta: float) -> void:
	_time -= delta
	Game.set_objective("JOB_DELIVER", {"i": _done + 1, "total": Tuning.DELIVERY_DROPS, "time": ceili(maxf(_time, 0.0))})
	if _time <= 0.0:
		failed.emit("FAIL_TIME")
	elif near(_target, ARRIVE):
		_done += 1
		reward += _pay
		Game.add_money(_pay)
		Game.bump("deliveries")
		Game.deed("delivery")
		Sfx.play("cash")
		if _done >= Tuning.DELIVERY_DROPS:
			reward += Tuning.DELIVERY_BONUS
			Game.add_money(Tuning.DELIVERY_BONUS)
			Game.bump("delivery_chains")
			Sfx.play("mission_complete")
			Game.notice.emit(I18n.fmt("NOTICE_JOB_DONE", {"money": I18n.money(reward)}))
			completed.emit()
		else:
			Game.notice.emit(I18n.fmt("NOTICE_DELIVERED", {"money": I18n.money(_pay)}))
			_next_drop()
