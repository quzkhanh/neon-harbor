class_name GotoDriver
extends PathDriver
## Lái tới một điểm cố định với tỉ lệ tốc độ cho trước; `waiting` thì đứng chờ; tới nơi thì dừng hẳn.

const ARRIVE := 160.0

var target := Vector2.ZERO
var ratio := 0.6
var waiting := false
var arrived := false


func update(v: Vehicle, delta: float) -> bool:
	if waiting or arrived:
		return hold(v, delta)
	if v.global_position.distance_to(target) < ARRIVE:
		arrived = true
	return steer_to(v, target, float(v.spec.max_speed) * ratio, delta)
