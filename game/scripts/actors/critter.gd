class_name Critter
extends Node2D
## Thú vật trong phố: bồ câu, mèo, chó (đi trên vỉa hè và cỏ), hải âu (bay lượn), cua (bò ven nước).
## Không bao giờ bị thương: không có va chạm, không thuộc nhóm "damageable", đạn và xe đều đi xuyên qua; thú chỉ
## chạy hoặc bay tránh người và xe tới gần. Thỉnh thoảng kêu một tiếng khi Jay lại gần.

const SPECS := {
	"pigeon": {"speed": 26.0, "flee": 230.0, "scare": 130.0, "bark": ""},
	"cat": {"speed": 40.0, "flee": 175.0, "scare": 150.0, "bark": "CRITTER_CAT"},
	"dog": {"speed": 60.0, "flee": 160.0, "scare": 90.0, "bark": "CRITTER_DOG"},
	"crab": {"speed": 30.0, "flee": 120.0, "scare": 100.0, "bark": "CRITTER_CRAB"},
	"gull": {"speed": 95.0, "flee": 95.0, "scare": 0.0, "bark": "CRITTER_GULL"},
}
const GRASS := "\""
const ART_SCALE := 2.0  # thú nhỏ hơn người nhưng vẫn phải nhìn rõ ở độ zoom của game
const SCAN_EVERY := 0.2
const FLY_TIME := 1.7
const LIFT_RATE := 4.0
const PACK_RADIUS := 150.0  # một con bồ câu bay thì cả bầy quanh nó bay theo
const VEHICLE_MIN_SPEED := 80.0
const WANDER_CELLS := Vector2i(2, 5)
const IDLE_TIME := Vector2(1.0, 4.0)
const FEED_RANGE := 320.0  # có ông lão cho ăn trong tầm này thì bồ câu tụ về
const FEED_SPREAD := 46.0
const BARK_RANGE := 110.0
const BARK_COOLDOWN := 9.0
const BARK_CHANCE := 0.35
const ORBIT_RADIUS := Vector2(70.0, 170.0)
const ORBIT_SPEED := 0.55

var kind := "pigeon"
var city: City
var coat := Color.WHITE
var _art := Node2D.new()  # chỉ phần hình xoay theo hướng đi, để bong bóng thoại luôn thẳng
var _t := randf() * 10.0
var _lift := 0.0
var _flee_dir := Vector2.ZERO
var _flee_time := 0.0
var _goal := Vector2.ZERO
var _idle := 0.0
var _scan := randf() * SCAN_EVERY
var _bark_cd := randf_range(2.0, BARK_COOLDOWN)
var _orbit_center := Vector2.ZERO
var _orbit_angle := randf() * TAU
var _orbit_radius := 100.0


func _ready() -> void:
	add_to_group("critters")
	z_index = 12 if kind == "gull" else 0
	coat = Palette.CAT_COATS.pick_random() if kind == "cat" else Palette.DOG_COATS.pick_random() if kind == "dog" else Color.WHITE
	_goal = global_position
	_orbit_center = global_position
	_orbit_radius = randf_range(ORBIT_RADIUS.x, ORBIT_RADIUS.y)
	_art.rotation = randf() * TAU
	_art.draw.connect(func() -> void: CritterArt.draw(_art, kind, coat, _t, 1.0 if kind == "gull" else _lift))
	_art.scale = Vector2.ONE * ART_SCALE
	add_child(_art)


func _process(delta: float) -> void:
	if not city.view_rect().grow(Tuning.TILE * 2.0).has_point(global_position):
		return
	_t += delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_EVERY
		_look_around()
	if kind == "gull":
		_soar(delta)
	elif _flee_time > 0.0:
		_run_away(delta)
	else:
		_lift = maxf(_lift - LIFT_RATE * delta, 0.0)
		_wander(delta)
	_art.queue_redraw()


func startle(from: Vector2) -> void:
	if kind == "gull" or _flee_time > 0.0:
		return
	_flee_dir = (global_position - from).normalized()
	if _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.from_angle(randf() * TAU)
	_flee_dir = _flee_dir.rotated(randf_range(-0.5, 0.5))
	_flee_time = FLY_TIME if kind == "pigeon" else FLY_TIME * 0.6
	if kind == "pigeon":
		for other in get_tree().get_nodes_in_group("critters"):
			if other != self and other.kind == "pigeon" and other.global_position.distance_to(global_position) < PACK_RADIUS:
				other.startle(from)


