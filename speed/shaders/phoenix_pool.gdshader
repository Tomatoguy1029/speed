// 鳳凰の上空の炎が着地点を照らす光だまり。影より奥へ加算する。
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 center_color : source_color;
uniform vec4 middle_color : source_color;
uniform vec4 edge_color : source_color;
uniform float center_alpha;
uniform float middle_alpha;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	vec4 first = vec4(center_color.rgb, center_alpha);
	vec4 middle = vec4(middle_color.rgb, middle_alpha);
	vec4 edge = vec4(edge_color.rgb, 0.0);
	COLOR = radius < 0.5 ? mix(first, middle, radius * 2.0) : mix(middle, edge, clamp((radius - 0.5) * 2.0, 0.0, 1.0));
}
