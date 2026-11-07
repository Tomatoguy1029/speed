// 継続演出の色付きの影絵を加算する。形は画像のalpha、色は頂点色から取る。
shader_type canvas_item;
render_mode blend_premul_alpha;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	float a = texture(TEXTURE, UV).a * tint.a;
	COLOR = vec4(tint.rgb * a, 0.0);
}
