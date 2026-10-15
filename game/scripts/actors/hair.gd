class_name Hair
extends Node2D
## Tóc hoặc mũ vẽ bằng code đè lên đầu: sprite Kenney nhìn từ trên xuống chỉ có vòng tròn màu da nên trông như hói.
## Là con của `body` nên xoay, nhún và ngã theo thân; mặt hướng +x. Có material riêng (cùng shader chớp màu) để tóc cũng chớp khi trúng đòn.

const STYLES := ["short", "buzz", "long", "bun", "cap", "beanie", "bald"]
const BARE_HEADS := ["hitman1", "manBrown", "womanGreen"]  # skin có đầu trần; các skin khác đã có mũ/tóc trong sprite
const NATURAL_COLORS := 5  # mấy màu đầu của Palette.HAIR là màu tóc tự nhiên; còn lại là màu nhuộm/mũ
const HEAD_R := Vector2(9.0, 9.6)  # bán kính đầu trong sprite

var style: String
var color: Color


func _init(hair_style: String, hair_color: Color) -> void:
	style = hair_style
	color = hair_color
	material = ShaderMaterial.new()
	material.shader = load(Human.FLASH_SHADER)


## Chọn kiểu và màu cho người đi đường: [kiểu, chỉ số màu]. Mũ luôn lấy màu nhuộm cho dễ thấy.
static func roll() -> Array:
	var s: String = STYLES.pick_random()
	var hat := s == "cap" or s == "beanie"
	return [s, randi_range(NATURAL_COLORS if hat else 0, Palette.HAIR.size() - 1)]


func sync_flash(from: ShaderMaterial) -> void:
	for p in ["flash", "flash_color"]:
		material.set_shader_parameter(p, from.get_shader_parameter(p))


func _ready() -> void:
	z_index = 1


func _draw() -> void:
	match style:
		"short":
			Shapes.oval(self, Vector2(-1.4, 0), HEAD_R.x - 0.4, HEAD_R.y - 0.3, color)
		"buzz":
			Shapes.oval(self, Vector2(-0.6, 0), HEAD_R.x, HEAD_R.y, Color(color, 0.6), 0.0, false)
		"long":
			Shapes.oval(self, Vector2(-11, 0), 5.0, 3.6, color)
			Shapes.oval(self, Vector2(-4, 0), HEAD_R.x, HEAD_R.y + 1.2, color)
		"bun":
			Shapes.oval(self, Vector2(-8, 0), 3.2, 3.2, color)
			Shapes.oval(self, Vector2(-1.4, 0), HEAD_R.x - 0.4, HEAD_R.y - 0.3, color)
		"cap":
			Shapes.polygon(self, PackedVector2Array([Vector2(6, -6), Vector2(13, -4.5), Vector2(13, 4.5), Vector2(6, 6)]), color.darkened(0.25))
			Shapes.oval(self, Vector2(-0.5, 0), HEAD_R.x + 0.4, HEAD_R.y + 0.4, color)
		"beanie":
			Shapes.oval(self, Vector2(-0.5, 0), HEAD_R.x + 0.6, HEAD_R.y + 0.6, color)
			Shapes.oval(self, Vector2(-0.5, 0), 5.0, 5.4, color.lightened(0.15))
			Shapes.oval(self, Vector2(-0.5, 0), 2.2, 2.2, color.lightened(0.3))
