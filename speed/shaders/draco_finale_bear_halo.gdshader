shader_type canvas_item;
render_mode unshaded, blend_add;
// こぐま座の外側の光。形を淡い金で決着の光の層へ足し、光の合成でにじませる。
uniform vec4 halo = vec4(1.0, 0.886, 0.627, 1.0);
uniform float strength = 0.55;

void fragment() {
	COLOR = vec4(halo.rgb, step(0.5, texture(TEXTURE, UV).a) * COLOR.a * strength);
}
