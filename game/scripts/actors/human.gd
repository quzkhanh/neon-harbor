class_name Human
extends CharacterBody2D
## Cơ sở cho mọi người trong game (người chơi, người đi đường, cảnh sát, băng đảng):
## sprite theo tư thế, máu, đẩy lùi, chớp khi trúng, cháy, ngã, chết.

signal died(human: Human)

const CHAR_DIR := "res://assets/vendor/chars/%s_%s.png"
const BODY_PIVOT := Vector2(15, 21.5)
const MUZZLE := {"gun": Vector2(34, 9.5), "machine": Vector2(34, 9.5), "silencer": Vector2(39, 9.5), "hold": Vector2(20, 12)}
const FLASH_SHADER := "res://assets/shaders/flash.gdshader"
const BURN_COLOR := Color(1.0, 0.55, 0.15)
const LUNGE_TIME := 0.14
const LUNGE_DIST := 9.0
const STAGGER_TIME := 0.35
const STAGGER_SLOW := 0.25  # tốc độ còn lại khi đang lảo đảo
const STAGGER_DEG := 22.0

var skin := "manBrown"
var pose := "stand"
var max_health := Tuning.PED_HEALTH
var health := Tuning.PED_HEALTH
var alive := true
var knocked := 0.0
var knock_velocity := Vector2.ZERO
var facing := 0.0

var body: Sprite2D
var _flash := 0.0
var _burn := 0.0
var _burn_source: Node
var _walk_phase := 0.0
var _lunge := 0.0
var _stagger := 0.0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("humans")
	collision_layer = Tuning.LAYER_ACTORS
	collision_mask = Tuning.MASK_HUMAN
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = Tuning.HUMAN_RADIUS
	add_child(shape)
	body = Sprite2D.new()
	body.centered = false
	body.offset = -BODY_PIVOT
	body.material = ShaderMaterial.new()
	body.material.shader = load(FLASH_SHADER)
	add_child(body)
	health = max_health
	set_pose(pose)


func set_pose(new_pose: String) -> void:
	pose = new_pose
	body.texture = load(CHAR_DIR % [skin, pose])


func muzzle_position() -> Vector2:
	return global_position + MUZZLE.get(pose, MUZZLE["gun"]).rotated(facing)


## Di chuyển với vận tốc mong muốn + đà đẩy lùi; cập nhật dáng đi.
func move(desired: Vector2, delta: float) -> void:
	knock_velocity = knock_velocity.lerp(Vector2.ZERO, minf(Tuning.KNOCKBACK_DAMP * delta, 1.0))
	if knocked > 0.0:
		knocked -= delta
		desired = Vector2.ZERO
	if _stagger > 0.0:
		_stagger -= delta
		desired *= STAGGER_SLOW
	velocity = desired + knock_velocity
	var before := global_position
	move_and_slide()
	# Đẩy lùi mạnh có thể ép người lọt qua khe giữa các ô tường; lọt vào ô nhà thì trả về chỗ cũ.
	if Vehicle.map and Vehicle.map.at(MapData.world_to_cell(global_position)) == "#" and Vehicle.map.at(MapData.world_to_cell(before)) != "#":
		global_position = before
		knock_velocity = Vector2.ZERO
	_animate(delta, desired.length())


func face(angle: float) -> void:
	facing = angle
	rotation = 0.0
	body.rotation = facing


func _animate(delta: float, speed: float) -> void:
	_flash = maxf(_flash - delta / Tuning.FLASH_TIME, 0.0)
	var burn_pulse := 0.0
	if _burn > 0.0:
		_burn -= delta
		burn_pulse = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
		_apply_damage(Tuning.BURN_DPS * delta, Vector2.ZERO, Combat.source_or_null(_burn_source))
	body.material.set_shader_parameter("flash", maxf(_flash, burn_pulse))
	body.material.set_shader_parameter("flash_color", Palette.HIT_FLASH if _flash > burn_pulse else BURN_COLOR)
	if not alive or knocked > 0.0:
		return
	var moving := clampf(speed / Tuning.WALK_SPEED, 0.0, 1.0)
	_walk_phase += delta * Tuning.BOB_FREQ * moving
	var bob := absf(sin(_walk_phase)) * Tuning.BOB_SCALE * moving
	body.scale = Vector2(1.0 + bob, 1.0 - bob * 0.5)
	var wobble := deg_to_rad(STAGGER_DEG) * sin(_stagger * 40.0) * _stagger / STAGGER_TIME
	body.rotation = facing + deg_to_rad(Tuning.SWAY_DEG) * sin(_walk_phase) * moving + wobble
	_lunge = maxf(_lunge - delta, 0.0)
	body.position = Vector2.from_angle(facing) * LUNGE_DIST * sin(PI * _lunge / LUNGE_TIME)


## Nhoài người theo hướng đang quay mặt rồi giật về (cú đánh cận chiến).
func lunge() -> void:
	_lunge = LUNGE_TIME


## Trúng đòn cận chiến: lắc lư, gần như đứng khựng một lúc.
func stagger() -> void:
	_stagger = STAGGER_TIME


func take_hit(amount: float, dir: Vector2, source: Variant, knockback := 0.0) -> void:
	if not alive:
		return
	source = Combat.source_or_null(source)
	_flash = 1.0
	knock_velocity += dir.normalized() * knockback
	Fx.blood_spray(global_position, dir)
	_apply_damage(amount, dir, source)


func ignite(source: Node) -> void:
	if alive:
		_burn = Tuning.BURN_TIME
		_burn_source = source


## Bị xe đâm: ngã một lúc rồi mới dậy.
func knock_down(dir: Vector2, damage: float, source: Variant) -> void:
	if not alive:
		return
	knocked = Tuning.KNOCKDOWN_TIME
	body.rotation = facing + PI * 0.5
	take_hit(damage, dir, source, dir.length())


func _apply_damage(amount: float, dir: Vector2, source: Node) -> void:
	health -= amount
	_on_damaged(amount, source)
	if health <= 0.0 and alive:
		alive = false
		_burn = 0.0
		_die(dir, source)


## Ghi đè ở lớp con (báo tội, phản ứng...).
func _on_damaged(_amount: float, _source: Node) -> void:
	pass


## Xác: tối màu, ngã nghiêng và trượt theo hướng trúng đòn, vũng máu loang dần
## (người bị xe tông ngã thì không có máu và tự đứng dậy).
func _die(dir: Vector2, _source: Node) -> void:
	collision_layer = 0
	collision_mask = 0
	z_index = -1
	set_pose("stand")
	body.modulate = Palette.CORPSE
	body.scale = Vector2.ONE
	var slide := dir.normalized() * Tuning.CORPSE_SLIDE
	Fx.blood_pool(global_position + slide)
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "rotation", facing + PI * 0.5 * signf(dir.x + 0.01), 0.25)
	tween.tween_property(body, "position", slide, 0.25).set_ease(Tween.EASE_OUT)
	died.emit(self)
