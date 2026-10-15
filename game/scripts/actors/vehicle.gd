class_name Vehicle
extends CharacterBody2D
## Xe: lái arcade (tăng tốc, phanh, lùi, đánh lái theo tốc độ, drift), va chạm mất máu,
## hết máu thì cháy rồi nổ. Người lái là Player hoặc bộ lái tự động (`autopilot`).

signal destroyed(vehicle: Vehicle)

static var map: MapData  # bản đồ của cảnh thành phố (thuyền cần biết ô nào là nước); City gán

const CAR_DIR := "res://assets/vendor/cars/%s.png"
const SKID_TEX := "res://assets/vendor/objects/skidmark_short_1.png"

var kind := "car"
var spec: Dictionary
var sprite_name := ""
var hp := 100.0
var driver: Node
var autopilot: RefCounted
var has_npc_driver := false
var throttle := 0.0
var assist := false  # người chơi lái kiểu theo hướng phím (DriveInput)
var steer := 0.0
var handbrake := false
var boost := false  # người lái muốn đốt nitro
var nitro := Nitro.new()
var flat := false  # lốp thủng (dải đinh): chậm và trơn cho tới khi sửa
var stunt := Stunt.new()
var hull: BoatHull  # chỉ thuyền mới có
var burning := false
var wrecked := false
var last_attacker: Node
var size := Vector2.ZERO

var body: Sprite2D
var _engine: AudioStreamPlayer2D
var _skid_sound: AudioStreamPlayer2D
var _smoke: CPUParticles2D
var _siren: SirenLights
var _burn_left := 0.0
var _skid_timer := 0.0
var _flash := 0.0
var _crash_cooldown := 0.0
var _input_reader := DriveInput.new()


func setup(vehicle_kind: String, sprite := "") -> Vehicle:
	kind = vehicle_kind
	spec = DataDB.vehicle(kind)
	var options: Array = spec.sprites
	sprite_name = sprite if sprite != "" else options[randi() % options.size()]
	hp = float(spec.hp)
	return self


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("vehicles")
	collision_layer = Tuning.LAYER_VEHICLES
	collision_mask = Tuning.LAYER_VEHICLES if spec.get("water", false) else Tuning.MASK_CAR
	if spec.get("water", false):
		hull = BoatHull.new()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	body = Sprite2D.new()
	body.texture = load(spec.get("sprite_dir", CAR_DIR) % sprite_name)
	body.rotation = deg_to_rad(float(spec.get("sprite_angle", 90.0)))  # sprite xe Kenney quay mũi lên trên
	body.scale = Vector2.ONE * Tuning.VEHICLE_SCALE * float(spec.get("scale", 1.0))
	body.material = ShaderMaterial.new()
	body.material.shader = load(Human.FLASH_SHADER)
	add_child(body)
	var tex_size := body.texture.get_size() * body.scale
	size = Vector2(tex_size.y, tex_size.x) if body.rotation != 0.0 else tex_size
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size * 0.92
	add_child(shape)
	var hit_area := Area2D.new()
	hit_area.collision_layer = 0
	hit_area.collision_mask = Tuning.LAYER_ACTORS
	var hit_shape := CollisionShape2D.new()
	hit_shape.shape = RectangleShape2D.new()
	hit_shape.shape.size = size + Vector2(10, 6)
	hit_area.add_child(hit_shape)
	add_child(hit_area)
	hit_area.body_entered.connect(_on_body_touched)
	for side in [-1.0, 1.0]:
		var beam := Sprite2D.new()
		beam.texture = Fx.tex("glow")
		beam.material = Fx.additive()
		beam.modulate = Palette.HEADLIGHT
		beam.scale = Vector2(0.9, 0.4)
		beam.position = Vector2(size.x * 0.5 + 26.0, side * size.y * 0.28)
		beam.add_to_group("headlights")
		add_child(beam)
	if spec.get("siren", false):
		_siren = SirenLights.new()
		add_child(_siren)


func forward() -> Vector2:
	return Vector2.from_angle(rotation)


