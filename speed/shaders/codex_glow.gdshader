// 図鑑の実演の光（試作の glow）：四角いっぱいの円の中心で glow_color、縁で 0 になる光を加算する。
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(1.0);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	if (d >= 1.0) {
		discard;
	}
	COLOR = vec4(glow_color.rgb * glow_color.a * (1.0 - d), 1.0);
}
