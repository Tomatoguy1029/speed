shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

uniform vec2 view_center;
uniform vec2 view_half;
uniform float camera_zoom = 1.0;

void vertex() {
	// The random star data and circle mesh are uploaded once. Only view uniforms change.
	vec3 star = INSTANCE_CUSTOM.xyz;
	vec2 period_half = view_half * 2.4;
	vec2 offset = mod(star.xy * 5000.0 - view_center * (1.0 - star.z * 0.3), period_half * 2.0) - period_half;
	VERTEX = view_center + offset * 0.5 + VERTEX * (1.2 * star.z / max(camera_zoom, 0.01));
}
