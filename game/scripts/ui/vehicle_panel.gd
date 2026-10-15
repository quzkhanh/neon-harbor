class_name VehiclePanel
extends PanelContainer
## Thẻ xe trên HUD (chỉ hiện khi lái): máu xe và bình nitro.

const ICON_DIR := "res://assets/sprites/ui/%s.png"

var city: City
var _hp: ProgressBar
var _nitro: ProgressBar


func _init(c: City) -> void:
	city = c
	name = "VehiclePanel"
	theme_type_variation = "HudPanel"
	size_flags_horizontal = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Ui.vbox(6)
	add_child(box)
	_hp = _row(box, "icon_car", "HealthBar")
	_nitro = _row(box, "icon_nitro", "StatBar")


func _row(box: Control, icon: String, variation: String) -> ProgressBar:
	var row := Ui.hbox(8)
	row.add_child(Ui.texture(ICON_DIR % icon, Vector2(26, 26)))
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	box.add_child(row)
	return bar


func _process(_delta: float) -> void:
	var v := city.player.vehicle
	visible = v != null
	if v:
		_hp.value = clampf(v.hp / float(v.spec.hp), 0.0, 1.0)
		_nitro.value = v.nitro.fuel
		_nitro.modulate.a = 1.0 if v.nitro.fuel >= Tuning.NITRO_REARM or v.nitro.active else 0.5
