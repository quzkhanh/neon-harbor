shader_type canvas_item;
// Chớp màu khi trúng đòn hoặc đang cháy. Thêm biến thể trang phục: xoay sắc độ phần quần áo có màu, nhuộm phần
// quần áo xám/đen; giữ nguyên tông da để mặt không đổi màu.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outfit_tint : source_color = vec4(1.0);
uniform float outfit_mix : hint_range(0.0, 1.0) = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (hue_shift > 0.0 || outfit_mix > 0.0) {
		vec3 hsv = rgb2hsv(c.rgb);
		bool skin = hsv.x > 0.06 && hsv.x < 0.16 && hsv.y > 0.2 && hsv.y < 0.75 && hsv.z > 0.45;
		if (!skin) {
			if (hsv.y < 0.18) {
				c.rgb = mix(c.rgb, outfit_tint.rgb * (0.35 + hsv.z * 1.6), outfit_mix);
			} else {
				hsv.x = fract(hsv.x + hue_shift);
				c.rgb = hsv2rgb(hsv);
			}
		}
	}
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
}
