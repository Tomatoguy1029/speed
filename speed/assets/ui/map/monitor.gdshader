shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float crt_strength : hint_range(0.0, 1.0) = 0.25;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.012;

float noise(vec2 pixel) {
	return fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	vec2 pixel = floor(UV * vec2(640.0, 360.0));
	float scanline = mod(pixel.y, 2.0) * 0.08;
	vec2 edge = UV * 2.0 - 1.0;
	float vignette = dot(edge, edge) * 0.045;
	float grain = noise(pixel + floor(TIME * 12.0)) - 0.5;
	// 画素をずらさず、弱い走査線・周辺減光・微量ノイズだけを重ねる。
	COLOR = vec4(screen * (1.0 - crt_strength * (scanline + vignette)) + grain * noise_strength, COLOR.a);
}
