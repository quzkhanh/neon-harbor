class_name TrafficDriver
extends RefCounted
## Xe tự lái chạy theo làn: nối từng ô, lên lộ trình khi vào giao lộ, dừng/bấm còi khi có vật cản.

const LOOKAHEAD := 3
const REACH := 26.0
const TURN_RATE := 6.0
const TURN_SLOWDOWN := 0.55
const SHOVE_DECAY := 520.0  # px/s^2: vận tốc bị đẩy tắt dần
const SHOVE_MAX := 420.0
const STOP_DIST := 80.0  # cách giao lộ chừng này mà chưa được vào thì dừng chờ
const CLAIM_TIMEOUT_MS := 8000  # xe giữ giao lộ quá lâu (bị chặn, bị tông) thì xe khác được vào

var map: MapData
var cell: Vector2i
var heading: Vector2i
var points: Array[Vector2] = []
var speed := 0.0
var _plan: Array[Vector2i] = []
var _blocked := 0.0
var _inside := false
var _shove := Vector2.ZERO  # vận tốc bị xe khác đâm/đẩy, cộng thêm vào vận tốc tự lái
var _held := Vector2i(-1, -1)

## Giao lộ -> [mã xe đang giữ, thời điểm giữ]: mỗi giao lộ chỉ một xe tự lái vào một lúc, tránh hai xe cắt mặt nhau rồi kẹt.
static var _claims := {}
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
	if _obstacle_ahead(v) or not _right_of_way(v):
		target = 0.0
		_blocked += delta
		if _blocked > Tuning.HONK_AFTER and _honk_cd <= 0.0:
			_honk_cd = Tuning.HONK_COOLDOWN
			Sfx.play_at("horn", v.global_position, -6.0)
	else:
		_blocked = 0.0
	speed = move_toward(speed, target, Tuning.TRAFFIC_ACCEL * (3.0 if target < speed else 1.0) * delta)
	v.rotation = lerp_angle(v.rotation, to.angle(), minf(TURN_RATE * delta, 1.0))
	v.velocity = v.forward() * speed + _shove
	_shove = _shove.move_toward(Vector2.ZERO, SHOVE_DECAY * delta)
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


## Số giây xe bị chặn liên tục (để xoá xe kẹt khi ở ngoài màn hình).
func stuck_time() -> float:
	return _blocked


## Có được tiến vào giao lộ phía trước không: giữ "thẻ" của giao lộ trong lúc đi qua, trả lại khi ra khỏi.
func _right_of_way(v: Vehicle) -> bool:
	var here := MapData.world_to_cell(v.global_position)
	if map.at(here) == "+":
		_inside = true
		return _claim(Lanes.block_id(map, here), v)
	if _inside:
		_inside = false
		_release(v)
	for p in points:
		var c := MapData.world_to_cell(p)
		if map.at(c) == "+":
			return v.global_position.distance_to(p) > STOP_DIST or _claim(Lanes.block_id(map, c), v)
	return true


func _claim(block: Vector2i, v: Vehicle) -> bool:
	var now := Time.get_ticks_msec()
	var held: Array = _claims.get(block, [])
	if held.is_empty() or held[0] == v.get_instance_id() or now - held[1] > CLAIM_TIMEOUT_MS or not is_instance_id_valid(held[0]):
		_claims[block] = [v.get_instance_id(), held[1] if not held.is_empty() and held[0] == v.get_instance_id() else now]
		_held = block
		return true
	return false


func _release(v: Vehicle) -> void:
	var held: Array = _claims.get(_held, [])
	if not held.is_empty() and held[0] == v.get_instance_id():
		_claims.erase(_held)


## Bị xe khác đâm hoặc đẩy: xe tự lái điều khiển vận tốc từng khung nên phải cộng cú đẩy riêng, nếu không bị ghi đè ngay.
func shove(impulse: Vector2) -> void:
	_shove = (_shove + impulse).limit_length(SHOVE_MAX)
