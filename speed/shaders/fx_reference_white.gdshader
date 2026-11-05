// 元画像の透明度に白い光だけを加算し、元の彩色・法線は変更しない。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float strength = 0.0;
varying float tint_alpha;
void vertex() { tint_alpha = COLOR.a; }
void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a * tint_alpha * strength);
}
