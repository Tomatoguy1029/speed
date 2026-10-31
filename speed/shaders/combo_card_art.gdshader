// Authoring-only palette replacement for the existing card atlas. No new frame geometry.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 source_frame : source_color = vec4(0.356862745, 0.784313725, 0.858823529, 1.0);
uniform vec4 source_fill : source_color = vec4(0.121568627, 0.196078431, 0.239215686, 1.0);
uniform vec4 card_frame_color : source_color = vec4(0.356862745, 0.784313725, 0.858823529, 1.0);
uniform vec4 card_fill_color : source_color = vec4(0.121568627, 0.196078431, 0.239215686, 1.0);
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec4 result = source;
	if (distance(source.rgb, source_frame.rgb) < 0.02) result = vec4(card_frame_color.rgb, source.a * card_frame_color.a);
	else if (distance(source.rgb, source_fill.rgb) < 0.02) result = vec4(card_fill_color.rgb, source.a * card_fill_color.a);
	COLOR = result * item_tint;
}
