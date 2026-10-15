extends MissionBase
## NV9 Crane's Fall: Rosa đưa súng trường, áo giáp và hai đàn em; tấn công kho Red Fangs (w), hạ trùm Silas Crane,
## rồi cắt đuôi 4 sao truy nã.

const GEAR_WEAPON := "rifle"

var boss: Boss
var _left := 0
var _escaping := false


func _ready() -> void:
	Game.grant_weapon(GEAR_WEAPON)
	Game.add_armor(Tuning.MAX_ARMOR)
	Game.notice.emit(tr("NOTICE_ROSA_CREW"))
	for i in Tuning.ALLY_MAX - get_tree().get_nodes_in_group("allies").size():
		city.spawn_npc(Ally, city.player.global_position + Vector2(40 * (i + 1), 40))
	var warehouse := city.data.find("w")
	for g in spawn_gang(warehouse, Tuning.M9_GUARDS, 4):
		g.died.connect(_on_died)
		_left += 1
	for d in [Vector2i(-7, 2), Vector2i(7, 2)]:  # hộp máu ở rìa trận
		if city.data.is_ped_walkable(warehouse + d):
			track(Pickup.spawn_health(city.effects, MapData.cell_center(warehouse + d), Tuning.MEDKIT_PICKUP, false))
	boss = track(city.spawn_npc(Boss, MapData.cell_center(warehouse)))
	boss.died.connect(_on_died)
	_left += 1
	mark(MapData.cell_center(warehouse))
	_update()


func _on_died(_h: Human) -> void:
	_left -= 1
	if not is_instance_valid(boss) or not boss.alive:
		if not _escaping:
			_escaping = true
			unmark()
			Game.notice.emit(tr("NOTICE_SILAS_DOWN"))
			Game.set_stars(4)
	_update()


func _update() -> void:
	if _escaping:
		return
	Game.set_objective("M9_OBJ_BOSS" if _left <= 1 else "M9_OBJ_ASSAULT", {"left": _left - 1})


func _process(_delta: float) -> void:
	if _escaping:
		if Game.objective != "M3_OBJ_LOSE":
			Game.set_objective("M3_OBJ_LOSE")
		if Game.stars == 0:
			completed.emit()
