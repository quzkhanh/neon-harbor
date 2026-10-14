class_name Projectile
extends Node2D
## Lựu đạn (nảy trên tường, nổ sau ngòi) và tên lửa (nổ khi chạm).

var velocity := Vector2.ZERO
var weapon: Dictionary
var source: Node
var exclude: Array[RID] = []
var fuse := 0.0
var rocket := false
var _travel := 0.0
var _trail: CPUParticles2D


static func spawn_grenade(shooter: Node2D, w: Dictionary, origin: Vector2, angle: float) -> void:
	var p := _make(shooter, w, origin, "grenade")
	p.velocity = Vector2.from_angle(angle) * Tuning.GRENADE_SPEED
	p.fuse = Tuning.GRENADE_FUSE


static func spawn_rocket(shooter: Node2D, w: Dictionary, origin: Vector2, angle: float, exclude: Array[RID]) -> void:
	var p := _make(shooter, w, origin, "rocket")
	p.rocket = true
	p.rotation = angle
	p.velocity = Vector2.from_angle(angle) * Tuning.ROCKET_SPEED
	p.exclude = exclude
	p._trail = Fx.burst(Vector2.ZERO, "smoke", 24, 30.0, 0.6, Color(0.8, 0.8, 0.85, 0.6), false)
	p._trail.reparent(p, false)
	p._trail.one_shot = false
	p._trail.explosiveness = 0.0
	p._trail.local_coords = false


static func _make(shooter: Node2D, w: Dictionary, origin: Vector2, sprite: String) -> Projectile:
	var p := Projectile.new()
	p.weapon = w
	p.source = shooter
	p.global_position = origin
	p.z_index = 4
	var s := Sprite2D.new()
	s.texture = Fx.tex(sprite)
	p.add_child(s)
	Fx.root.add_child(p)
	return p


func _physics_process(delta: float) -> void:
	var motion := velocity * delta
	var mask := Combat.HIT_MASK if rocket else Tuning.LAYER_WORLD | Tuning.LAYER_VEHICLES
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, mask, exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if rocket:
		_travel += motion.length()
		if not hit.is_empty() or _travel > float(weapon.range):
			_explode(hit.get("position", global_position + motion))
			return
		global_position += motion
		return
	if hit.is_empty():
		global_position += motion
	else:
		velocity = velocity.bounce(hit.normal) * Tuning.GRENADE_BOUNCE
		global_position = hit.position + hit.normal * 2.0
	velocity = velocity.lerp(Vector2.ZERO, minf(Tuning.GRENADE_DAMP * delta, 1.0))
	rotation += velocity.length() * delta * 0.05
	fuse -= delta
	if fuse <= 0.0:
		_explode(global_position)


func _explode(pos: Vector2) -> void:
	Combat.explode(self, pos, float(weapon.damage), float(weapon.radius), source)
	if _trail:
		_trail.reparent(Fx.root)
		_trail.emitting = false
		get_tree().create_timer(_trail.lifetime).timeout.connect(_trail.queue_free)
	queue_free()
