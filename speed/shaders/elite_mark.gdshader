shader_type canvas_item;
render_mode unshaded;

uniform float pixel_grid = 64.0;
uniform float inner_radius = 0.29;
uniform float outer_radius = 0.43;
uniform float noise_scale = 7.0;
uniform float motion_speed = 0.65;
uniform float intensity = 0.85;
uniform vec4 mark_color : source_color = vec4(0.89, 0.47, 0.18, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.82, 0.43, 1.0);
uniform float mark_time = 0.0;

varying float seed;
void vertex() { seed = COLOR.r; }

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 pixel = (cell + 0.5) / pixel_grid - 0.5;
	float radius = length(pixel);
	float angle = atan(pixel.y, pixel.x);
	float sector = floor((angle + 3.14159) * 8.0 / 6.28318);
	float angular_pos = fract((angle + 3.14159) * 8.0 / 6.28318);
	float t = mark_time * motion_speed + seed * 13.0;
	float panel = step(0.12, angular_pos) * (1.0 - step(0.76, angular_pos));
	float seam = step(0.46, angular_pos) * (1.0 - step(0.52, angular_pos));
	float serration = step(0.5, hash21(vec2(sector, floor(radius * noise_scale * 20.0))));
	float band = step(inner_radius, radius) * (1.0 - step(outer_radius - serration * 0.018, radius));
	float scan = step(0.82, hash21(vec2(sector + seed * 19.0, floor(t * 4.0))));
	float alpha = band * panel * (0.27 + 0.27 * scan + 0.21 * seam) * intensity;
	vec3 rgb = mix(mark_color.rgb, highlight_color.rgb, max(seam, scan * 0.7));
	COLOR = vec4(rgb, min(alpha, 0.72));
}
