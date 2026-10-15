class_name RoadIncident
extends Node
## Một vụ va chạm giữa hai xe trên đường, diễn ra như ngoài đời: hai xe đâm nhau và chặn làn (xe phía sau dồn lại thành
## hàng, bấm còi), hai tài xế xuống xe, cãi nhau, có khi ẩu đả, rồi làm lành, lên xe đi tiếp.
## Bị người chơi can thiệp (đánh, bắn) thì thôi kịch bản: hai người phản ứng như người đi đường thường.

enum Phase { EXIT, ARGUE, FIGHT, SETTLE, LEAVE, DONE }

const EXIT_TIME := 1.8
const ARGUE_TIME := Vector2(7.0, 10.0)
const FIGHT_TIME := Vector2(4.0, 6.0)
const SETTLE_TIME := 3.5
const FIGHT_CHANCE := 0.4
const LINE_GAP := 2.3
const PUNCH_EVERY := 0.55
const PUNCH_PUSH := 140.0
const MEET_GAP := 34.0  # khoảng cách hai người đứng đối mặt
const WALK_SPEED := 1.3  # nhân với tốc độ đi bộ thường
const ARRIVE := 8.0
const BOARD_DIST := 16.0
const BOARD_PATIENCE := 12.0  # đi mãi chưa tới cửa xe thì lên xe luôn
const TIMEOUT := 70.0
const CRASH_DAMAGE := 0.12  # phần máu xe mất khi đâm nhau

var city: City
var cars: Array[Vehicle] = []
var _peds: Array[Pedestrian] = []
var _phase := Phase.EXIT
var _t := 0.0
var _phase_time := EXIT_TIME
var _line := 0
var _punch := 0.0
var _total := 0.0
var _meet: Array[Vector2] = []
var _doors: Array[Vector2] = []  # chỗ mỗi tài xế xuống xe, cũng là chỗ lên xe
var _loser := -1


## Dựng vụ va chạm: `rear` đâm vào đuôi `front` trên làn `dir`. Trả về false nếu không dựng được.
func start(front: Vehicle, rear: Vehicle, dir: Vector2) -> bool:
	cars = [front, rear]
	var overlap := front.size.x * 0.5 + rear.size.x * 0.5 - 6.0
	rear.global_position = front.global_position - dir * overlap
	rear.rotation = dir.angle() + randf_range(-0.1, 0.1)
	for v in cars:
		v.autopilot = null
		v.has_npc_driver = true
		v.hazard = true
		v.hp *= 1.0 - CRASH_DAMAGE
	Sfx.play_at("crash", front.global_position)
	Fx.burst(front.global_position - dir * front.size.x * 0.5, "spark", 12, 220.0, 0.35, Color(1, 0.85, 0.5))
	for i in 2:
		_doors.append(cars[i].exit_point())
	var mid := (_doors[0] + _doors[1]) * 0.5
	var near_side := 1.0 if (_doors[0] - mid).dot(dir) > 0.0 else -1.0  # mỗi người đứng về phía xe của mình
	_meet = [mid + dir * MEET_GAP * 0.5 * near_side, mid - dir * MEET_GAP * 0.5 * near_side]
	for i in 2:
		var ped := city.spawn_npc(Pedestrian, _doors[i])
		ped.add_to_group("peds")
		ped.scripted = true
		ped.armed = false
		ped.gun = null
		_peds.append(ped)
		Sfx.play_at("door", cars[i].global_position)
		Emote.show_on(ped, Emote.Kind.ANGRY)
	return true


func _process(delta: float) -> void:
	_total += delta
	_t += delta
	if _total > TIMEOUT or _aborted():
		_finish()
		return
	match _phase:
		Phase.EXIT:
			_gather(delta)
		Phase.ARGUE:
			_gather(delta)
			_talk("INCIDENT_BLAME", "INCIDENT_DENY")
		Phase.FIGHT:
			_gather(delta)
			_brawl(delta)
		Phase.SETTLE:
			_gather(delta)
			_talk("INCIDENT_SETTLE", "INCIDENT_SETTLE")
		Phase.LEAVE:
			_leave(delta)
	if _t >= _phase_time and _phase != Phase.LEAVE:
		_enter(_after())


