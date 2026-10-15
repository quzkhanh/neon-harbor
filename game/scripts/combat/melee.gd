class_name Melee
extends Object
## Đòn cận chiến: trúng mọi mục tiêu trong hình quạt trước mặt (không xuyên tường), không gây tiếng súng.
## Người đánh nhoài tới, vệt chém quét theo cú vung. Trúng thì nạn nhân lảo đảo, sao tóe; người chơi đánh trúng thì
## khựng hình một chút (hit-stop). Người chơi đánh liên tiếp thành combo; cú thứ COMBO_HITS mạnh hơn và làm ngã.

const COMBO_HITS := 3
const COMBO_WINDOW := 0.35  # giây sau khi hồi đòn mà vẫn nối được combo
const FINISHER_DAMAGE := 1.6
const FINISHER_KNOCKBACK := 1.5
const FINISHER_RECOVERY := 0.25  # cú cuối hồi lâu hơn
const HITSTOP_TIME := 0.06
const HITSTOP_FINISHER := 0.1
const HITSTOP_SCALE := 0.05


## `step`: thứ tự cú đánh trong combo (1..COMBO_HITS); NPC luôn đánh cú 1.
static func swing(shooter: Node2D, w: Dictionary, angle: float, step := 1) -> void:
	var finisher := step == COMBO_HITS
	if shooter is Human:
		shooter.lunge()
	SwingArc.spawn(shooter, w, angle, step)
	var space := shooter.get_world_2d().direct_space_state
	var hit := false
	for n in shooter.get_tree().get_nodes_in_group("damageable"):
		if n == shooter or (n is Human and not n.alive):
			continue
		var to: Vector2 = n.global_position - shooter.global_position
		var reach: float = float(w.range) + (n.size.y * 0.5 if n is Vehicle else Tuning.HUMAN_RADIUS)
		if to.length() > reach or absf(angle_difference(angle, to.angle())) > deg_to_rad(float(w.spread)):
			continue
		var los := PhysicsRayQueryParameters2D.create(shooter.global_position, n.global_position, Tuning.LAYER_WORLD)
		if not space.intersect_ray(los).is_empty():
			continue
		_strike(n, shooter, w, to, finisher)
		hit = true
	Sfx.play_at("punch" if hit else str(w.sound), shooter.global_position, 0.0, randf_range(0.9, 1.1) - (0.15 if finisher else 0.0))
	if hit and shooter is Player:
		Fx.shake(float(w.shake) * (2.0 if finisher else 1.0))
		hit_stop(shooter.get_tree(), HITSTOP_FINISHER if finisher else HITSTOP_TIME)


static func _strike(n: Node2D, shooter: Node2D, w: Dictionary, to: Vector2, finisher: bool) -> void:
	var damage := float(w.damage) * (FINISHER_DAMAGE if finisher else 1.0)
	_star(n.global_position - to.normalized() * Tuning.HUMAN_RADIUS, finisher)
	if finisher and n is Human:
		n.knock_down(to.normalized() * float(w.knockback) * FINISHER_KNOCKBACK, damage, shooter)
		return
	n.take_hit(damage, to, shooter, float(w.knockback))
	if n is Human:
		n.stagger()


## Sao tóe ở điểm trúng (cú cuối combo: to hơn).
static func _star(pos: Vector2, big: bool) -> void:
	if Fx.root:
		Fx.burst(pos, "spark", 10 if big else 6, 220.0 if big else 150.0, 0.22, Palette.HIT_STAR)
		var glow := Fx.burst(pos, "glow", 1, 1.0, 0.14, Palette.HIT_STAR)
		glow.scale_amount_min = 0.45 if big else 0.28
		glow.scale_amount_max = glow.scale_amount_min


## Khựng hình: thời gian gần như dừng trong chốc lát (tính theo giờ thật). Không chen vào lúc đang chậm vì việc khác
## (vòng chọn súng), và chỉ trả lại tốc độ thường nếu không ai đổi time_scale trong lúc đó.
static func hit_stop(tree: SceneTree, seconds: float) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = HITSTOP_SCALE
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if Engine.time_scale == HITSTOP_SCALE:
			Engine.time_scale = 1.0)
