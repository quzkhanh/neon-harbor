class_name Helicopter
extends CharacterBody2D
## Trực thăng cảnh sát (5 sao): bay theo người chơi, rọi đèn xuống đất; chỉ "thấy" người chơi trong vòng đèn rọi.
## Bắn từng loạt từ trên cao (không bị tường chắn). Bắn rơi được: lớp va chạm riêng, không cản người hay xe.

signal downed

const BODY := "res://assets/sprites/world/heli.png"
const ROTOR := "res://assets/sprites/world/rotor.png"
const ALTITUDE := Vector2(-70, -110)  # vị trí node là điểm mặt đất dưới trực thăng (tâm đèn rọi); thân vẽ lệch lên trên
const SHADOW_OFFSET := Vector2(50, 70)
const ROTOR_SPEED := 28.0
const SHOT_GAP := 0.12
const AIM_ERROR := 40.0
const RADIUS := 46.0
const TURN_RATE := 2.5

var city: City
var hp := Tuning.HELI_HP
var leaving := false
var _rotor: Sprite2D
var _shadow: Sprite2D
var _spot: Sprite2D
var _body: Sprite2D
var _fire_cd := Tuning.HELI_FIRE_EVERY
var _burst_left := 0
var _shot_cd := 0.0
var _flash := 0.0
var _down := false


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("helicopters")
	collision_layer = Tuning.LAYER_AIR
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	shape.position = ALTITUDE
	add_child(shape)
	_spot = _sprite(Fx.tex("glow"), 19)
	_spot.material = Fx.additive()
	_spot.modulate = Palette.HELI_SPOT
	_spot.scale = Vector2.ONE * Tuning.HELI_SPOT_RADIUS / 64.0  # glow.png 128 px
	_shadow = _sprite(load(BODY), -15)
	_shadow.modulate = Palette.GROUND_SHADOW
	_shadow.position = SHADOW_OFFSET
	_body = _sprite(load(BODY), 40)
	_body.position = ALTITUDE
	_body.material = ShaderMaterial.new()
	_body.material.shader = load(Human.FLASH_SHADER)
	_rotor = _sprite(load(ROTOR), 41)
	_rotor.position = ALTITUDE
	Sfx.make_loop("heli", self, -2.0).play()


func _sprite(tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.z_as_relative = false
	s.z_index = z
	add_child(s)
	return s


func target() -> Node2D:
	var p := city.player
	return p.vehicle if p.vehicle else p


func sees_player() -> bool:
	return not _down and not leaving and city.player.alive and target().global_position.distance_to(global_position) < Tuning.HELI_SPOT_RADIUS


func leave() -> void:
	leaving = true


func _physics_process(delta: float) -> void:
	_rotor.rotation += ROTOR_SPEED * delta
	_flash = maxf(_flash - delta / Tuning.FLASH_TIME, 0.0)
	_body.material.set_shader_parameter("flash", _flash)
	if _down:
		return
	var goal := target().global_position
	if leaving:
		var away := global_position - goal
		goal = global_position + (away.normalized() if away.length() > 1.0 else Vector2.UP) * 1000.0
		if not city.view_rect().grow(400.0).has_point(global_position):
			queue_free()
			return
	var step := goal - global_position
	if step.length() > 1.0:
		_body.rotation = lerp_angle(_body.rotation, step.angle(), minf(TURN_RATE * delta, 1.0))
		_shadow.rotation = _body.rotation
	global_position = global_position.move_toward(goal, Tuning.HELI_SPEED * delta)
	_shoot(delta)


func _shoot(delta: float) -> void:
	if _burst_left > 0:
		_shot_cd -= delta
		if _shot_cd <= 0.0:
			_shot_cd = SHOT_GAP
			_burst_left -= 1
			_fire_once()
		return
	if sees_player():
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = Tuning.HELI_FIRE_EVERY
			_burst_left = Tuning.HELI_BURST


func _fire_once() -> void:
	var t := target()
	var aim := t.global_position + Vector2(randf_range(-AIM_ERROR, AIM_ERROR), randf_range(-AIM_ERROR, AIM_ERROR))
	Fx.tracer(global_position + ALTITUDE, aim)
	Sfx.play_at("rifle", global_position, -4.0)
	if randf() < Tuning.HELI_HIT_CHANCE and city.player.alive:
		t.take_hit(Tuning.HELI_DAMAGE, aim - global_position, self, 30.0)


func take_hit(amount: float, _dir: Vector2, source: Variant, _knockback := 0.0) -> void:
	if _down or (is_instance_valid(source) and source is Node and source.is_in_group("cops")):  # cảnh sát không bắn nhầm
		return
	hp -= amount
	_flash = 0.7
	if hp <= 0.0:
		_crash(Combat.source_or_null(source))


func _crash(source: Node) -> void:
	_down = true
	collision_layer = 0
	remove_from_group("damageable")
	if source is Player:
		Game.add_heat(Tuning.HELI_HEAT)
	Game.notice.emit(tr("NOTICE_HELI_DOWN"))
	Fx.explosion(global_position + ALTITUDE, 150.0)
	Sfx.play_at("explosion", global_position)
	Fx.shake(8.0)
	_spot.visible = false
	downed.emit()
	var t := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_property(_body, "scale", Vector2.ONE * 0.55, 1.2)
	t.tween_property(_body, "rotation", _body.rotation + 6.0, 1.2)
	t.tween_property(_body, "position", Vector2.ZERO, 1.2)
	t.tween_property(_rotor, "position", Vector2.ZERO, 1.2)
	t.tween_property(_shadow, "position", Vector2.ZERO, 1.2)
	t.tween_property(_rotor, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(func() -> void: Combat.explode(self, global_position + ALTITUDE * 0.4, Tuning.VEHICLE_EXPLOSION_DAMAGE, Tuning.VEHICLE_EXPLOSION_RADIUS, source))
	t.chain().tween_property(self, "modulate:a", 0.0, 1.5)
	t.chain().tween_callback(queue_free)
