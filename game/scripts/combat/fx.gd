class_name Fx
extends Object
## Hiệu ứng hình ảnh dùng chung. `root` là node Effects của cảnh thành phố.

const DIR := "res://assets/sprites/fx/%s.png"
const ADD_BLEND := CanvasItemMaterial.BLEND_MODE_ADD

static var root: Node2D
static var _casings: Array = []
static var _add_material: CanvasItemMaterial


static func tex(fx_name: String) -> Texture2D:
	var path := DIR % fx_name
	return load(path) if ResourceLoader.exists(path) else null


static func additive() -> CanvasItemMaterial:
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = ADD_BLEND
	return _add_material


static func _sprite(fx_name: String, pos: Vector2, z := 5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(fx_name)
	s.global_position = pos
	s.z_index = z
	root.add_child(s)
	return s


static func muzzle(pos: Vector2, angle: float, size := 1.0) -> void:
	if root == null:
		return
	var s := _sprite("muzzle_flash", pos, 6)
	s.centered = false
	s.offset = Vector2(0, -16)
	s.rotation = angle
	s.scale = Vector2.ONE * size
	s.material = additive()
	var glow := _sprite("glow", pos, 6)
	glow.material = additive()
	glow.modulate = Color(1.0, 0.75, 0.35, 0.55)
	glow.scale = Vector2.ONE * 0.9 * size
	for n in [s, glow]:
		n.get_tree().create_timer(Tuning.MUZZLE_TIME).timeout.connect(n.queue_free)


static func casing(pos: Vector2, angle: float) -> void:
	if root == null:
		return
	var s := _sprite("shell", pos, -1)
	s.rotation = randf() * TAU
	var side := Vector2.from_angle(angle + PI * 0.5 + randf_range(-0.4, 0.4)) * randf_range(18, 34)
	var t := s.create_tween().set_parallel()
	t.tween_property(s, "position", s.position + side, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "rotation", s.rotation + randf_range(4, 9), 0.25)
	t.chain().tween_interval(Tuning.CASING_LIFE)
	t.chain().tween_property(s, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(s.queue_free)
	_casings = _casings.filter(func(c: Variant) -> bool: return is_instance_valid(c))
	_casings.append(s)
	while _casings.size() > Tuning.MAX_CASINGS:
		_casings.pop_front().queue_free()


static func tracer(from: Vector2, to: Vector2, width := 2.0) -> void:
	if root == null:
		return
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = width
	line.default_color = Palette.TRACER
	line.material = additive()
	line.z_index = 6
	root.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, Tuning.TRACER_TIME)
	t.tween_callback(line.queue_free)


static func burst(pos: Vector2, fx_name: String, amount: int, speed: float, life: float, color := Color.WHITE, add := true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex(fx_name)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.5
	p.damping_max = speed * 2.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	if add:
		p.material = additive()
	p.global_position = pos
	p.z_index = 6
	root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static func impact(pos: Vector2) -> void:
	if root:
		burst(pos, "spark", 5, 160.0, 0.25, Color(1, 0.85, 0.5))


static func explosion(pos: Vector2, radius: float) -> void:
	if root == null:
		return
	var scorch := _sprite("scorch", pos, -15)
	scorch.rotation = randf() * TAU
	scorch.scale = Vector2.ONE * radius / 70.0
	var t := scorch.create_tween()
	t.tween_interval(Tuning.WRECK_TIME)
	t.tween_property(scorch, "modulate:a", 0.0, 2.0)
	t.tween_callback(scorch.queue_free)
	var flash := _sprite("glow", pos, 7)
	flash.material = additive()
	flash.modulate = Color(1.0, 0.7, 0.3)
	flash.scale = Vector2.ONE * radius / 40.0
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.35)
	ft.tween_callback(flash.queue_free)
	burst(pos, "flame", 28, radius * 3.0, 0.6, Color(1.0, 0.6, 0.2))
	burst(pos, "smoke", 14, radius * 1.6, 1.4, Color(0.25, 0.25, 0.28, 0.8), false)
	burst(pos, "spark", 16, radius * 4.0, 0.5, Color(1, 0.9, 0.5))
	shake(radius / 12.0)


static func flame_puff(pos: Vector2, angle: float, reach: float) -> void:
	if root == null:
		return
	var p := burst(pos, "flame", 6, reach * 2.6, 0.35, Color(1.0, 0.65, 0.25))
	p.direction = Vector2.from_angle(angle)
	p.spread = 9.0
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2


static func shake(amount: float) -> void:
	if root:
		root.get_tree().call_group("camera_rig", "add_trauma", amount)
