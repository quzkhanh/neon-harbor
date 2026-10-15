class_name Pedestrian
extends Npc
## Người đi đường: đi trên vỉa hè, nghe tiếng súng thì bỏ chạy. Một số người có súng: bị tấn công thì bắn trả một lúc;
## một số người khác bị đấm thì xông vào đấm lại, còn lại ôm đầu bỏ chạy.
## Thấy Jay nổ súng (khi chưa bị truy nã) thì gọi cảnh sát; còn sống sau vài giây là cuộc gọi tới nơi.
## Bị chĩa súng thì giơ tay; bị ngắm đủ lâu thì đánh rơi ví rồi chạy (ai thấy thì báo cảnh sát). Bắt chuyện: xem PedTalk.

const SKINS := ["manBrown", "womanGreen", "survivor1"]
const BRAWLER_CHANCE := 0.35
const CHAT_TIME := 3.0
## [kiểu, xác suất]: người kỳ dị theo thời điểm. Ban đêm đổi hẳn dàn nhân vật: người say, người làm ca đêm, kẻ đứng ở góc phố.
## "feeder": ông lão cho bồ câu ăn, bồ câu quanh đó tụ lại (Critter).
const DAY_QUIRKS := [["robot", 0.05], ["feeder", 0.06]]
const NIGHT_QUIRKS := [["drunk", 0.2], ["nightshift", 0.14], ["loiter", 0.12], ["robot", 0.03]]
const QUIRK_SKINS := {"robot": "robot1", "feeder": "manOld", "nightshift": "manBlue", "loiter": "survivor1"}
const DRUNK_SPEED := 0.55
const DRUNK_SWAY := 38.0  # px/giây lắc ngang khi đi
const DRUNK_SWAY_RATE := 2.2
const HICCUP_EVERY := Vector2(8.0, 16.0)
const LOITER_RANGE := 220.0
const LOITER_EVERY := Vector2(7.0, 14.0)

var _target := Vector2.ZERO
var _heading := Vector2i.RIGHT
var _flee_from := Vector2.ZERO
var _flee_time := 0.0
var armed := false
var _angry := 0.0
var _report := 0.0
var zombie := false
var brawler := false
var scripted := false  # đang trong một sự cố giao thông (RoadIncident): kịch bản điều khiển, không tự đi lang thang
var quirk := ""  # "robot", "feeder" hoặc "" (người thường): quyết định kiểu nói chuyện
var waiting := false  # đang chờ Jay mang đồ về (việc vặt)
var holdup := PedHoldup.new()
var _chat := 0.0
var _chat_with: Pedestrian
var _quirk_time := 0.0
var _next_quirk_line := randf_range(HICCUP_EVERY.x, HICCUP_EVERY.y)

static var _last_report_ms := -100000


func _ready() -> void:
	skin = SKINS[randi() % SKINS.size()]
	quirk = _roll_quirk()
	skin = QUIRK_SKINS.get(quirk, skin)
	if quirk == "feeder":
		add_to_group("feeders")
	max_health = Tuning.PED_HEALTH
	heat_on_hit = Tuning.HEAT_SHOOT_PED
	heat_on_kill = Tuning.HEAT_KILL_PED
	armed = randf() < Tuning.ARMED_PED_CHANCE
	brawler = not armed and randf() < BRAWLER_CHANCE
	if armed:
		gun = Gun.new(DataDB.weapon("pistol"))
	super()
	if Game.zombies:
		zombify()
	_heading = MapData.DIRS[randi() % 4]
	_target = global_position


func _think(delta: float) -> void:
	if scripted:
		return
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
		var reach := float(gun.def.range) + Tuning.HUMAN_RADIUS if gun.def.kind == "melee" else Tuning.NPC_SHOOT_RANGE
		if player().alive and can_see(target, reach):
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
	if holdup.update(self, delta):
		return
	if _chat > 0.0 or waiting:
		_chat -= delta
		walk_dir(Vector2.ZERO, delta)
		var listener: Node2D = _chat_with if is_instance_valid(_chat_with) else player()
		face(lerp_angle(facing, (listener.global_position - global_position).angle(), minf(8.0 * delta, 1.0)))
		return
	_quirk_time += delta
	_say_quirk_line(delta)
	if quirk == "loiter":  # đứng yên ở góc phố, nhìn người qua lại
		walk_dir(Vector2.ZERO, delta)
		return
	if global_position.distance_to(_target) < 6.0:
		_pick_next()
	var walk := (_target - global_position).normalized() * Tuning.PED_SPEED
	if quirk == "drunk":
		walk = walk * DRUNK_SPEED + walk.orthogonal().normalized() * sin(_quirk_time * DRUNK_SWAY_RATE) * DRUNK_SWAY
	walk_dir(walk, delta)