func forward_speed() -> float:
	return velocity.dot(forward())


func is_player_driven() -> bool:
	return driver is Player


func set_driver(new_driver: Node) -> void:
	driver = new_driver
	if driver:
		autopilot = null
		has_npc_driver = false
		Sfx.play_at("door", global_position)
		_engine = Sfx.make_loop("engine", self, -6.0)
		_engine.play()
		_skid_sound = Sfx.make_loop("skid", self, -10.0)
	else:
		Sfx.play_at("door", global_position)
		for p in [_engine, _skid_sound]:
			if p:
				p.queue_free()
		_engine = null
		_skid_sound = null
		throttle = 0.0
		steer = 0.0
		assist = false
		boost = false


## Đổi sang màu khác trong các sprite của loại xe này (tiệm sơn xe).
func repaint() -> void:
	var options: Array = spec.sprites.filter(func(s: String) -> bool: return s != sprite_name)
	if options.size() > 0:
		sprite_name = options[randi() % options.size()]
		body.texture = load(CAR_DIR % sprite_name)


## Tiệm sửa xe: đầy máu, vá lốp, tắt khói.
func repair() -> void:
	hp = float(spec.hp)
	flat = false
	if _smoke:
		_smoke.queue_free()
		_smoke = null


func pop_tires() -> void:
	if not flat and not wrecked:
		flat = true
		Sfx.play_at("tire_pop", global_position)
		Fx.burst(global_position, "spark", 14, 260.0, 0.4, Color(1, 0.85, 0.5))


## Bấm còi: người đi đường phía trước giật mình tránh xe.
func honk() -> void:
	Sfx.play_at("horn", global_position)
	for p in get_tree().get_nodes_in_group("peds"):
		var to: Vector2 = p.global_position - global_position
		if to.length() < Tuning.HORN_SCARE_RADIUS and to.dot(forward()) > 0.0:
			p.flee(global_position)


func set_siren(on: bool) -> void:
	if _siren:
		_siren.set_active(on)


func _physics_process(delta: float) -> void:
	if driver == null and autopilot == null and not burning and _flash <= 0.0 and stunt.air <= 0.0 and velocity.length_squared() < 4.0:
		velocity = Vector2.ZERO
		return  # xe đỗ / xác xe đứng yên: bỏ qua vật lý (bị tông thì có vận tốc và chạy lại)
	_flash = maxf(_flash - delta / Tuning.FLASH_TIME, 0.0)
	_crash_cooldown -= delta
	body.material.set_shader_parameter("flash", _flash)
	if burning:
		_burn_left -= delta
		if _burn_left <= 0.0:
			_explode()
	if stunt.update(self, delta):
		move_and_slide()
		return
	var kinematic := false
	if wrecked:
		throttle = 0.0
		boost = false
		handbrake = true
	elif autopilot:
		kinematic = autopilot.update(self, delta)
	elif is_player_driven() and driver.controls_enabled and driver.alive:
		_input_reader.read(self)
	else:
		throttle = 0.0
		steer = 0.0
		boost = false
		handbrake = true
	if not kinematic:
		_drive(delta)
	var before := velocity
	var was_at := global_position
	move_and_slide()
	if hull:
		hull.keep_afloat(self, was_at)
		hull.wake(self, delta)
	_check_crashes(before)
	_update_audio(delta)


