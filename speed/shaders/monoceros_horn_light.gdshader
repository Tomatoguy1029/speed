// 角と頭の装甲へ、元画像の透明度を使った白い光を加算する。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float strength = 0.0;
varying float tint_alpha;
void vertex() { tint_alpha = COLOR.a; }
void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(1.0, 1.0, 1.0, mask * tint_alpha * strength);
}