func _roll_quirk() -> String:
	var roll := randf()
	for q in NIGHT_QUIRKS if Game.is_night() else DAY_QUIRKS:
		if roll < q[1]:
			return q[0]
		roll -= q[1]
	return ""


## Người say thỉnh thoảng nấc / lảm nhảm; kẻ đứng góc phố lên tiếng khi Jay đi ngang.
func _say_quirk_line(delta: float) -> void:
	_next_quirk_line -= delta
	if _next_quirk_line > 0.0 or not (quirk == "drunk" or quirk == "loiter"):
		return
	var reach := LOITER_RANGE if quirk == "loiter" else INF
	if global_position.distance_to(player().global_position) < reach and global_position.distance_to(city.camera.get_screen_center_position()) < Tuning.SPAWN_MIN_DIST:
		Speech.say(self, Speech.pick("PED_DRUNK" if quirk == "drunk" else "PED_LOITER"))
	var every := HICCUP_EVERY if quirk == "drunk" else LOITER_EVERY
	_next_quirk_line = randf_range(every.x, every.y)


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


## Có thể bắt chuyện: còn sống, bình tĩnh (không chạy trốn, không đánh nhau, không bị chĩa súng).
func can_chat() -> bool:
	return alive and not zombie and not scripted and _angry <= 0.0 and _flee_time <= 0.0 and not holdup.active()


## Dừng lại, quay sang nói chuyện với Jay một lúc.
func chat() -> void:
	_chat = CHAT_TIME
	_chat_with = null


## Rảnh rỗi: có đang đi dạo, không bận gì, nên bắt chuyện với người khác được.
func is_idle() -> bool:
	return can_chat() and _chat <= 0.0 and not waiting


## Dừng lại, quay sang `other` nói chuyện trong `seconds` giây.
func chat_with(other: Pedestrian, seconds: float) -> void:
	_chat = seconds
	_chat_with = other


## Thấy Jay phạm tội ở `pos` (khi chưa bị truy nã, không trong lúc làm nhiệm vụ): vài giây sau gọi cảnh sát.
func witness(pos: Vector2) -> void:
	var busy := city.missions.current != null or city.activities.current != null  # đang làm nhiệm vụ: không ai báo
	if Game.stars == 0 and _report <= 0.0 and not busy and not zombie and can_see(pos):
		_report = Tuning.WITNESS_DELAY


func hear_gunshot(pos: Vector2, shooter: Node) -> void:
	if not alive or global_position.distance_to(pos) > Tuning.HEAR_GUNSHOT_RADIUS:
		return
	if shooter is Player:
		witness(pos)
	if _angry <= 0.0 and not zombie:
		if _flee_time <= 0.0:
			Emote.show_on(self, Emote.Kind.ALERT)
		flee(pos)


func _call_cops() -> void:
	if not alive or Game.stars > 0 or Time.get_ticks_msec() - _last_report_ms < Tuning.WITNESS_COOLDOWN * 1000.0:
		return
	_last_report_ms = Time.get_ticks_msec()
	Game.add_heat(Tuning.HEAT_WITNESS)
	Game.notice.emit(tr("NOTICE_WITNESS"))


## Bị chọc giận (bị tấn công khi có súng, bị đấm khi máu nóng, hay bị cướp xe): đánh trả người chơi một lúc.
func provoke(weapon := "pistol") -> void:
	if gun == null:
		gun = Gun.new(DataDB.weapon(weapon))
	armed = gun.def.kind != "melee"
	_angry = Tuning.ANGRY_TIME
	_flee_time = 0.0
	holdup.release(self)
	_react = Tuning.NPC_REACTION
	set_pose(str(gun.def.pose))
	if armed:
		Emote.show_on(self, Emote.Kind.ANGRY)
	else:
		Speech.say(self, Speech.pick("PED_FIGHT"))


func flee(from: Vector2) -> void:
	_flee_from = from
	_flee_time = Tuning.PED_FLEE_TIME
	_chat = 0.0
	_chat_with = null
	holdup.release(self)


func _on_attacked(source: Node) -> void:
	scripted = false  # bị tấn công giữa vụ cãi nhau: thôi kịch bản, phản ứng như người thường
	if zombie or not source is Node2D:
		return
	var punched: bool = source is Player and source.vehicle == null and source.gun.def.kind == "melee"
	if source is Player and (armed or (brawler and punched)):
		provoke("pistol" if armed else "fists")
	elif _angry <= 0.0:
		if _flee_time <= 0.0:
			Emote.show_on(self, Emote.Kind.FEAR)
		flee(source.global_position)

