shader_type canvas_item;
render_mode unshaded;

uniform bool highlighted = false;
uniform vec4 part_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D surface_mask : filter_nearest, repeat_disable;
uniform float effect_progress : hint_range(0.0, 1.0) = 1.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float scan_width : hint_range(0.01, 0.2) = 0.1;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 cyan = vec3(0.357, 0.784, 0.859);
	vec3 base = highlighted ? cyan : pixel.rgb;
	vec2 local_uv = (UV - part_uv_rect.xy) / part_uv_rect.zw;
	float surface = texture(surface_mask, local_uv).r;
	float scan_y = mix(-0.2, 1.2, clamp(effect_progress / 0.65, 0.0, 1.0));
	float distance_to_scan = abs(local_uv.y - scan_y);
	float line = 1.0 - smoothstep(0.0, scan_width, distance_to_scan);
	float glow = 1.0 - smoothstep(0.0, scan_width * 3.0, distance_to_scan);
	float envelope = smoothstep(0.0, 0.06, effect_progress)
		* (1.0 - smoothstep(0.8, 1.0, effect_progress));
	float scan = (line + glow * 0.4) * envelope;
	float revealed = 1.0 - smoothstep(scan_y - scan_width, scan_y + scan_width, local_uv.y);
	float flash = smoothstep(0.52, 0.66, effect_progress) * envelope;
	float light = clamp((revealed * 0.7 + scan * 0.8 + flash) * effect_strength * envelope, 0.0, 1.0);
	vec3 fill_color = mix(cyan * 0.6, cyan, clamp(scan + flash, 0.0, 1.0));
	vec3 color = mix(fill_color, mix(base, cyan, light), pixel.a);
	// 走査後に面の色を残し、全体を短く光らせて元の透過へ戻す。
	COLOR = vec4(color, max(pixel.a, surface * light)) * tint;
}
