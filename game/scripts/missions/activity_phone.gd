extends MissionBase
## Việc vặt của Lucky Live: một tên trộm giật điện thoại của Lucky rồi bỏ chạy. Hạ gục hoặc quật ngã hắn (đấm đủ combo,
## bắn, tông xe) để lấy lại rồi mang về trả. Đánh tên trộm không tính là phạm tội. Hắn chạy quá xa, hay Lucky chết, là
## thất bại. Lucky trả tiền, có khi "quên ví" nhưng rồi vẫn chuyển khoản.

const ESCAPE := 1100.0
const ARRIVE := 60.0
const REWARD := Vector2i(150, 260)
const WALLET_JOKE := 0.35

var lucky: Streamer
var thief: Pedestrian
var _found := false


func _ready() -> void:
	lucky = city.streamer.lucky
	lucky.say("LUCKY_JOB_ASK")
	var cell := MapData.world_to_cell(lucky.global_position)
	var start := lucky.global_position
	for d in MapData.DIRS:
		if city.data.is_ped_walkable(cell + d):
			start = MapData.cell_center(cell + d)
			break
	thief = city.spawn_npc(Pedestrian, start)
	thief.armed = false
	thief.gun = null
	thief.brawler = false
	thief.heat_on_hit = 0.0
	thief.heat_on_kill = 0.0


func _process(_delta: float) -> void:
	if not is_instance_valid(lucky) or not lucky.alive:
		failed.emit("FAIL_ERRAND_OWNER")
		return
	Game.set_objective("JOB_PHONE_RETURN" if _found else "JOB_PHONE_CHASE")
	if not _found:
		_chase()
		return
	mark(lucky.global_position)
	if near(lucky.global_position, ARRIVE) and city.player.vehicle == null:
		var pay := randi_range(REWARD.x, REWARD.y)
		Game.add_money(pay)
		Sfx.play("cash")
		lucky.say("LUCKY_WALLET" if randf() < WALLET_JOKE else "LUCKY_THANKS")
		Game.notice.emit(I18n.fmt("NOTICE_JOB_DONE", {"money": I18n.money(pay)}))
		completed.emit()


func _chase() -> void:
	if not is_instance_valid(thief):
		failed.emit("FAIL_THIEF_ESCAPED")
		return
	if not thief.alive or thief.knocked > 0.0:
		_found = true
		thief.add_to_group("peds")  # xong vai: Population lo dọn như người đi đường thường
		Sfx.play("pickup")
		Game.notice.emit(tr("NOTICE_PHONE_FOUND"))
		return
	if thief.global_position.distance_to(city.player.global_position) > ESCAPE:
		failed.emit("FAIL_THIEF_ESCAPED")
		return
	thief.flee(city.player.global_position)
	mark(thief.global_position)


func cleanup() -> void:
	super()
	if is_instance_valid(thief) and not _found:
		thief.queue_free()