func _after() -> Phase:
	match _phase:
		Phase.EXIT:
			return Phase.ARGUE
		Phase.ARGUE:
			return Phase.FIGHT if randf() < FIGHT_CHANCE else Phase.SETTLE
		Phase.FIGHT:
			return Phase.SETTLE
		_:
			return Phase.LEAVE


func _enter(next: Phase) -> void:
	_phase = next
	_t = 0.0
	_line = 0
	match next:
		Phase.ARGUE:
			_phase_time = randf_range(ARGUE_TIME.x, ARGUE_TIME.y)
		Phase.FIGHT:
			_phase_time = randf_range(FIGHT_TIME.x, FIGHT_TIME.y)
			_loser = randi() % 2
		Phase.SETTLE:
			_phase_time = SETTLE_TIME


func _aborted() -> bool:
	for p in _peds:
		if p != null and (not is_instance_valid(p) or not p.alive or not p.scripted):
			return true
	return false


## Hai người đứng đối mặt ở chỗ hẹn.
func _gather(delta: float) -> void:
	for i in 2:
		var p := _peds[i]
		if p.global_position.distance_to(_meet[i]) > ARRIVE:
			p.walk_to(_meet[i], Tuning.PED_SPEED * WALK_SPEED, delta)
		else:
			p.walk_dir(Vector2.ZERO, delta)
			p.face(lerp_angle(p.facing, (_peds[1 - i].global_position - p.global_position).angle(), minf(8.0 * delta, 1.0)))


func _talk(first_pool: String, second_pool: String) -> void:
	if _t < _line * LINE_GAP:
		return
	var who := _line % 2
	Speech.clear(_peds[1 - who])
	Speech.say(_peds[who], Speech.pick(first_pool if who == 0 else second_pool))
	_line += 1


## Ẩu đả: lần lượt đấm nhau (không gây thương tích); hết cuộc, một người ngã ra đường.
func _brawl(delta: float) -> void:
	_punch -= delta
	if _punch > 0.0:
		return
	_punch = PUNCH_EVERY
	var from := randi() % 2
	var hitter := _peds[from]
	var victim := _peds[1 - from]
	var to := victim.global_position - hitter.global_position
	hitter.lunge()
	victim.stagger()
	victim.knock_velocity += to.normalized() * PUNCH_PUSH
	Sfx.play_at("punch", victim.global_position)
	Melee.star(victim.global_position, false)
	if randf() < 0.3:
		Speech.say(hitter, Speech.pick("INCIDENT_FIGHT"))
	if _t + PUNCH_EVERY >= _phase_time:
		_peds[_loser].knocked = Tuning.KNOCKDOWN_TIME


## Về xe: ai lên xe xong thì xe đó chạy tiếp.
func _leave(delta: float) -> void:
	for i in 2:
		var p := _peds[i]
		if not is_instance_valid(p):
			continue
		if p.knocked > 0.0:
			continue
		if p.global_position.distance_to(_doors[i]) > BOARD_DIST and _t < BOARD_PATIENCE:
			p.walk_to(_doors[i], Tuning.PED_SPEED * WALK_SPEED, delta)
			continue
		_drive_off(cars[i])
		Sfx.play_at("door", cars[i].global_position)
		p.queue_free()
		_peds[i] = null
	if _peds.all(func(p: Variant) -> bool: return p == null):
		_finish()


func _drive_off(v: Vehicle) -> void:
	v.hazard = false
	v.autopilot = TrafficDriver.new(city.data, MapData.world_to_cell(v.global_position))


## Hết sự cố: người còn lại thành người đi đường thường, xe còn đó chạy tiếp (hoặc đỗ lại nếu người lái đã bị hạ).
func _finish() -> void:
	for p in _peds:
		if is_instance_valid(p):
			p.scripted = false
	for v in cars:
		if is_instance_valid(v):
			v.hazard = false
	queue_free()
