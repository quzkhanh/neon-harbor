class_name Ramps
extends Node2D
## Dốc nhảy trên các đoạn đường thẳng (data/extras.json): xe lao lên đúng hướng, đủ nhanh thì bay (Stunt).

const TEX := "res://assets/sprites/world/ramp.png"


func _ready() -> void:
	name = "Ramps"
	z_index = -12
	var ramps: Array = DataDB.extras().ramps
	for i in ramps.size():
		var r: Array = ramps[i]
		var dir := Vector2(float(r[2]), float(r[3]))
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = Tuning.LAYER_VEHICLES
		area.position = MapData.cell_center(Vector2i(int(r[0]), int(r[1])))
		area.rotation = dir.angle()
		var sprite := Sprite2D.new()
		sprite.texture = load(TEX)
		area.add_child(sprite)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(Tuning.TILE * 0.5, Tuning.TILE * 0.9)
		area.add_child(shape)
		area.body_entered.connect(_on_enter.bind(i, dir))
		add_child(area)


func _on_enter(body: Node, index: int, dir: Vector2) -> void:
	if body is Vehicle and body.velocity.dot(dir) > Tuning.RAMP_MIN_SPEED:
		body.stunt.launch.call_deferred(body, index)  # đang trong callback va chạm: không đổi lớp va chạm ngay
