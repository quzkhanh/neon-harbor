class_name Pedestrian
extends Npc
## Người đi đường: đi trên vỉa hè, nghe tiếng súng thì bỏ chạy.

const SKINS := ["manBrown", "womanGreen", "survivor1"]

var _target := Vector2.ZERO
var _heading := Vector2i.RIGHT
var _flee_from := Vector2.ZERO
var _flee_time := 0.0


func _ready() -> void:
	skin = SKINS[randi() % SKINS.size()]
	max_health = Tuning.PED_HEALTH
	heat_on_hit = Tuning.HEAT_SHOOT_PED
	heat_on_kill = Tuning.HEAT_KILL_PED
	super()
	_heading = MapData.DIRS[randi() % 4]
	_target = global_position


func _think(delta: float) -> void:
	if _flee_time > 0.0:
		_flee_time -= delta
		var away := (global_position - _flee_from).normalized()
		if get_slide_collision_count() > 0:
			away = away.rotated(PI * 0.5 * signf(randf() - 0.5))
			_flee_from = global_position - away * 10.0
		walk_dir(away * Tuning.PED_FLEE_SPEED, delta)
		return
	if global_position.distance_to(_target) < 6.0:
		_pick_next()
	walk_dir((_target - global_position).normalized() * Tuning.PED_SPEED, delta)


## Chọn ô vỉa hè kế tiếp, ưu tiên đi thẳng, tránh quay đầu.
func _pick_next() -> void:
	var data := city.data
	var cell := MapData.world_to_cell(global_position)
	var options: Array[Vector2i] = []
	for d in MapData.DIRS:
		if data.is_ped_walkable(cell + d) and d != -_heading:
			options.append(d)
			if d == _heading:
				options.append_array([d, d, d])
	if options.is_empty():
		options.append(-_heading)
	_heading = options[randi() % options.size()]
	var jitter := Vector2(randf_range(-14, 14), randf_range(-14, 14))
	_target = MapData.cell_center(cell + _heading) + jitter


func hear_gunshot(pos: Vector2, _shooter: Node) -> void:
	if alive and global_position.distance_to(pos) < Tuning.HEAR_GUNSHOT_RADIUS:
		flee(pos)


func flee(from: Vector2) -> void:
	_flee_from = from
	_flee_time = Tuning.PED_FLEE_TIME


func _on_attacked(source: Node) -> void:
	if source is Node2D:
		flee(source.global_position)