func _drive(delta: float) -> void:
	var speed := forward_speed()
	var max_speed := float(spec.max_speed)
	var accel := float(spec.accel)
	if nitro.update(self, boost and not burning, delta):
		max_speed *= Tuning.NITRO_SPEED
		accel *= Tuning.NITRO_ACCEL
		throttle = maxf(throttle, 1.0) if throttle >= 0.0 else throttle
	if flat:
		max_speed *= Tuning.FLAT_SPEED
	var full_speed := Tuning.ASSIST_STEER_FULL_SPEED if assist else Tuning.STEER_FULL_SPEED
	var steer_factor := clampf(absf(speed) / full_speed, 0.0, 1.0) * (1.0 - 0.35 * clampf(absf(speed) / max_speed, 0.0, 1.0))
	var turn := float(spec.turn) * (Tuning.ASSIST_TURN_SCALE if assist else 1.0)
	rotation += steer * turn * steer_factor * signf(speed) * delta
	var fwd := forward()
	var side := fwd.rotated(PI * 0.5)
	speed = velocity.dot(fwd)
	var lateral := velocity.dot(side)
	if throttle > 0.0:
		speed = minf(speed + accel * throttle * delta, maxf(max_speed, speed)) if speed >= 0.0 else speed + float(spec.brake) * delta
	elif throttle < 0.0:
		if speed > 20.0:
			speed -= float(spec.brake) * -throttle * delta
		else:
			speed = maxf(speed - accel * 0.6 * delta, -float(spec.reverse))
	else:
		speed = move_toward(speed, 0.0, (Tuning.ASSIST_DRAG if assist else Tuning.VEHICLE_DRAG) * delta)
	if speed > max_speed:  # hết nitro / thủng lốp: hụt tốc dần, không phanh gấp
		speed = move_toward(speed, max_speed, Tuning.OVERSPEED_DRAG * delta)
	var grip := float(spec.grip) * (Tuning.FLAT_GRIP if flat else 1.0) * lerpf(1.0, Tuning.RAIN_GRIP, Weather.wet)
	if handbrake:
		grip = Tuning.HANDBRAKE_GRIP
		speed = move_toward(speed, 0.0, float(spec.brake) * 0.35 * delta)
	elif absf(steer) > 0.5 and absf(speed) > max_speed * 0.65:
		grip = Tuning.DRIFT_GRIP
	lateral = lerpf(lateral, 0.0, minf(grip * delta, 1.0))
	velocity = fwd * speed + side * lateral
	_skid_timer -= delta
	var skidding := absf(lateral) > Tuning.DRIFT_MIN_LATERAL and hull == null
	if skidding and _skid_timer <= 0.0:
		_skid_timer = Tuning.SKID_EVERY
		_leave_skid(side)
	if _skid_sound:
		if skidding and not _skid_sound.playing:
			_skid_sound.play()
		elif not skidding and _skid_sound.playing:
			_skid_sound.stop()


func _leave_skid(side: Vector2) -> void:
	if Fx.root == null:
		return
	for s in [-1.0, 1.0]:
		var mark := Sprite2D.new()
		mark.texture = load(SKID_TEX)
		mark.global_position = global_position - forward() * size.x * 0.35 + side * s * size.y * 0.32
		mark.rotation = rotation + PI * 0.5
		mark.scale = Vector2(0.35, 0.25)
		mark.modulate = Color(1, 1, 1, 0.5)
		mark.z_index = -16
		Fx.root.add_child(mark)
		var t := mark.create_tween()
		t.tween_interval(Tuning.SKID_LIFE)
		t.tween_property(mark, "modulate:a", 0.0, 1.0)
		t.tween_callback(mark.queue_free)


## Chỉ cú đâm mới gây sát thương (có thời gian hồi), trượt dọc tường thì không.
## Bỏ phần vận tốc hướng vào vật cản: move_and_slide giữ nguyên vận tốc khi tì vào xe khác,
## nên xe đứng yên vẫn "đâm" ở tốc độ tối đa sau mỗi lần hồi và tự nổ.
func _check_crashes(before: Vector2) -> void:
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		velocity -= n * minf(velocity.dot(n), 0.0)
	if _crash_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var impact := -before.dot(c.get_normal())
		if impact < Tuning.CRASH_MIN_SPEED:
			continue
		_crash_cooldown = Tuning.CRASH_COOLDOWN
		velocity += c.get_normal() * impact * Tuning.CRASH_BOUNCE
		var damage := (impact - Tuning.CRASH_MIN_SPEED) * Tuning.CRASH_DAMAGE_PER_SPEED + 4.0
		take_hit(damage * _crash_scale(), c.get_normal(), driver)
		var other := c.get_collider()
		if other is Vehicle:
			other.take_hit(damage * other._crash_scale() * float(spec.get("ram", 1.0)), -c.get_normal(), driver if driver else self)
			other.velocity += before * 0.35
		Sfx.play_at("crash", c.get_position(), clampf((impact - 300.0) / 40.0, -12.0, 0.0))
		Fx.impact(c.get_position())
		if is_player_driven():
			Fx.shake(impact / 60.0)


