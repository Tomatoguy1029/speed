// ドット単位の図形を、1つの四角に1つずつ GPU で塗る（PixelShapes）。重ねて描く。図形は pixel_shapes.gdshaderinc。
shader_type canvas_item;
render_mode unshaded;
#include "pixel_shapes.gdshaderinc"

void fragment() {
	vec4 c = shape_color(COLOR);
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
