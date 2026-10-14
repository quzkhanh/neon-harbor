class_name Backdrop
extends Node2D
## Nền menu/màn kết: bản đồ thành phố thật, camera lướt chậm, phủ tối nhẹ.

const PAN_SPEED := 26.0
const ZOOM := 0.7

var _camera: Camera2D
var _from: Vector2
var _to: Vector2
var _t := 0.0


func _ready() -> void:
	var map := CityMap.new()
	add_child(map)
	map.build()
	var tint := CanvasModulate.new()
	tint.color = Palette.NIGHT_TINT.darkened(0.25)
	add_child(tint)
	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * ZOOM
	add_child(_camera)
	_camera.make_current()
	var rect := map.data.world_rect()
	_from = rect.get_center() + Vector2(-rect.size.x * 0.25, -rect.size.y * 0.15)
	_to = rect.get_center() + Vector2(rect.size.x * 0.25, rect.size.y * 0.15)
	_camera.global_position = _from


func _process(delta: float) -> void:
	_t += delta * PAN_SPEED / _from.distance_to(_to)
	_camera.global_position = _from.lerp(_to, 0.5 - 0.5 * cos(_t * PI))