func _crash_scale() -> float:
	return Tuning.PLAYER_CRASH_SCALE if is_player_driven() else 1.0


func _on_body_touched(other: Node) -> void:
	if stunt.air > 0.0:  # đang bay qua đầu người
		return
	var speed := velocity.length()
	if other is Human and other != driver and speed > Tuning.RUNOVER_SPEED and not wrecked:
		other.knock_down(velocity * 0.6, speed * Tuning.RUNOVER_DAMAGE_PER_SPEED, driver if driver else self)


func take_hit(amount: float, _dir: Vector2, source: Variant, _knockback := 0.0) -> void:
	if wrecked:
		return
	if source is Npc:
		if has_npc_driver:  # đạn NPC không phá xe do NPC lái (tránh chuỗi xe cảnh sát tự nổ quanh người chơi)
			return
		if is_player_driven():
			amount *= Tuning.PLAYER_VEHICLE_BULLET_SCALE  # xe Jay lái chịu đạn NPC nhẹ hơn: truy đuổi vẫn thoát được
	hp -= amount
	_flash = 0.6
	if Combat.source_or_null(source):
		last_attacker = source
	if hp < float(spec.hp) * Tuning.VEHICLE_SMOKE_RATIO and _smoke == null:
		_smoke = Fx.burst(Vector2.ZERO, "smoke", 12, 40.0, 1.2, Color(0.3, 0.3, 0.32, 0.7), false)
		_smoke.reparent(self, false)
		_smoke.one_shot = false
		_smoke.explosiveness = 0.0
		_smoke.local_coords = false
	if hp <= 0.0 and not burning:
		burning = true
		_burn_left = Tuning.VEHICLE_BURN_TIME
		if _smoke:
			_smoke.texture = Fx.tex("flame")
			_smoke.color = Color(1.0, 0.55, 0.2)
			_smoke.material = Fx.additive()
			_smoke.amount = 24
		if is_player_driven():
			Game.notice.emit(tr("NOTICE_VEHICLE_FIRE"))
			driver.exit_vehicle()


func _explode() -> void:
	burning = false
	wrecked = true
	set_siren(false)
	autopilot = null
	if _smoke:
		_smoke.emitting = false
	body.modulate = Color(0.25, 0.23, 0.22)
	Combat.explode(self, global_position, Tuning.VEHICLE_EXPLOSION_DAMAGE, Tuning.VEHICLE_EXPLOSION_RADIUS, Combat.source_or_null(last_attacker))
	destroyed.emit(self)
	var t := create_tween()
	t.tween_interval(Tuning.WRECK_TIME)
	t.tween_property(self, "modulate:a", 0.0, 1.5)
	t.tween_callback(queue_free)


func _update_audio(_delta: float) -> void:
	if _engine:
		var ratio := clampf(absf(forward_speed()) / float(spec.max_speed), 0.0, 1.0)
		_engine.pitch_scale = float(spec.engine_pitch) * (0.8 + ratio * 1.2)


## Điểm xuống xe: bên trái, nếu vướng thì bên phải, rồi phía sau.
func exit_point() -> Vector2:
	var side := forward().rotated(-PI * 0.5)
	var space := get_world_2d().direct_space_state
	for offset in [side * (size.y * 0.5 + 22.0), -side * (size.y * 0.5 + 22.0), -forward() * (size.x * 0.5 + 22.0)]:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = global_position + offset
		q.collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_VEHICLES | Tuning.LAYER_WATER
		if space.intersect_point(q).is_empty():
			return q.position
	return global_position + forward() * (size.x * 0.5 + 22.0)
