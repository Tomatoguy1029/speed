shader_type canvas_item;
uniform sampler2D base_tex : source_color, filter_nearest;
uniform sampler2D armor_tex : source_color, filter_nearest;
uniform sampler2D normal_tex : hint_normal, filter_nearest;
uniform sampler2D enemy0 : source_color, filter_nearest;
uniform sampler2D enemy1 : source_color, filter_nearest;
uniform sampler2D enemy2 : source_color, filter_nearest;
uniform float full = 0.0;
uniform float clock = 0.0;
uniform float flash = 0.0;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
varying vec2 local_pixel;
varying vec2 basis_x;
varying vec2 basis_y;
varying vec4 albedo;
// 元のBase+Armor後部輪郭。固定入力の解析を実行時に繰り返さない。
const float OUTLINE[72] = float[72](8.975,9.1,8.225,8.35,8.6,7.85,8.225,8.725,8.1,8.725,8.1,8.725,8.225,7.85,8.6,8.35,8.225,9.1,9.1,9.1,9.225,9.225,8.6,8.975,8.6,8.725,9.35,8.725,9.35,9.1,9.35,8.975,9.6,9.35,9.225,10.1,10.1,10.1,10.225,9.35,9.6,9.975,9.35,9.975,10.6,11.6,11.975,11.1,10.475,9.975,9.6,9.35,9.225,9.1,9.1,9.1,9.225,9.35,9.6,9.975,10.475,11.1,11.225,10.1,9.35,8.725,8.6,8.975,8.6,9.225,9.225,9.1);
void vertex() {
	local_pixel = VERTEX + vec2(12.0, 27.0);
	basis_x = normalize(MODEL_MATRIX[0].xy);
	basis_y = normalize(MODEL_MATRIX[1].xy);
}
void fragment() {
	vec2 p = floor(local_pixel);
	vec2 source = p;
	bool front = p.y < 18.0 && p.x >= 0.0 && p.x < 24.0 && p.y >= 0.0;
	if (front) front = max(texture(base_tex,(p+0.5)/vec2(24,37)).a,texture(armor_tex,(p+0.5)/vec2(24,37)).a)>0.0;
	vec2 delta = p - vec2(12.0, 27.0);
	float a = mod(atan(delta.y, delta.x) + TAU, TAU);
	float original = OUTLINE[int(round(a / TAU * 72.0)) % 72];
	float target = mix(original, 16.5, full);
	bool rear = full <= 0.001 || length(delta) <= target;
	if (!front && full > 0.001) source = floor(vec2(12.0, 27.0) + delta * original / target + 0.5);
	bool valid = source.x >= 0.0 && source.x < 24.0 && source.y >= (front ? 0.0 : 18.0) && source.y < 37.0;
	vec2 sample_uv = (source + 0.5) / vec2(24.0, 37.0);
	vec4 base = valid && (front || rear) ? texture(base_tex, sample_uv) : vec4(0.0);
	vec4 armor = valid && (front || rear) ? texture(armor_tex, sample_uv) : vec4(0.0);
	vec4 contents = vec4(0.0);
	for (int j = 0; j < 7; j++) {
		float angle = float(j) * 2.39996;
		vec2 center = vec2(12.0, 27.0) + vec2(cos(angle), sin(angle)) * (j == 0 ? 0.0 : 3.8);
		vec2 uv = (source - center) / (j % 3 == 2 ? vec2(4,8) : vec2(8)) + 0.5;
		if (float(j) < ceil(full * 7.0) && all(greaterThanEqual(uv, vec2(0))) && all(lessThan(uv, vec2(1)))) {
			vec4 piece = j % 3 == 0 ? texture(enemy0, uv) : (j % 3 == 1 ? texture(enemy1, uv) : texture(enemy2, uv));
			contents = mix(contents, piece, piece.a);
		}
	}
	vec4 inside = mix(base, contents, contents.a * base.a);
	if (base.r > base.g * 1.4 && base.r > 0.1) inside = base;
	albedo = armor;
	albedo.rgb = mix(armor.rgb, vec3(1.0), flash * 0.8);
	vec3 color = mix(inside.rgb, albedo.rgb * ambient, armor.a);
	COLOR = vec4(color * brightness, max(base.a, armor.a));
	vec3 n = texture(normal_tex, sample_uv).rgb * 2.0 - 1.0;
	n.y *= -1.0;
	n = normalize(vec3(n.xy * normal_strength, max(n.z, 0.001)));
	NORMAL = vec3(mat2(basis_x, basis_y) * n.xy, n.z);
}
void light() {
	LIGHT = vec4(albedo.rgb * albedo.a * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * max(dot(NORMAL, LIGHT_DIRECTION), 0.0), LIGHT_COLOR.a);
}
