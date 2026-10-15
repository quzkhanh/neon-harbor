class_name TrailerPilot
extends RefCounted
## Lái xe của Jay khi quay trailer: chỉ đặt ga/lái/phanh tay/nitro rồi để `Vehicle._drive` chạy vật lý thật,
## nên vẫn có drift, vệt lốp, lửa nitro và va chạm như người chơi lái. Chạy vòng qua `points` theo đường A*.

const REACH := 90.0  # tới gần điểm A* chừng này thì nhắm điểm kế
const LOOKAHEAD := 2
const STEER_GAIN := 2.6
const SHARP := 0.7  # rad: cua gắt thì nhả ga
const DRIFT_ANGLE := 0.9  # rad: cua rất gắt ở tốc độ cao thì kéo phanh tay cho xe trượt
const DRIFT_SPEED := 300.0
const NITRO_ANGLE := 0.15  # chỉ đốt nitro trên đoạn thẳng
const STUCK_SPEED := 30.0
const STUCK_TIME := 1.0
const REVERSE_TIME := 0.8

var city: City
var points: Array[Vector2] = []
var _next := 0
var _path := PackedVector2Array()
var _stuck := 0.0
var _reverse := 0.0


func _init(c: City, route: Array[Vector2]) -> void:
	city = c
	points = route


## Gọi từ `Vehicle._physics_process`; trả về false để xe tự chạy vật lý theo điều khiển vừa đặt.
func update(v: Vehicle, delta: float) -> bool:
	if _path.size() <= 1:
		_next = (_next + 1) % points.size() if v.global_position.distance_to(points[_next]) < REACH * 2.0 else _next
		_path = city.path(v.global_position, points[_next], true)
	while _path.size() > 1 and v.global_position.distance_to(_path[0]) < REACH:
		_path.remove_at(0)
	var target := _path[mini(LOOKAHEAD - 1, _path.size() - 1)] if _path.size() > 0 else points[_next]
	var diff := angle_difference(v.rotation, (target - v.global_position).angle())
	var speed := v.forward_speed()
	v.assist = false
	v.steer = clampf(diff * STEER_GAIN, -1.0, 1.0)
	v.handbrake = absf(diff) > DRIFT_ANGLE and speed > DRIFT_SPEED
	v.boost = absf(diff) < NITRO_ANGLE
	v.throttle = 0.4 if absf(diff) > SHARP else 1.0
	_stuck = _stuck + delta if absf(speed) < STUCK_SPEED else 0.0
	if _stuck > STUCK_TIME:
		_stuck = 0.0
		_reverse = REVERSE_TIME
		_path = PackedVector2Array()
	if _reverse > 0.0:
		_reverse -= delta
		v.throttle = -1.0
		v.steer = -v.steer
		v.boost = false
		v.handbrake = false
	return false
