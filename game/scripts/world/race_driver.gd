class_name RaceDriver
extends PathDriver
## Đối thủ đua: chạy lần lượt qua các checkpoint; đi trước người chơi thì nhả ga một chút, tụt lại thì dốc hết sức.

const CHECK_RADIUS := 150.0
const AHEAD_EASE := 0.82

var points: Array[Vector2] = []
var skill := 0.9
var next := 0
var started := false
var player_progress := 0.0  # Race cập nhật để bám đuổi


func update(v: Vehicle, delta: float) -> bool:
	if not started or next >= points.size():
		return hold(v, delta)
	if v.global_position.distance_to(points[next]) < CHECK_RADIUS:
		next += 1
		if next >= points.size():
			return hold(v, delta)
	var pace := AHEAD_EASE if progress(v) > player_progress else 1.0
	return steer_to(v, points[next], float(v.spec.max_speed) * skill * pace, delta)


## Tiến độ để xếp hạng: số checkpoint đã qua, trừ phần quãng đường còn lại tới checkpoint kế (theo nghìn px).
func progress(v: Vehicle) -> float:
	if next >= points.size():
		return float(points.size())
	return next - v.global_position.distance_to(points[next]) / 100000.0
