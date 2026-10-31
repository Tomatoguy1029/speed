// Radial glass cells / outward fracture adapt pixelfx a841596, Patch / Hugo Duprez, MIT.
// Mesh authoring owns the seeded shape. This shader only animates those cells.
// See assets/ui/rewards/pixelfx_LICENSE.txt and pixelfx_NOTICE.txt.
shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform sampler2D source_scene : filter_nearest, repeat_disable;
uniform sampler2D game_backdrop : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float background_dim = 0.54;
uniform float transition_opacity = 1.0;
uniform vec2 design_size = vec2(640.0, 360.0);
uniform vec2 focus = vec2(0.49, 0.45);
uniform float pixel_size = 2.0;
uniform float opening_seconds = 0.90;
uniform float crack_fraction = 0.24;
uniform float crack_flash_width = 0.045;
uniform float crack_tint_strength = 0.14;
uniform float shard_ink_mix = 0.12;
uniform float shard_fade_start = 0.66;
uniform float front_delay = 0.10;
uniform float scatter_speed = 210.0;
uniform float fall_acceleration = 1450.0;
uniform float spin_speed = 5.0;
uniform float glow_strength = 0.22;
uniform bool edge_pass = false;
uniform vec4 transition_color : source_color = vec4(1.0, 0.827, 0.298, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.949, 0.651, 1.0);
uniform vec4 ink_color : source_color = vec4(0.063, 0.071, 0.110, 1.0);
varying float shard_age;
varying float source_distance;

void vertex() {
	vec2 center = COLOR.rg * design_size;
	vec2 delta = center - focus * design_size;
	float distance_to_impact = length(delta);
	float delay = (distance_to_impact / 400.0 * 0.65 + COLOR.a * 0.35) * front_delay;
	float burst = max(0.0, (progress - crack_fraction) / (1.0 - crack_fraction));
	shard_age = clamp((burst - delay) / (1.0 - delay), 0.0, 1.0);
	source_distance = distance_to_impact;
	float seconds = shard_age * opening_seconds;
	float turn = (COLOR.b - 0.5) * spin_speed * seconds;
	vec2 p = VERTEX - center;
	p = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * p;
	p.x *= max(0.10, abs(cos(seconds * (2.0 + COLOR.b * 3.0))));
	vec2 direction = delta / max(1.0, distance_to_impact);
	VERTEX = center + p + direction * scatter_speed * seconds + vec2(0.0, 0.5 * fall_acceleration * seconds * seconds);
	VERTEX = floor(VERTEX / pixel_size + 0.5) * pixel_size;
}

void fragment() {
	float flash = max(0.0, 1.0 - abs(progress - crack_fraction) / crack_flash_width);
	float alpha = 1.0 - smoothstep(shard_fade_start, 1.0, shard_age);
	vec4 source = texture(source_scene, UV);
	vec3 dimmed = mix(source.rgb, dim_color.rgb, dim_color.a * background_dim);
	vec4 backdrop = texture(game_backdrop, UV);
	vec3 composite = mix(backdrop.rgb, dimmed, source.a);
	vec3 color = mix(composite, ink_color.rgb, shard_ink_mix);
	color = mix(color, transition_color.rgb, flash * crack_tint_strength);
	alpha *= ink_color.a;
	if (edge_pass) {
		float arrival = length(UV * design_size - focus * design_size) / 410.0;
		alpha *= step(arrival, progress / crack_fraction);
		color = flash > 0.45 ? highlight_color.rgb : transition_color.rgb;
		alpha *= flash > 0.45 ? highlight_color.a : transition_color.a;
		color += transition_color.rgb * flash * glow_strength;
	}
	COLOR = vec4(color, progress >= 1.0 ? 0.0 : alpha * transition_opacity);
}
