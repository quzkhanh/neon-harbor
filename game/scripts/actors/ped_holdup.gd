class_name PedHoldup
extends RefCounted
## Người đi đường bị Jay chĩa súng (ngắm có chủ đích, không tính hướng ngắm tự đi theo hướng chạy): đứng im giơ tay; bị ngắm đủ lâu thì đánh rơi ví rồi bỏ chạy, ai thấy thì báo
## cảnh sát. Người có súng thì không giơ tay mà rút súng bắn lại. Mỗi người chỉ bị trấn một lần.

const RANGE := 280.0
const CONE := 0.2  # rad: Jay ngắm lệch ít hơn chừng này là đang chĩa vào người này
const DROP_TIME := 1.5  # bị chĩa súng chừng này giây thì đánh rơi ví
const WALLET := Vector2i(15, 45)

var _time := 0.0
var _mugged := false


func active() -> bool:
	return _time > 0.0


## Trả về true khi người này đang giơ tay (bỏ qua các hành vi khác trong frame này).
func update(ped: Pedestrian, delta: float) -> bool:
	if _mugged or not _aimed_at(ped):
		release(ped)
		return false
	if ped.armed:
		ped.provoke()
		return false
	if _time <= 0.0:
		ped.set_pose("hold")
		Emote.show_on(ped, Emote.Kind.ALERT)
	_time += delta
	ped.walk_dir(Vector2.ZERO, delta)
	ped.face((ped.player().global_position - ped.global_position).angle())
	if _time >= DROP_TIME:
		_drop_wallet(ped)
	return true


## Hạ tay (hết bị chĩa súng, bỏ chạy hay nổi giận).
func release(ped: Pedestrian) -> void:
	if _time > 0.0:
		_time = 0.0
		ped.set_pose("stand")


func _aimed_at(ped: Pedestrian) -> bool:
	var p := ped.player()
	if not p.alive or not p.aiming or p.vehicle or p.gun.def.get("kind", "melee") == "melee":
		return false
	var to := ped.global_position - p.global_position
	return to.length() < RANGE and absf(angle_difference(p.aim_angle, to.angle())) < CONE and ped.can_see(p.global_position)


func _drop_wallet(ped: Pedestrian) -> void:
	_mugged = true
	var to_player := (ped.player().global_position - ped.global_position).normalized()
	Pickup.spawn_cash(ped.city.effects, ped.global_position + to_player * Tuning.HUMAN_RADIUS * 2.0, randi_range(WALLET.x, WALLET.y))
	Speech.say(ped, Speech.pick("PED_PLEAD"))
	ped.flee(ped.player().global_position)
	for other in ped.get_tree().get_nodes_in_group("peds"):
		if other != ped and other.alive:
			other.witness(ped.global_position)
