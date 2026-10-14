class_name Pickup
extends Area2D
## Vật nhặt được (tiền, hộp máu, áo giáp, vali nhiệm vụ). Chỉ người chơi nhặt, và chỉ khi `can_take` cho phép
## (đầy máu thì không nhặt hộp máu); đứng sẵn trên đó rồi mới cần thì vẫn nhặt được.

signal collected

const ITEM_DIR := "res://assets/sprites/items/%s.png"
const RADIUS := 26.0
const LIFETIME := 30.0

var _time := 0.0
var _sprite: Sprite2D
var _expires := true
var can_take := func() -> bool: return true


static func spawn_cash(parent: Node, pos: Vector2, value: int) -> Pickup:
	var p := make(parent, pos, "cash")
	p.collected.connect(func() -> void:
		Game.add_money(value)
		Sfx.play("cash"))
	return p


static func spawn_health(parent: Node, pos: Vector2, amount: float, expires := true) -> Pickup:
	var p := make(parent, pos, "medkit", expires)
	p.can_take = func() -> bool: return Game.health < Tuning.MAX_HEALTH
	p.collected.connect(func() -> void:
		Game.heal(amount)
		Sfx.play("pickup"))
	return p


static func spawn_armor(parent: Node, pos: Vector2, amount: float, expires := true) -> Pickup:
	var p := make(parent, pos, "armor_vest", expires)
	p.can_take = func() -> bool: return Game.armor < Tuning.MAX_ARMOR
	p.collected.connect(func() -> void:
		Game.add_armor(amount)
		Sfx.play("pickup"))
	return p


static func make(parent: Node, pos: Vector2, item: String, expires := true) -> Pickup:
	var p := Pickup.new()
	p._expires = expires
	p.global_position = pos
	p._sprite = Sprite2D.new()
	p._sprite.texture = load(ITEM_DIR % item)
	p.add_child(p._sprite)
	var glow := Sprite2D.new()
	glow.texture = Fx.tex("glow")
	glow.material = Fx.additive()
	glow.modulate = Color(Palette.GOLD, 0.35)
	glow.scale = Vector2.ONE * 0.6
	glow.show_behind_parent = true
	p.add_child(glow)
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = Tuning.LAYER_PICKUPS
	collision_mask = Tuning.LAYER_ACTORS
	z_index = 2
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = RADIUS
	add_child(shape)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 4.0) * 3.0
	_sprite.rotation = sin(_time * 2.0) * 0.15
	if _expires and _time > LIFETIME:
		queue_free()
		return
	for body in get_overlapping_bodies():
		if body is Player and body.alive and can_take.call():
			collected.emit()
			queue_free()
			return
