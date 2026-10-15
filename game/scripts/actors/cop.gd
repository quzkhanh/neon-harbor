class_name Cop
extends Npc
## Cảnh sát NHPD: khi có sao truy nã thì đuổi theo và bắn; hết sao thì rời đi.

var _patrol_dir := Vector2.ZERO


func _ready() -> void:
	_equip()
	heat_on_hit = Tuning.HEAT_HIT_COP
	heat_on_kill = Tuning.HEAT_KILL_COP
	pose = str(gun.def.pose)
	super()
	add_to_group("cops")


## Trang phục, máu, súng; Swat ghi đè.
func _equip() -> void:
	skin = "manBlue"
	max_health = Tuning.COP_HEALTH
	gun = Gun.new(DataDB.weapon(Tuning.COP_WEAPON[Game.stars]))


func sees_player() -> bool:
	return alive and player().alive and can_see(player_target().global_position, Tuning.COP_SIGHT)


func _think(delta: float) -> void:
	var target := player_target()
	if Game.stars == 0 or not player().alive:
		if _patrol_dir == Vector2.ZERO:
			_patrol_dir = (global_position - target.global_position).normalized()
		walk_dir(_patrol_dir * Tuning.PED_SPEED, delta)
		return
	_patrol_dir = Vector2.ZERO
	var dist := global_position.distance_to(target.global_position)
	if dist < Tuning.NPC_SHOOT_RANGE and can_see(target.global_position):
		shoot_at(target.global_position, delta)
	else:
		_react = Tuning.NPC_REACTION
		walk_to(target.global_position, Tuning.COP_SPEED, delta)


func hear_gunshot(pos: Vector2, shooter: Node) -> void:
	if alive and shooter is Player and Game.stars == 0 and can_see(pos, Tuning.COP_SIGHT):
		Game.add_heat(Tuning.HEAT_GUNFIRE_SEEN)


func _die(dir: Vector2, source: Node) -> void:
	super(dir, source)
	if randf() < Tuning.COP_HEALTH_DROP:
		Pickup.spawn_health(city.effects, global_position + Vector2(24, 12), Tuning.DROP_HEALTH)
