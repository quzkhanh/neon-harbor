class_name MotoRider
extends Sprite2D
## Người ngồi trên xe máy (tư thế "hold": hai tay nắm ghi đông): Jay khi tự lái, hoặc người lái xe máy tự chạy.
## Jay bị ẩn khi lên xe nên nếu không vẽ riêng thì xe máy trông như chạy không người.

const SCALE := 0.95
const SEAT := Vector2(-4, 0)  # lùi nhẹ so với tâm xe

var _vehicle: Vehicle
var _npc_skin: String = Pedestrian.SKINS[randi() % Pedestrian.SKINS.size()]
var _skin := ""


func _init(v: Vehicle) -> void:
	_vehicle = v
	scale = Vector2.ONE * SCALE
	position = SEAT
	z_index = 1
	visible = false


func _process(_delta: float) -> void:
	var player_riding := _vehicle.is_player_driven()
	visible = not _vehicle.wrecked and (player_riding or _vehicle.autopilot != null)
	if not visible:
		return
	var skin: String = Game.skin if player_riding else _npc_skin
	if skin != _skin:
		_skin = skin
		texture = load(Human.CHAR_DIR % [skin, "hold"])
