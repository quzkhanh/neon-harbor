class_name SignPost
extends Node2D
## Biển hiệu tĩnh trước cửa cửa hàng, bệnh viện, gara (chữ là khoá dịch); hiện trên minimap.

const PAD := Vector2(14, 6)

var color := Palette.CYAN
var icon := MapIcon.Kind.SHOP


static func make(parent: Node, pos: Vector2, sign_color: Color, key: String, map_icon: MapIcon.Kind) -> SignPost:
	var s := SignPost.new()
	s.color = sign_color
	s.icon = map_icon
	s.global_position = pos
	s.z_index = 22
	var panel := PanelContainer.new()
	var style := UiTheme.box(Color(Palette.BG, 0.85), 8, 2, sign_color)
	style.content_margin_left = PAD.x
	style.content_margin_right = PAD.x
	style.content_margin_top = PAD.y
	style.content_margin_bottom = PAD.y
	style.shadow_color = Color(sign_color, 0.35)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	var label := Ui.label(key, "WorldLabel")
	label.add_theme_color_override("font_color", sign_color)
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	s.add_child(panel)
	panel.resized.connect(func() -> void: panel.position = Vector2(-panel.size.x * 0.5, -Tuning.TILE * 0.5 - panel.size.y))
	parent.add_child(s)
	return s


func _ready() -> void:
	add_to_group("markers")
	var glow := Sprite2D.new()
	glow.texture = Fx.tex("glow")
	glow.material = Fx.additive()
	glow.modulate = Color(color, 0.35)
	glow.position = Vector2(0, -Tuning.TILE * 0.5)
	glow.scale = Vector2(1.6, 0.8)
	add_child(glow)
