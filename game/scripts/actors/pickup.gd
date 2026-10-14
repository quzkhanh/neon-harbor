class_name Pickup
extends Area2D
## Vật nhặt được (tiền rơi, vali nhiệm vụ). Chỉ người chơi nhặt.

signal collected

const ITEM_DIR := "res://assets/sprites/items/%s.png"
const RADIUS := 26.0
const LIFETIME := 30.0

var _time := 0.0
var _sprite: Sprite2D
var _expires := true


static func spawn_cash(parent: Node, pos: Vector2, value: int) -> Pickup:
	var p := make(parent, pos, "cash")
	p.collected.connect(func() -> void:
		Game.add_money(value)
		Sfx.play("cash"))
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
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * 4.0) * 3.0
	_sprite.rotation = sin(_time * 2.0) * 0.15
	if _expires and _time > LIFETIME:
		queue_free()


func _on_body(body: Node) -> void:
	if body is Player and body.alive:
		collected.emit()
		queue_free()
