shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	bool left_front = p.x >= 2.0 && p.x < 7.0 && p.y >= 11.0 && p.y < 21.0;
	bool right_front = p.x >= 13.0 && p.x < 18.0 && p.y >= 11.0 && p.y < 21.0;
	bool left_rear = p.x >= 1.0 && p.x < 7.0 && p.y >= 21.0 && p.y < 31.0;
	bool right_rear = p.x >= 13.0 && p.x < 19.0 && p.y >= 21.0 && p.y < 31.0;
	if (left_front || right_front || left_rear || right_rear) discard;
}
