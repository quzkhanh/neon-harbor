class_name FleeDriver
extends PathDriver
## Xe tội phạm: chạy tới một ô đường xa phía bên kia so với người chơi, tới nơi thì chọn ô khác.

const REPICK := 300.0
const FLEE_DIST := 2200.0

var _goal := Vector2.INF


func update(v: Vehicle, delta: float) -> bool:
	if _goal == Vector2.INF or v.global_position.distance_to(_goal) < REPICK:
		_goal = _pick(v)
	return steer_to(v, _goal, float(v.spec.max_speed) * Tuning.FLEE_SPEED_RATIO, delta)


func _pick(v: Vehicle) -> Vector2:
	var away := (v.global_position - city.player.global_position).normalized()
	for i in 40:
		var dir := away.rotated(randf_range(-1.2, 1.2))
		var cell := MapData.world_to_cell(v.global_position + dir * FLEE_DIST)
		if city.data.lane_dir(cell) != Vector2i.ZERO:
			return MapData.cell_center(cell)
	return city.data.world_rect().get_center()
