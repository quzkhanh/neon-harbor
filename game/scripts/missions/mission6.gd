extends MissionBase
## NV6 Hot Wheels: xe gài bom. Đã chạy nhanh thì phải giữ trên tốc độ tối thiểu, chậm quá lâu là nổ.
## Lao tới gần kho xăng Red Fangs (F) rồi nhảy ra: xe tự lao vào kho và nổ tung.

const BOMB_RADIUS := 240.0
const BOMB_DAMAGE := 200.0
const HIT_DEPOT := 120.0

var car: Vehicle
var _armed := false
var _slow := 0.0
var _bailed := false


func _ready() -> void:
	car = car_near(city.player.global_position, "pickup", "car_red_4")
	car.set_meta("mission", true)
	car.hp = Tuning.M6_CAR_HP  # xe gia cố: phải giữ tốc độ qua dòng xe và lãnh địa Red Fangs
	Game.set_objective("M6_OBJ_CAR")
	mark(car.global_position)


func _process(delta: float) -> void:
	if _bailed:
		return
	if not is_instance_valid(car) or car.wrecked or car.burning:
		failed.emit("M6_FAIL_BOOM")
		return
	var depot := cell_pos("F")
	var driving := city.player.vehicle == car
	var speed := car.velocity.length()
	if not _armed:
		if driving and speed > Tuning.M6_MIN_SPEED:
			_armed = true
			mark(depot)
			Game.notice.emit(tr("NOTICE_BOMB_ARMED"))
		elif not driving:
			Game.set_objective("M6_OBJ_CAR")
		else:
			Game.set_objective("M6_OBJ_ARM")
		return
	if not driving and car.global_position.distance_to(depot) < Tuning.M6_BAIL_RADIUS:
		_bail(depot)
		return
	_slow = _slow + delta if speed < Tuning.M6_MIN_SPEED else 0.0
	if _slow > Tuning.M6_GRACE:
		_detonate(car.global_position)
		failed.emit("M6_FAIL_BOOM")
		return
	var close := car.global_position.distance_to(depot) < Tuning.M6_BAIL_RADIUS
	Game.set_objective("M6_OBJ_BAIL" if close else ("M6_OBJ_SLOW" if _slow > 0.0 else "M6_OBJ_DRIVE"), {"time": ceili(Tuning.M6_GRACE - _slow)})


## Nhảy ra gần kho: xe tự lao vào kho rồi nổ (chậm nhất sau Tuning.M6_FUSE giây).
func _bail(depot: Vector2) -> void:
	_bailed = true
	unmark()
	city.player.shield(Tuning.M6_FUSE + Tuning.VEHICLE_BURN_TIME + 1.0)  # bom nổ rồi xe cháy nổ thêm lần nữa
	var driver := GotoDriver.new(city)
	driver.target = depot
	driver.ratio = 0.8
	driver.speed = car.velocity.length()
	car.autopilot = driver
	var left := Tuning.M6_FUSE
	while left > 0.0 and is_instance_valid(car) and car.global_position.distance_to(depot) > HIT_DEPOT:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
	if not is_inside_tree():
		return
	_detonate(car.global_position if is_instance_valid(car) else depot)
	completed.emit()


func _detonate(pos: Vector2) -> void:
	if is_instance_valid(car) and not car.wrecked:
		car.take_hit(99999.0, Vector2.ZERO, null)
	Combat.explode(self, pos, BOMB_DAMAGE, BOMB_RADIUS, city.player)  # bom của Jay: Jay chỉ chịu nửa sát thương
	Fx.shake(14.0)
