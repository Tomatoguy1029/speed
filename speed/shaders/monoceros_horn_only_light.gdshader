// 角だけの発光を1.1倍にする。頭部の装甲と被弾の白は別のままにする。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float strength = 0.0;
varying float tint_alpha;
void vertex() { tint_alpha = COLOR.a; }
void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(1.0, 1.0, 1.0, mask * tint_alpha * strength * 1.1);
}
