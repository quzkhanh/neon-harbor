class_name ChaseDriver
extends RefCounted
## Xe cảnh sát: lái theo đường A* tới người chơi; tới gần thì dừng và thả cảnh sát xuống.

signal arrived(vehicle: Vehicle)

const REACH := 40.0
const TURN_RATE := 5.0
const SPEED_RATIO := 0.85

var city: City
var speed := 0.0
var _path := PackedVector2Array()
var _timer := 0.0
var _stuck := 0.0
var _reverse := 0.0
var _arrived := false


func _init(c: City) -> void:
	city = c


func update(v: Vehicle, delta: float) -> bool:
	var target := city.player.vehicle.global_position if city.player.vehicle else city.player.global_position
	var dist := v.global_position.distance_to(target)
	if dist < Tuning.COP_CAR_STOP_DIST and not _arrived:
		_arrived = true
		arrived.emit(v)
	if _arrived:
		speed = move_toward(speed, 0.0, 900.0 * delta)
		v.velocity = v.forward() * speed
		if dist > Tuning.COP_CAR_STOP_DIST * 3.0:
			_arrived = false
		return true
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
	var max_speed := float(v.spec.max_speed) * SPEED_RATIO
	var sharp := absf(angle_difference(v.rotation, to.angle())) > 0.6
	speed = move_toward(speed, max_speed * (0.45 if sharp else 1.0), float(v.spec.accel) * delta)
	v.rotation = lerp_angle(v.rotation, to.angle(), minf(TURN_RATE * delta, 1.0))
	v.velocity = v.forward() * speed
	_stuck = _stuck + delta if v.get_real_velocity().length() < 30.0 else 0.0
	if _stuck > Tuning.STUCK_TIME:
		_stuck = 0.0
		_reverse = 0.8
		speed = 0.0
	return true
