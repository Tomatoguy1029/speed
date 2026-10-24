shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float crt_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec3 screen = texture(screen_texture, SCREEN_UV).rgb;
	vec2 pixel = floor(UV * vec2(640.0, 360.0));
	float scanline = mod(pixel.y, 2.0) * 0.16;
	float phosphor_mask = step(1.0, mod(pixel.x, 3.0)) * 0.025;
	vec2 edge = UV * 2.0 - 1.0;
	float vignette = dot(edge, edge) * 0.045;
	// 発光部にだけ、ごく弱い隣接画素の光を足す。芯のドットは保つ。
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec3 nearby = texture(screen_texture, SCREEN_UV + vec2(texel.x, 0.0)).rgb
		+ texture(screen_texture, SCREEN_UV - vec2(texel.x, 0.0)).rgb
		+ texture(screen_texture, SCREEN_UV + vec2(0.0, texel.y)).rgb
		+ texture(screen_texture, SCREEN_UV - vec2(0.0, texel.y)).rgb;
	vec3 phosphor_light = max(nearby * 0.25 - vec3(0.3), vec3(0.0)) * 0.05;
	COLOR = vec4(screen * (1.0 - crt_strength * (scanline + phosphor_mask + vignette))
		+ phosphor_light * crt_strength, COLOR.a);
}
