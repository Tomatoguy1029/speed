// やわらかい光：四角いっぱいの円の中心で glow_color、縁で 0 になる光を加算する（試作の glow）。
// 試作のキャンバスと同じく、画面の色（sRGB）で中心から外へ薄れる量を求めてから足す。
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0);

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	if (d >= 1.0) {
		discard;
	}
	COLOR = vec4(to_linear(to_srgb(glow_color.rgb) * glow_color.a * (1.0 - d)), 1.0);
}
