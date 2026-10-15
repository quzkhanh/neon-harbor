extends MissionBase
## NV5 Hold the Line: Rosa đưa súng trường và áo giáp; giữ quán của cô (y) trước 3 đợt Red Fangs. Bỏ đi quá xa là thua.

const GEAR_WEAPON := "rifle"
const ARRIVE := 120.0

var _wave := 0
var _left := 0
var _holding := false


func _ready() -> void:
	Game.grant_weapon(GEAR_WEAPON)
	Game.add_armor(Tuning.MAX_ARMOR)
	Game.notice.emit(tr("NOTICE_ROSA_RIFLE"))
	Game.set_objective("M5_OBJ_GO")
	mark(cell_pos("y"))


func _process(_delta: float) -> void:
	var bar := cell_pos("y")
	if not _holding:
		if near(bar, ARRIVE):
			_holding = true
			unmark()
			_next_wave()
		return
	if not near(bar, Tuning.M5_LEAVE_RADIUS):
		failed.emit("M5_FAIL_LEFT")


func _next_wave() -> void:
	_wave += 1
	var center := MapData.world_to_cell(cell_pos("y"))
	var size: int = Tuning.M5_WAVES[_wave - 1]
	var spots: Array[Vector2i] = []
	for r in range(8, 13):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r), Vector2i(r, r), Vector2i(-r, r)]:
			if city.data.is_ped_walkable(center + d):
				spots.append(center + d)
	spots.shuffle()
	_left = size
	for i in size:
		var g: Gangster = track(city.spawn_npc(Gangster, MapData.cell_center(spots[i % spots.size()])))
		g.alert()
		g.died.connect(_on_died)
	_update()


func _on_died(_h: Human) -> void:
	_left -= 1
	if _left > 0:
		_update()
	elif _wave < Tuning.M5_WAVES.size():
		Game.notice.emit(tr("NOTICE_WAVE_CLEARED"))
		_next_wave()
	else:
		completed.emit()


func _update() -> void:
	Game.set_objective("M5_OBJ_HOLD", {"wave": _wave, "waves": Tuning.M5_WAVES.size(), "left": _left})
