class_name BoatHull
extends RefCounted
## Thuyền (xe có "water" trong dữ liệu): chỉ chạy trên ô nước. Mũi thuyền chạm bờ thì lùi về chỗ cũ và dội ngược;
## chạy nhanh để lại vệt bọt sau đuôi.

const WAKE_EVERY := 0.07
const WAKE_SPEED := 90.0
const BOUNCE := 0.3

var _wake := 0.0


## Gọi sau move_and_slide với vị trí trước khi di chuyển.
func keep_afloat(v: Vehicle, before: Vector2) -> void:
	if Vehicle.map == null:
		return
	var bow := v.global_position + v.velocity.normalized() * v.size.x * 0.5
	if Vehicle.map.at(MapData.world_to_cell(bow)) != "~" or Vehicle.map.at(MapData.world_to_cell(v.global_position)) != "~":
		v.global_position = before
		v.velocity = -v.velocity * BOUNCE


func wake(v: Vehicle, delta: float) -> void:
	_wake -= delta
	if _wake <= 0.0 and v.velocity.length() > WAKE_SPEED and Fx.root:
		_wake = WAKE_EVERY
		Fx.burst(v.global_position - v.forward() * v.size.x * 0.5, "smoke", 3, 40.0, 0.9, Palette.WAKE, false).z_index = -14
