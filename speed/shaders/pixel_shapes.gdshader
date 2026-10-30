// ドット単位の図形を、1つの四角に1つずつ GPU で塗る（PixelShapes）。光を足し合わせて描く。図形は pixel_shapes.gdshaderinc。
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "pixel_shapes.gdshaderinc"

void fragment() {
	vec4 c = shape_color(COLOR);
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = vec4(c.rgb * c.a, 1.0);
}
