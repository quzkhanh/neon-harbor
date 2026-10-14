class_name DistrictBanner
extends Label
## Tên khu hiện to giữa màn hình một lúc khi người chơi đi vào khu mới.

const CHECK_EVERY := 0.5
const FADE := 0.4
const HOLD := 2.2
const TOP := 120.0

var city: City
var _current := ""
var _timer := 0.0


func _init(c: City) -> void:
	city = c
	theme_type_variation = "BannerLabel"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = TOP
	modulate.a = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	var key := DataDB.district_at(MapData.world_to_cell(city.player.global_position))
	if key == _current or key == "":
		return
	_current = key
	text = key
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, FADE)
	t.tween_interval(HOLD)
	t.tween_property(self, "modulate:a", 0.0, FADE)
