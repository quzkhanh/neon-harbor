class_name ChaseDriver
extends PathDriver
## Xe cảnh sát: lái theo đường A* tới người chơi; tới gần thì dừng và thả cảnh sát xuống.

signal arrived(vehicle: Vehicle)

const SPEED_RATIO := 0.85

var _arrived := false


func update(v: Vehicle, delta: float) -> bool:
	var target := city.player.vehicle.global_position if city.player.vehicle else city.player.global_position
	var dist := v.global_position.distance_to(target)
	if dist < Tuning.COP_CAR_STOP_DIST and not _arrived:
		_arrived = true
		arrived.emit(v)
	if _arrived:
		if dist > Tuning.COP_CAR_STOP_DIST * 3.0:
			_arrived = false
		return hold(v, delta)
	return steer_to(v, target, float(v.spec.max_speed) * SPEED_RATIO, delta)
