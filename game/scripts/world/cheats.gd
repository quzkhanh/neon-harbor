class_name Cheats
extends Node
## Mã gian lận gõ trên bàn phím (chỉ để chơi vui). Đã dùng là save bị đánh dấu và không còn nhận thành tựu.

const CODES := {
	"NEONGOD": "_god", "FULLCLIP": "_guns", "HEATWAVE": "_heat", "COOLOFF": "_cool", "FASTLANE": "_car", "DEADTOWN": "_zombies",
}
const MAX_LEN := 12

var city: City
var _typed := ""


func _init(c: City) -> void:
	city = c
	name = "Cheats"


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.unicode > 0):
		return
	_typed = (_typed + char(event.unicode).to_upper()).right(MAX_LEN)
	for code in CODES:
		if _typed.ends_with(code):
			_typed = ""
			Game.stats["cheated"] = 1
			call(CODES[code])
			Sfx.play("star")


func _god() -> void:
	Game.god = not Game.god
	Game.notice.emit(tr("CHEAT_GOD_ON" if Game.god else "CHEAT_GOD_OFF"))


func _guns() -> void:
	for w in DataDB.weapons():
		Game.grant_weapon(w.id)
	Game.select_weapon("rifle")
	Game.notice.emit(tr("CHEAT_GUNS"))


func _heat() -> void:
	Game.set_stars(mini(Game.stars + 1, Tuning.MAX_STARS))
	Game.notice.emit(tr("CHEAT_HEAT"))


func _cool() -> void:
	Game.clear_wanted()
	Game.notice.emit(tr("CHEAT_COOL"))


func _car() -> void:
	var p := city.player
	var v := city.spawn_vehicle("super", MapData.world_to_cell(p.global_position), p.facing)
	v.global_position = p.global_position + Vector2.from_angle(p.facing) * Tuning.TILE * 1.5
	v.reset_physics_interpolation()
	Game.notice.emit(tr("CHEAT_CAR"))


func _zombies() -> void:
	Game.zombies = not Game.zombies
	for ped in city.population.peds():
		if Game.zombies:
			ped.zombify()
		else:
			ped.queue_free()
	Game.notice.emit(tr("CHEAT_ZOMBIES_ON" if Game.zombies else "CHEAT_ZOMBIES_OFF"))
