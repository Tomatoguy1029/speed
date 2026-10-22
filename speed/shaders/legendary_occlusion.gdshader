// 遺物を覆う黒い影。固定した粒状の濃淡をゆっくり解き、電子的な位置ずれを加えない。
shader_type canvas_item;
render_mode unshaded;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 1.0;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.025;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float grain(vec2 p) {
	vec2 c = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(c), hash(c + vec2(1.0, 0.0)), f.x),
		mix(hash(c + vec2(0.0, 1.0)), hash(c + vec2(1.0)), f.x), f.y);
}
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 tint = item_tint;
	float shape = texture(TEXTURE, UV).a;
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	float veil = grain(pixel / 17.0) * 0.65 + grain(pixel / 5.0) * 0.25 + hash(pixel) * 0.1;
	float uncover = smoothstep(veil - 0.18, veil + 0.18, mix(-0.2, 1.2, exposure));
	float soot = 0.003 + hash(pixel) * grain_strength;
	COLOR = vec4(vec3(soot * 0.8, soot * 0.85, soot), shape * (1.0 - uncover) * shadow_strength) * tint;
}
