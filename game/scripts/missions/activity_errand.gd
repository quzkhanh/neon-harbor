extends MissionBase
## Việc vặt: người đi đường nhờ tìm món đồ đánh rơi ở vỉa hè gần đó rồi mang trả. Người nhờ đứng chờ tại chỗ;
## họ chết là thất bại.

const RANGE := Vector2(260, 640)
const TRIES := 60
const ARRIVE := 60.0
const REWARD := Vector2i(60, 140)

var asker: Pedestrian
var _found := false


func _ready() -> void:
	asker.waiting = true
	asker.remove_from_group("peds")  # Population không được dọn mất người đang chờ
	var spot := _spot()
	var item := track(Pickup.make(city.effects, spot, "package", false)) as Pickup
	item.collected.connect(func() -> void:
		_found = true
		Sfx.play("pickup")
		Game.notice.emit(tr("NOTICE_ERRAND_FOUND")))
	mark(spot)


## Ô vỉa hè ngẫu nhiên cách người nhờ một quãng vừa phải.
func _spot() -> Vector2:
	var cells := city.data.find_all(",")
	var best := asker.global_position
	for i in TRIES:
		var pos := MapData.cell_center(cells[randi() % cells.size()])
		var d := pos.distance_to(asker.global_position)
		if d > RANGE.x and d < RANGE.y:
			return pos
		if d > best.distance_to(asker.global_position):
			best = pos
	return best


func _process(_delta: float) -> void:
	if not is_instance_valid(asker) or not asker.alive:
		failed.emit("FAIL_ERRAND_OWNER")
		return
	Game.set_objective("JOB_ERRAND_RETURN" if _found else "JOB_ERRAND_FIND")
	if not _found:
		return
	mark(asker.global_position)
	if near(asker.global_position, ARRIVE) and city.player.vehicle == null:
		var pay := randi_range(REWARD.x, REWARD.y)
		Game.add_money(pay)
		Sfx.play("cash")
		Speech.say(asker, "PED_ERRAND_THANKS")
		Game.notice.emit(I18n.fmt("NOTICE_JOB_DONE", {"money": I18n.money(pay)}))
		completed.emit()


func cleanup() -> void:
	super()
	if is_instance_valid(asker):
		asker.waiting = false
		asker.add_to_group("peds")
