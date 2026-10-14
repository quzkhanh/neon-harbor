shader_type canvas_item;
// Kéo màu tile về màu nhuộm của ô (modulate) mà vẫn giữ nét vẽ: tường và mái nhà nổi khối (BuildingDepth).
uniform float amount : hint_range(0.0, 1.0) = 0.5;
varying vec4 tint;

void vertex() {
	tint = COLOR;  // modulate của ô; trong fragment() COLOR đã nhân sẵn texture
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(t.rgb, tint.rgb, amount), t.a * tint.a);
}
