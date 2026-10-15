class_name Combat
extends Object
## Bắn (tia, xuyên mục tiêu), ném lựu đạn, bắn tên lửa, phun lửa, nổ vùng.

const HIT_MASK := Tuning.LAYER_WORLD | Tuning.LAYER_ACTORS | Tuning.LAYER_VEHICLES | Tuning.LAYER_AIR


## Bắn một phát của súng `w` từ `origin` theo góc `angle`. `exclude`: RID không bị trúng (người bắn, xe của họ).
static func fire(shooter: Node2D, w: Dictionary, origin: Vector2, angle: float, exclude: Array[RID]) -> void:
	if w.kind == "melee":
		_melee(shooter, w, angle)
		return
	match w.kind:
		"hitscan":
			for i in int(w.pellets):
				var spread := deg_to_rad(float(w.spread)) * 0.5
				_ray(shooter, w, origin, angle + randf_range(-spread, spread), exclude)
			Fx.muzzle(origin, angle, 1.4 if int(w.pellets) > 1 else 1.0)
			Fx.casing(shooter.global_position, angle)
		"throw":
			Projectile.spawn_grenade(shooter, w, origin, angle)
		"rocket":
			Projectile.spawn_rocket(shooter, w, origin, angle, exclude)
			Fx.muzzle(origin, angle, 1.6)
		"flame":
			_flame(shooter, w, origin, angle)
	if w.kind != "flame" or randf() < 0.2:
		Sfx.play_at(w.sound, origin, 0.0, randf_range(0.94, 1.06))
	Fx.shake(float(w.shake))
	shooter.get_tree().call_group("listeners", "hear_gunshot", origin, shooter)


static func _ray(shooter: Node2D, w: Dictionary, origin: Vector2, angle: float, exclude: Array[RID]) -> void:
	var dir := Vector2.from_angle(angle)
	var space := shooter.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, origin + dir * float(w.range), HIT_MASK, exclude.duplicate())
	var end := query.to
	var left := int(w.pierce)
	while left > 0:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		end = hit.position
		var target: Object = hit.collider
		if not target.has_method("take_hit"):
			Fx.impact(end)
			Sfx.play_at("impact", end, -8.0)
			break
		target.take_hit(float(w.damage), dir, shooter, float(w.knockback))
		Sfx.play_at("hit", end, -6.0)
		left -= 1
		var ex := query.exclude
		ex.append(hit.rid)
		query.exclude = ex
		if left > 0:
			end = query.to
	Fx.tracer(origin, end, 3.0 if int(w.pierce) > 1 else 2.0)


static func _flame(shooter: Node2D, w: Dictionary, origin: Vector2, angle: float) -> void:
	var reach := float(w.range)
	Fx.flame_puff(origin, angle, reach)
	var space := shooter.get_world_2d().direct_space_state
	for n in shooter.get_tree().get_nodes_in_group("damageable"):
		if n == shooter:
			continue
		var to: Vector2 = n.global_position - origin
		if to.length() > reach or absf(angle_difference(angle, to.angle())) > deg_to_rad(float(w.spread)):
			continue
		var los := PhysicsRayQueryParameters2D.create(origin, n.global_position, Tuning.LAYER_WORLD)
		if not space.intersect_ray(los).is_empty():
			continue
		n.take_hit(float(w.damage), to, shooter, float(w.knockback))
		if n.has_method("ignite"):
			n.ignite(shooter)


## Đòn cận chiến: trúng mọi mục tiêu trong hình quạt trước mặt (không xuyên tường), không gây tiếng súng.
static func _melee(shooter: Node2D, w: Dictionary, angle: float) -> void:
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
		n.take_hit(float(w.damage), to, shooter, float(w.knockback))
		hit = true
	Sfx.play_at("punch" if hit else str(w.sound), shooter.global_position, 0.0, randf_range(0.9, 1.1))
	if hit:
		Fx.shake(float(w.shake))


## Nguồn sát thương có thể đã bị giải phóng (người bắn chết/bị dọn trước khi xe nổ, lửa tắt...): coi như null.
static func source_or_null(source: Variant) -> Node:
	return source if is_instance_valid(source) else null


static func explode(world: Node, pos: Vector2, damage: float, radius: float, source: Variant) -> void:
	source = source_or_null(source)
	for n in world.get_tree().get_nodes_in_group("damageable"):
		var d: float = n.global_position.distance_to(pos)
		if d < radius:
			var falloff := 1.0 - 0.6 * d / radius
			var own := Tuning.SELF_BLAST_SCALE if n == source else 1.0
			n.take_hit(damage * falloff * own, n.global_position - pos, source, Tuning.EXPLOSION_KNOCKBACK * falloff)
	Fx.explosion(pos, radius)
	Sfx.play_at("explosion", pos)
	world.get_tree().call_group("listeners", "hear_gunshot", pos, source)
