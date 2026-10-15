class_name Gangster
extends Npc
## Thành viên Red Fangs: canh hang ổ, thấy người chơi thì buông một câu chọc ghẹo rồi áp sát và bắn (bị bắn trước thì
## bắn luôn). Chết rơi tiền.

const SKINS := ["soldier1", "manOld"]
const KEEP_DISTANCE := 230.0
const TAUNT_PAUSE := 0.7  # buông câu chọc ghẹo xong mới bắn

var guard_pos := Vector2.ZERO
var alerted := false
var _strafe := 1.0


func _ready() -> void:
	skin = SKINS[randi() % SKINS.size()]
	max_health = Tuning.GANG_HEALTH
	gun = Gun.new(DataDB.weapon("smg" if randf() < 0.4 else "pistol"))
	pose = str(gun.def.pose)
	super()
	add_to_group("gang")
	guard_pos = global_position
	face(randf() * TAU)


func _think(delta: float) -> void:
	var target := player_target()
	var p := player()
	if not alerted:
		if p.alive and can_see(target.global_position):
			alert()
			Speech.say(self, Speech.pick("GANG_TAUNT"), {}, Palette.EMOTE_ANGRY)
			_react += TAUNT_PAUSE
		move(Vector2.ZERO, delta)
		return
	if not p.alive:
		walk_to(guard_pos, Tuning.GANG_SPEED * 0.5, delta)
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < Tuning.NPC_SHOOT_RANGE and can_see(target.global_position):
		if dist > KEEP_DISTANCE:
			walk_dir((target.global_position - global_position).normalized() * Tuning.GANG_SPEED * 0.5, delta)
		shoot_at(target.global_position, delta)
		if randf() < delta * 0.5:
			_strafe = -_strafe
		knock_velocity += (target.global_position - global_position).normalized().rotated(PI * 0.5) * _strafe * 6.0
	else:
		_react = Tuning.NPC_REACTION
		walk_to(target.global_position, Tuning.GANG_SPEED, delta)


func alert() -> void:
	if not alerted:
		alerted = true
		_react = Tuning.NPC_REACTION
		for g in get_tree().get_nodes_in_group("gang"):
			if g != self and g.global_position.distance_to(global_position) < Tuning.NPC_SIGHT:
				g.alert()


func hear_gunshot(pos: Vector2, _shooter: Node) -> void:
	if alive and global_position.distance_to(pos) < Tuning.HEAR_GUNSHOT_RADIUS:
		alert()


func _on_attacked(_source: Node) -> void:
	alert()


func _die(dir: Vector2, source: Node) -> void:
	super(dir, source)
	Pickup.spawn_cash(city.effects, global_position, randi_range(Tuning.MONEY_DROP.x, Tuning.MONEY_DROP.y))
	if randf() < Tuning.GANG_HEALTH_DROP:
		Pickup.spawn_health(city.effects, global_position + Vector2(24, 12), Tuning.DROP_HEALTH)
