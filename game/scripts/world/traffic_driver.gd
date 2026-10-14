class_name TrafficDriver
extends RefCounted
## Xe tự lái chạy theo làn: nối từng ô, lên lộ trình khi vào giao lộ, dừng/bấm còi khi có vật cản.

const LOOKAHEAD := 3
const REACH := 26.0
const TURN_RATE := 6.0
const TURN_SLOWDOWN := 0.55

var map: MapData
var cell: Vector2i
var heading: Vector2i
var points: Array[Vector2] = []
var speed := 0.0
var _plan: Array[Vector2i] = []
var _blocked := 0.0
var _honk_cd := 0.0


func _init(map_data: MapData, start: Vector2i) -> void:
	map = map_data
	cell = start
	heading = map.lane_dir(start)
	points.append(MapData.cell_center(start))


## Trả về true: điều khiển động học (đặt thẳng velocity/rotation).
func update(v: Vehicle, delta: float) -> bool:
	while points.size() < LOOKAHEAD:
		_extend()
	if v.global_position.distance_to(points[0]) < REACH:
		points.pop_front()
		_extend()
	var to := points[0] - v.global_position
	var turn := absf(angle_difference(v.rotation, to.angle()))
	var target := Tuning.TRAFFIC_SPEED * (TURN_SLOWDOWN if turn > 0.4 else 1.0)
	_honk_cd -= delta
	if _obstacle_ahead(v):
		target = 0.0
		_blocked += delta
		if _blocked > Tuning.HONK_AFTER and _honk_cd <= 0.0:
			_honk_cd = Tuning.HONK_COOLDOWN
			Sfx.play_at("horn", v.global_position, -6.0)
	else:
		_blocked = 0.0
	speed = move_toward(speed, target, Tuning.TRAFFIC_ACCEL * (3.0 if target < speed else 1.0) * delta)
	v.rotation = lerp_angle(v.rotation, to.angle(), minf(TURN_RATE * delta, 1.0))
	v.velocity = v.forward() * speed
	return true


func _extend() -> void:
	var next: Vector2i
	if _plan.size() > 0:
		next = _plan.pop_front()
	else:
		next = Lanes.step(map, cell, heading)
		if map.at(next) == "+":
			_plan = Lanes.plan_intersection(map, next, heading)
			next = _plan.pop_front()
	if not map.is_road(next):
		next = cell - heading
	heading = next - cell
	cell = next
	points.append(MapData.cell_center(cell))


func _obstacle_ahead(v: Vehicle) -> bool:
	var space := v.get_world_2d().direct_space_state
	var front := v.global_position + v.forward() * v.size.x * 0.5
	for offset in [0.0, -0.3, 0.3]:
		var dir := v.forward().rotated(offset)
		var q := PhysicsRayQueryParameters2D.create(front, front + dir * Tuning.TRAFFIC_LOOK, Tuning.LAYER_ACTORS | Tuning.LAYER_VEHICLES, [v.get_rid()])
		if not space.intersect_ray(q).is_empty():
			return true
	return false