func _look_around() -> void:
	var threat := _nearest_threat()
	if global_position.distance_to(threat) < float(SPECS[kind].scare):
		startle(threat)
	_bark_cd -= SCAN_EVERY
	var bark: String = SPECS[kind].bark
	if bark != "" and _bark_cd <= 0.0 and global_position.distance_to(city.player.global_position) < BARK_RANGE and randf() < BARK_CHANCE:
		_bark_cd = BARK_COOLDOWN
		Speech.say(self, Speech.pick(bark))


## Vị trí của mối đe doạ gần nhất: Jay, hoặc một chiếc xe đang chạy.
func _nearest_threat() -> Vector2:
	var best: Vector2 = city.player.global_position
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v.velocity.length() > VEHICLE_MIN_SPEED and v.global_position.distance_to(global_position) < best.distance_to(global_position):
			best = v.global_position
	return best


func _nearest_feeder() -> Vector2:
	if kind != "pigeon":
		return Vector2.INF
	var best := Vector2.INF
	for f in get_tree().get_nodes_in_group("feeders"):
		if f.alive and f.global_position.distance_to(global_position) < minf(FEED_RANGE, best.distance_to(global_position)):
			best = f.global_position
	return best


func _walkable(pos: Vector2) -> bool:
	var cell := MapData.world_to_cell(pos)
	return city.data.is_ped_walkable(cell) or city.data.at(cell) == GRASS


func _wander(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
		return
	var to := _goal - global_position
	if to.length() < 4.0:
		_idle = randf_range(IDLE_TIME.x, IDLE_TIME.y)
		_goal = _pick_goal()
		return
	var step: Vector2 = to.normalized() * float(SPECS[kind].speed) * delta
	if not _walkable(global_position + step * 4.0):
		_goal = global_position
		return
	global_position += step
	_art.rotation = lerp_angle(_art.rotation, to.angle() + (PI * 0.5 if kind == "crab" else 0.0), minf(8.0 * delta, 1.0))


func _pick_goal() -> Vector2:
	var feeder := _nearest_feeder()
	if feeder != Vector2.INF:
		var crumb := feeder + Vector2.from_angle(randf() * TAU) * randf_range(10.0, FEED_SPREAD)
		return crumb if _walkable(crumb) else global_position
	var cells := randi_range(WANDER_CELLS.x, WANDER_CELLS.y)
	var goal := global_position + Vector2.from_angle(randf() * TAU) * Tuning.TILE * cells
	return goal if _walkable(goal) else global_position


## Chạy (hoặc bay, với bồ câu) khỏi mối đe doạ; bồ câu bay qua được mọi thứ, thú chạy chỉ đi trên ô đi được.
func _run_away(delta: float) -> void:
	_flee_time -= delta
	var flying := kind == "pigeon"
	if flying:
		_lift = minf(_lift + LIFT_RATE * delta, 1.0)
	var step := _flee_dir * float(SPECS[kind].flee) * delta
	if flying or _walkable(global_position + step * 3.0):
		global_position += step
	else:
		_flee_dir = _flee_dir.rotated(PI * 0.5 * signf(randf() - 0.5))
	_art.rotation = lerp_angle(_art.rotation, _flee_dir.angle(), minf(10.0 * delta, 1.0))
	if flying and _flee_time <= 0.0 and not _walkable(global_position):
		_flee_time = 0.25  # chưa có chỗ đáp: bay thêm chút nữa
	_goal = global_position


## Hải âu lượn vòng quanh một điểm, tâm trôi chậm.
func _soar(delta: float) -> void:
	_orbit_angle += ORBIT_SPEED * delta
	_orbit_center += Vector2.from_angle(_orbit_angle * 0.37) * 8.0 * delta
	var target := _orbit_center + Vector2.from_angle(_orbit_angle) * _orbit_radius
	_art.rotation = (target - global_position).angle()
	global_position = target
