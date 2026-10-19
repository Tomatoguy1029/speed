shader_type canvas_item;
render_mode unshaded;

uniform sampler2D sweep_texture : filter_nearest, repeat_disable;
uniform sampler2D stars_texture : filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform bool panel_open = false;
uniform float map_progress = 0.0;
uniform sampler2D map_ring_texture : filter_nearest, repeat_disable;
uniform float map_angle = 0.0;

void fragment() {
	vec2 canvas = vec2(640.0, 360.0);
	vec2 center = vec2(462.0, 176.0);
	vec2 map_center = mix(center, vec2(198.0, 195.0), map_progress);
	vec2 offset = (UV * canvas - map_center) / vec2(1.0, mix(1.0, 0.5, map_progress));
	vec2 radar_uv = (offset + center) / canvas;
	float rotation = elapsed * TAU / 16.0;
	float c = cos(rotation);
	float s = sin(rotation);
	vec2 source = vec2(c * offset.x + s * offset.y, -s * offset.x + c * offset.y);
	vec2 sweep_uv = (source + center) / canvas;
	vec4 sweep = texture(sweep_texture, clamp(sweep_uv, vec2(0.0), vec2(1.0)));
	float inside = step(length(offset), 150.0);
	float age = mod(rotation - (atan(offset.y, offset.x) + PI * 0.5) + TAU, TAU);
	float fade = exp(-age * 0.625) * step(age, rotation);
	vec4 stars = texture(stars_texture, radar_uv);
	vec4 base = texture(TEXTURE, UV);
	if (panel_open && UV.x * canvas.x < 280.0 && UV.y * canvas.y > 65.0 && UV.y * canvas.y < 140.0) {
		base.rgb = vec3(0.0);
	}
	if (map_progress > 0.0) {
		if (distance(UV * canvas, center) < 154.0) {
			base.rgb = vec3(0.0);
		}
		base.rgb = mix(base.rgb, vec3(0.012, 0.035, 0.045), map_progress);
	}
	vec3 radar = sweep.rgb * sweep.a * 0.45 + stars.rgb * stars.a * fade;
	float reveal = smoothstep(0.55, 1.0, map_progress);
	float rc = cos(map_angle * map_progress);
	float rs = sin(map_angle * map_progress);
	vec2 ring_offset = vec2(rc * offset.x + rs * offset.y, -rs * offset.x + rc * offset.y);
	vec2 ring_uv = (ring_offset + vec2(175.0)) / vec2(351.0);
	vec4 circle = texture(map_ring_texture, clamp(ring_uv, vec2(0.0), vec2(1.0)));
	float ring_bounds = step(0.0, ring_uv.x) * step(ring_uv.x, 1.0) * step(0.0, ring_uv.y) * step(ring_uv.y, 1.0);
	// 共通の円と格子は常に描き、外側の文様だけを出現させる。
	float ring_visibility = length(ring_offset) <= 150.5 ? 1.0 : reveal;
	vec3 moving_ring = circle.rgb * circle.a * ring_bounds * ring_visibility;
	COLOR = vec4(max(base.rgb, max(moving_ring, radar * inside * (1.0 - map_progress))), 1.0);
}
