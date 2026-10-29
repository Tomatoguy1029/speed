shader_type canvas_item;
render_mode unshaded;

uniform float pixel_grid = 72.0;
uniform float inner_radius = 0.31;
uniform float outer_radius = 0.48;
uniform float noise_scale = 11.0;
uniform float motion_speed = 1.25;
uniform float intensity = 0.9;
uniform vec4 mark_color : source_color = vec4(0.82, 0.68, 0.38, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.96, 0.8, 1.0);
uniform float mark_time = 0.0;

varying float seed;
void vertex() { seed = COLOR.r; }

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 pixel = (cell + 0.5) / pixel_grid - 0.5;
	float radius = length(pixel);
	float angle = atan(pixel.y, pixel.x);
	float drift = mark_time * motion_speed + seed * 18.0;
	float grain = hash21(floor(pixel * noise_scale * 16.0) + floor(drift * 2.0));
	float rays = pow(max(0.0, sin(angle * 11.0 + drift * 0.8)), 8.0);
	float lattice = hash21(cell + floor(drift * 3.0) + seed * 37.0);
	float band = step(inner_radius, radius) * (1.0 - step(outer_radius, radius));
	float fleck = band * step(0.83, lattice) * (0.35 + 0.65 * rays);
	float veil = band * step(0.70, grain) * (0.12 + 0.15 * rays);
	float alpha = min(0.78, (fleck * 0.65 + veil) * intensity);
	vec3 rgb = mix(mark_color.rgb, highlight_color.rgb, step(0.95, lattice));
	COLOR = vec4(rgb, alpha);
}
