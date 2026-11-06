shader_type canvas_item;
render_mode unshaded, blend_add;
// 光だけの低解像度の絵を、そのまま足す。
uniform float strength = 1.0;
void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb * strength, 1.0);
}
