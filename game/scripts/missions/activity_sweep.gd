extends MissionBase
## Việc phụ: càn quét từ điểm K. Một toán Red Fangs kéo tới quanh đó; hạ hết trong thời hạn để nhận thưởng.

var reward := 0
var _left := 0
var _time := Tuning.SWEEP_TIME


func _ready() -> void:
	var center := MapData.world_to_cell(city.player.global_position)
	var spots: Array[Vector2i] = []
	for r in range(5, 10):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r), Vector2i(r, r), Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r)]:
			if city.data.is_ped_walkable(center + d):
				spots.append(center + d)
	spots.shuffle()
	for i in mini(Tuning.SWEEP_COUNT, spots.size()):
		var g: Gangster = track(city.spawn_npc(Gangster, MapData.cell_center(spots[i])))
		g.alert()
		g.died.connect(_on_died)
		_left += 1
	Sfx.play("star")


func _on_died(_h: Human) -> void:
	_left -= 1
	if _left <= 0 and is_inside_tree():
		reward = Tuning.SWEEP_REWARD
		Game.add_money(reward)
		Game.bump("sweeps")
		Sfx.play("mission_complete")
		Game.notice.emit(I18n.fmt("NOTICE_JOB_DONE", {"money": I18n.money(reward)}))
		completed.emit()


func _process(delta: float) -> void:
	_time -= delta
	Game.set_objective("SWEEP_OBJ", {"n": _left, "time": ceili(maxf(_time, 0.0))})
	if _time <= 0.0:
		failed.emit("FAIL_TIME")
