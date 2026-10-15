class_name Pedestrian
extends Npc
## Người đi đường: đi trên vỉa hè, nghe tiếng súng thì bỏ chạy. Một số người có súng: bị tấn công thì bắn trả một lúc.
## Thấy Jay nổ súng (khi chưa bị truy nã) thì gọi cảnh sát; còn sống sau vài giây là cuộc gọi tới nơi.

const SKINS := ["manBrown", "womanGreen", "survivor1"]

var _target := Vector2.ZERO
var _heading := Vector2i.RIGHT
var _flee_from := Vector2.ZERO
var _flee_time := 0.0
var armed := false
var _angry := 0.0
var _report := 0.0
var zombie := false

static var _last_report_ms := -100000


func _ready() -> void:
	skin = SKINS[randi() % SKINS.size()]
	max_health = Tuning.PED_HEALTH
	heat_on_hit = Tuning.HEAT_SHOOT_PED
	heat_on_kill = Tuning.HEAT_KILL_PED
	armed = randf() < Tuning.ARMED_PED_CHANCE
	if armed:
		gun = Gun.new(DataDB.weapon("pistol"))
	super()
	if Game.zombies:
		zombify()
	_heading = MapData.DIRS[randi() % 4]
	_target = global_position


func _think(delta: float) -> void:
	if zombie:
		_shamble(delta)
		return
	if _report > 0.0:
		_report -= delta
		if _report <= 0.0:
			_call_cops()
	if _angry > 0.0:
		_angry -= delta
		var target := player_target().global_position
		if player().alive and can_see(target, Tuning.NPC_SHOOT_RANGE):
			shoot_at(target, delta)
		else:
			walk_to(target, Tuning.PED_FLEE_SPEED, delta)
		return
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


## Đêm zombie (mã gian lận): lê về phía Jay, tới sát thì cắn.
func zombify() -> void:
	zombie = true
	heat_on_hit = 0.0
	heat_on_kill = 0.0
	armed = false
	gun = null
	skin = "zombie1"
	set_pose("hold")


func _shamble(delta: float) -> void:
	var target := player_target()
	var dist := global_position.distance_to(target.global_position)
	if not player().alive or dist > Tuning.ZOMBIE_SENSE:
		walk_dir(Vector2.ZERO, delta)
		return
	if dist > Tuning.ZOMBIE_REACH:
		walk_to(target.global_position, Tuning.ZOMBIE_SPEED, delta)
		return
	walk_dir(Vector2.ZERO, delta)
	_react -= delta
	if _react <= 0.0:
		_react = Tuning.ZOMBIE_BITE_EVERY
		target.take_hit(Tuning.ZOMBIE_BITE, target.global_position - global_position, self, 60.0)
		Sfx.play_at("punch", global_position)


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


func hear_gunshot(pos: Vector2, shooter: Node) -> void:
	if not alive or global_position.distance_to(pos) > Tuning.HEAR_GUNSHOT_RADIUS:
		return
	var busy := city.missions.current != null or city.activities.current != null  # đang làm nhiệm vụ: không ai báo
	if shooter is Player and Game.stars == 0 and _report <= 0.0 and not busy and not zombie and can_see(pos):
		_report = Tuning.WITNESS_DELAY
	if _angry <= 0.0 and not zombie:
		flee(pos)


func _call_cops() -> void:
	if not alive or Game.stars > 0 or Time.get_ticks_msec() - _last_report_ms < Tuning.WITNESS_COOLDOWN * 1000.0:
		return
	_last_report_ms = Time.get_ticks_msec()
	Game.add_heat(Tuning.HEAT_WITNESS)
	Game.notice.emit(tr("NOTICE_WITNESS"))


## Bị chọc giận (bị tấn công khi có súng, hay bị cướp xe): bắn trả người chơi một lúc.
func provoke() -> void:
	if gun == null:
		armed = true
		gun = Gun.new(DataDB.weapon("pistol"))
	_angry = Tuning.ANGRY_TIME
	_flee_time = 0.0
	_react = Tuning.NPC_REACTION
	set_pose(str(gun.def.pose))


func flee(from: Vector2) -> void:
	_flee_from = from
	_flee_time = Tuning.PED_FLEE_TIME


func _on_attacked(source: Node) -> void:
	if zombie:
		return
	if armed and source is Player:
		provoke()
	elif source is Node2D:
		flee(source.global_position)

