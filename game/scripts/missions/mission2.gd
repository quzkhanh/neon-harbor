extends MissionBase
## NV2 Debt Collection: Rosa đưa tiểu liên + áo giáp; tới hang ổ Red Fangs, hạ 6 tên, nhặt vali, mang về cho Rosa.

const RING := 3
const GEAR_WEAPON := "smg"

var _left := Tuning.GANG_COUNT
var _case: Pickup
var _has_case := false


func _ready() -> void:
	Game.grant_weapon(GEAR_WEAPON)
	Game.add_armor(Tuning.MAX_ARMOR)
	Game.notice.emit(tr("NOTICE_ROSA_GEAR"))
	var hideout := city.data.find("r")
	var spots := _guard_spots(hideout)
	for i in Tuning.GANG_COUNT:
		var g: Gangster = track(city.spawn_npc(Gangster, MapData.cell_center(spots[i % spots.size()])))
		g.died.connect(_on_gang_died)
	_update_objective()
	mark(MapData.cell_center(hideout))


## Các ô đi được quanh hang ổ, cách đều nhau.
func _guard_spots(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-RING, RING + 1):
		for dx in range(-RING, RING + 1):
			var c := center + Vector2i(dx, dy) * 2
			if city.data.is_ped_walkable(c) or city.data.at(c) == "r":
				out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_to(center) < b.distance_to(center))
	return out


func _on_gang_died(_h: Human) -> void:
	_left -= 1
	_update_objective()
	if _left == 0:
		_case = track(Pickup.make(city.effects, cell_pos("r"), "briefcase", false))
		_case.collected.connect(_on_case)
		mark(cell_pos("r"))
		Game.set_objective("M2_OBJ_CASE")


func _update_objective() -> void:
	if _left > 0:
		Game.set_objective("M2_OBJ_KILL", {"n": _left})


func _on_case() -> void:
	_has_case = true
	Sfx.play("pickup")
	mark(cell_pos("2"))
	Game.set_objective("M2_OBJ_RETURN")


func _process(_delta: float) -> void:
	if _has_case and near(cell_pos("2")):
		completed.emit()
