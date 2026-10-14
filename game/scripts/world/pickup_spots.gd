class_name PickupSpots
extends Node
## Hộp máu ("h") và áo giáp ("a") cố định trên bản đồ; nhặt rồi thì một lúc sau mới có lại.

var city: City


func _init(c: City) -> void:
	city = c
	name = "PickupSpots"


func _ready() -> void:
	for cell in city.data.find_all("h"):
		_spawn(MapData.cell_center(cell), true)
	for cell in city.data.find_all("a"):
		_spawn(MapData.cell_center(cell), false)


func _spawn(pos: Vector2, health: bool) -> void:
	var p := Pickup.spawn_health(city.effects, pos, Tuning.MEDKIT_PICKUP, false) if health \
		else Pickup.spawn_armor(city.effects, pos, Tuning.ARMOR_PICKUP, false)
	p.collected.connect(func() -> void:
		get_tree().create_timer(Tuning.PICKUP_RESPAWN).timeout.connect(_spawn.bind(pos, health)))
