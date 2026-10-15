class_name SpikeStrip
extends Area2D
## Dải đinh của rào chắn: xe chạy qua thì thủng lốp (Vehicle.pop_tires).

const TEX := "res://assets/sprites/world/spikes.png"


static func make(parent: Node, pos: Vector2, angle: float, width: float) -> SpikeStrip:
	var s := SpikeStrip.new()
	s.global_position = pos
	s.rotation = angle
	var sprite := Sprite2D.new()
	sprite.texture = load(TEX)
	sprite.scale = Vector2(width / sprite.texture.get_width(), 1.5)
	s.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, sprite.texture.get_height())
	s.add_child(shape)
	parent.add_child(s)
	return s


func _ready() -> void:
	collision_layer = 0
	collision_mask = Tuning.LAYER_VEHICLES
	z_index = -10
	body_entered.connect(func(body: Node) -> void:
		if body is Vehicle:
			body.pop_tires())
