extends MissionBase
## Việc phụ: đua đường phố từ điểm Q (phải đang lái xe). 3 đối thủ, đếm ngược, qua lần lượt các checkpoint;
## về đích nhận thưởng theo hạng, lưu thời gian tốt nhất.

const RIVALS := [["sports", 0.93], ["car", 0.97], ["compact", 0.95]]
const COUNTDOWN := 3

var index := 0  # tuyến đua trong DataDB.extras().races
var reward := 0
var _race: Dictionary
var _points: Array[Vector2] = []
var _rivals: Array[Vehicle] = []
var _car: Vehicle
var _next := 0
var _time := 0.0
var _running := false


func _ready() -> void:
	_race = DataDB.extras().races[index]
	for p in _race.points:
		_points.append(Vector2(float(p[0]), float(p[1])) * Tuning.TILE)
	_car = city.player.vehicle
	var heading := Vector2(float(_race.heading[0]), float(_race.heading[1]))
	var across := Vector2(heading.y, -heading.x)  # làn bên cạnh (ngược chiều, chỉ dùng làm chỗ xếp hàng)
	var start := MapData.cell_center(Vector2i(int(_race.start[0]), int(_race.start[1])))
	_place(_car, start, heading)
	var slots := [start + across * Tuning.TILE, start - heading * Tuning.TILE * 2.2, start - heading * Tuning.TILE * 2.2 + across * Tuning.TILE]
	for i in RIVALS.size():
		var v: Vehicle = track(city.spawn_vehicle(RIVALS[i][0], MapData.world_to_cell(slots[i]), heading.angle()))
		_place(v, slots[i], heading)
		var driver := RaceDriver.new(city)
		driver.points = _points
		driver.skill = RIVALS[i][1]
		v.autopilot = driver
		v.has_npc_driver = true
		v.set_meta("mission", true)
		_rivals.append(v)
	_countdown()


func _place(v: Vehicle, pos: Vector2, heading: Vector2) -> void:
	v.global_position = pos
	v.rotation = heading.angle()
	v.velocity = Vector2.ZERO


func _countdown() -> void:
	city.player.controls_enabled = false
	for n in range(COUNTDOWN, 0, -1):
		Game.set_objective("RACE_COUNTDOWN", {"sec": n})
		Sfx.play("beep")
		await get_tree().create_timer(1.0, false).timeout
		if not is_inside_tree():
			return
	city.player.controls_enabled = true
	Sfx.play("beep_go")
	for v in _rivals:
		v.autopilot.started = true
	_running = true
	mark(_points[0])


func _process(delta: float) -> void:
	if not _running:
		return
	if not is_instance_valid(_car) or _car.wrecked or _car.burning:
		failed.emit("FAIL_RACE_CAR")
		return
	if city.player.vehicle != _car:
		failed.emit("FAIL_RACE_LEFT")
		return
	_time += delta
	if _time > Tuning.RACE_TIME_LIMIT:
		failed.emit("FAIL_TIME")
		return
	if _car.global_position.distance_to(_points[_next]) < RaceDriver.CHECK_RADIUS:
		_next += 1
		Sfx.play("checkpoint")
		if _next >= _points.size():
			_finish()
			return
		mark(_points[_next])
	var mine := player_progress()
	for v in _rivals:
		if is_instance_valid(v):
			v.autopilot.player_progress = mine
	Game.set_objective("RACE_OBJ", {"cp": _next + 1, "total": _points.size(), "place": place(), "count": _rivals.size() + 1})


func player_progress() -> float:
	return _next - _car.global_position.distance_to(_points[_next]) / 100000.0 if _next < _points.size() else float(_points.size())


## Hạng hiện tại của người chơi (1 = dẫn đầu).
func place() -> int:
	var mine := player_progress()
	var ahead := _rivals.filter(func(v: Vehicle) -> bool: return is_instance_valid(v) and v.autopilot.progress(v) > mine).size()
	return ahead + 1


func _finish() -> void:
	_running = false
	var p := place()
	reward = int(Tuning.RACE_PRIZES[p - 1])
	Game.add_money(reward)
	if p == 1:
		Game.bump("races_won")
		Game.mark("races_won_ids", str(index))
	var key := "race_best_%d" % index
	var best := float(Game.stats.get(key, 0.0))
	if best <= 0.0 or _time < best:
		Game.stats[key] = snappedf(_time, 0.01)
	Sfx.play("mission_complete")
	Game.notice.emit(I18n.fmt("NOTICE_RACE_DONE", {"place": p, "time": "%.1f" % _time, "money": I18n.money(reward)}))
	completed.emit()


func cleanup() -> void:
	city.player.controls_enabled = true
	super()
