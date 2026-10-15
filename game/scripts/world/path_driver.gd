class_name PathDriver
extends RefCounted
## Lái tự động (động học) theo đường A* ưu tiên lòng đường tới một điểm: chậm lại khi cua gắt, kẹt thì lùi ra.
## Lớp con chọn điểm đến và tốc độ (ChaseDriver đuổi người chơi, RaceDriver chạy qua checkpoint).

const REACH := 40.0
const TURN_RATE := 5.0
const SHARP_TURN := 0.6
const SHARP_SLOW := 0.45
const REVERSE_TIME := 0.8

var city: City
var speed := 0.0
var _path := PackedVector2Array()
var _timer := 0.0
var _stuck := 0.0
var _reverse := 0.0


func _init(c: City) -> void:
	city = c


## Lái `v` về phía `target` với tốc tối đa `max_speed`. Luôn trả về true (điều khiển động học).
func steer_to(v: Vehicle, target: Vector2, max_speed: float, delta: float) -> bool:
	_timer -= delta
	if _timer <= 0.0:
		_timer = Tuning.PATH_REFRESH
		_path = city.path(v.global_position, target, true)
	while _path.size() > 1 and v.global_position.distance_to(_path[0]) < REACH:
		_path.remove_at(0)
	var goal := target if _path.size() <= 1 else _path[0]
	var to := goal - v.global_position
	if _reverse > 0.0:
		_reverse -= delta
		v.velocity = -v.forward() * float(v.spec.reverse)
		return true
	var sharp := absf(angle_difference(v.rotation, to.angle())) > SHARP_TURN
	speed = move_toward(speed, max_speed * (SHARP_SLOW if sharp else 1.0), float(v.spec.accel) * delta)
	v.rotation = lerp_angle(v.rotation, to.angle(), minf(TURN_RATE * delta, 1.0))
	v.velocity = v.forward() * speed
	_stuck = _stuck + delta if v.get_real_velocity().length() < 30.0 else 0.0
	if _stuck > Tuning.STUCK_TIME:
		_stuck = 0.0
		_reverse = REVERSE_TIME
		speed = 0.0
	return true


## Đứng yên (phanh gấp) tại chỗ.
func hold(v: Vehicle, delta: float) -> bool:
	speed = move_toward(speed, 0.0, 900.0 * delta)
	v.velocity = v.forward() * speed
	return true
