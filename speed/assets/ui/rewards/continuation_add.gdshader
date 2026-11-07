// 継続演出の加算（Canvas2D の lighter）。透明な層へ色だけを足し、alphaは下の値を保つ。
shader_type canvas_item;
render_mode blend_premul_alpha;
void fragment() {
	COLOR = vec4(COLOR.rgb * COLOR.a, 0.0);
}
