// ベイク済みRGBの再生だけを行う。ノイズ・輪郭生成を行わない。
shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 atlas_grid = vec2(8.0, 4.0);
uniform float frame_count = 32.0;
uniform float frame_position = 0.0;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	float current = mod(floor(frame_position), frame_count);
	float next = mod(current + 1.0, frame_count);
	vec2 inset = TEXTURE_PIXEL_SIZE * atlas_grid * 0.5;
	vec2 uv = clamp(UV, inset, vec2(1.0) - inset);
	vec2 a = (vec2(mod(current, atlas_grid.x), floor(current / atlas_grid.x)) + uv) / atlas_grid;
	vec2 b = (vec2(mod(next, atlas_grid.x), floor(next / atlas_grid.x)) + uv) / atlas_grid;
	vec3 light = mix(texture(TEXTURE, a).rgb, texture(TEXTURE, b).rgb, fract(frame_position));
	COLOR = vec4(light * item_tint.rgb, item_tint.a);
}
