class_name Gun
extends RefCounted
## Nhịp bắn và nạp đạn. Người chơi dùng đạn trong Game; NPC đạn vô hạn.

var def: Dictionary
var uses_game_ammo := false
var cooldown := 0.0
var reloading := 0.0
var combo := 0  # cú thứ mấy trong chuỗi cận chiến của người chơi


func _init(weapon: Dictionary = {}, player := false) -> void:
	def = weapon
	uses_game_ammo = player
	if not player and not weapon.is_empty():
		def = weapon.duplicate()
		def.rate = float(weapon.rate) * Tuning.NPC_RATE_SCALE
		def.damage = float(weapon.damage) * Tuning.NPC_DAMAGE_SCALE


## Trả về true khi vừa nạp xong.
func tick(delta: float) -> bool:
	cooldown -= delta
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			if uses_game_ammo:
				Game.finish_reload()
			return true
	return false


func try_fire(shooter: Node2D, origin: Vector2, angle: float, exclude: Array[RID]) -> bool:
	if cooldown > 0.0 or reloading > 0.0:
		return false
	if def.kind == "melee":
		combo = combo % Melee.COMBO_HITS + 1 if uses_game_ammo and cooldown > -Melee.COMBO_WINDOW else 1
		cooldown = 1.0 / float(def.rate) + (Melee.FINISHER_RECOVERY if combo == Melee.COMBO_HITS else 0.0)
		Melee.swing(shooter, def, angle, combo)
		return true
	if uses_game_ammo and not Game.consume_ammo():
		if not start_reload():
			Sfx.play("empty")
			cooldown = 0.3
		return false
	cooldown = 1.0 / float(def.rate)
	Combat.fire(shooter, def, origin, angle, exclude)
	if uses_game_ammo and int(Game.ammo().mag) == 0:
		start_reload()
	return true


func start_reload() -> bool:
	if def.kind == "melee" or reloading > 0.0 or (uses_game_ammo and not Game.can_reload()):
		return false
	reloading = float(def.reload)
	if def.kind != "throw":
		Sfx.play("reload", -4.0)
	return true
