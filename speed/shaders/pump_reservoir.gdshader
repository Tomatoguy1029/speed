shader_type canvas_item;
uniform sampler2D base_tex : source_color, filter_nearest;
uniform sampler2D armor_tex : source_color, filter_nearest;
uniform sampler2D normal_tex : hint_normal, filter_nearest;
uniform sampler2D enemy0 : source_color, filter_nearest;
uniform sampler2D enemy1 : source_color, filter_nearest;
uniform sampler2D enemy2 : source_color, filter_nearest;
#include "res://shaders/elite_death.gdshaderinc"
uniform float death_age = 0.0;
uniform float full = 0.0;
uniform float stored_full = 0.0;
uniform float clock = 0.0;
uniform float flash = 0.0;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
// 縁を焼き込み外周を広げた絵のときの余白ドット数（0 なら元の絵）
uniform float pad = 0.0;
uniform vec3 outline_color : source_color = vec3(0.008, 0.016, 0.039);
varying vec2 local_pixel;
varying vec4 albedo;
#include "res://shaders/pump_outline.gdshaderinc"
void vertex() {
	local_pixel = VERTEX + vec2(12.0, 27.0);
}
void fragment() {
	vec2 p = floor(local_pixel);
	vec2 source = p;
	vec2 padded = vec2(24.0, 37.0) + 2.0 * pad;
	bool front = p.y < 18.0 && p.x >= -pad && p.x < 24.0 + pad && p.y >= -pad;
	if (front) front = max(texture(base_tex,(p+pad+0.5)/padded).a,texture(armor_tex,(p+pad+0.5)/padded).a)>0.0;
	vec2 delta = p - vec2(12.0, 27.0);
	vec2 radii = pump_radii(p, full);
	float target = radii.y;
	bool rear = full <= 0.001 || length(delta) <= target;
	if (!front && full > 0.001) source = pump_source(p, radii);
	// 膨らんだ後部は形が変わるため、膨らんだ外周の1ドット外側へ縁を置く
	bool rim = !front && full > 0.001 && pad > 0.0 && p.y >= 18.0 && length(delta) > target && length(delta) <= target + pad;
	bool valid = source.x >= -pad && source.x < 24.0 + pad && source.y >= (front ? -pad : 18.0) && source.y < 37.0 + pad;
	vec3 mapped = death_sample((source + 0.5) / vec2(24.0, 37.0), death_age);
	if (mapped.z < 0.5) discard;
	if (death_enabled) source = mapped.xy * vec2(24.0, 37.0) - 0.5;
	vec2 sample_uv = (source + pad + 0.5) / padded;
	vec4 base = valid && (front || rear) ? texture(base_tex, sample_uv) : vec4(0.0);
	vec4 armor = valid && (front || rear) ? texture(armor_tex, sample_uv) : vec4(0.0);
	vec4 contents = vec4(0.0);
	for (int j = 0; j < 7; j++) {
		float angle = float(j) * 2.39996;
		vec2 center = vec2(12.0, 27.0) + vec2(cos(angle), sin(angle)) * (j == 0 ? 0.0 : 3.8);
		vec2 uv = (source - center) / (j % 3 == 2 ? vec2(4,8) : vec2(8)) + 0.5;
		if (float(j) < ceil(stored_full * 7.0) && all(greaterThanEqual(uv, vec2(0))) && all(lessThan(uv, vec2(1)))) {
			vec4 piece = j % 3 == 0 ? texture(enemy0, uv) : (j % 3 == 1 ? texture(enemy1, uv) : texture(enemy2, uv));
			contents = mix(contents, piece, piece.a);
		}
	}
	// Baseは赤い芯以外が透過。収納物は後部の内側へ表示し、Baseのalphaで消さない。
	float contents_alpha = valid && rear && !front ? contents.a : 0.0;
	vec4 inside = mix(base, contents, contents_alpha);
	if (base.r > base.g * 1.4 && base.r > 0.1) inside = base;
	albedo = armor;
	albedo.rgb = mix(armor.rgb, vec3(1.0), flash * 0.8);
	vec3 color = mix(inside.rgb, albedo.rgb * ambient, armor.a);
	COLOR = vec4(color * brightness, max(max(base.a, armor.a), contents_alpha));
	if (rim) {
		albedo = vec4(0.0);
		COLOR = vec4(outline_color * brightness, 1.0);
	}
	vec3 n = texture(normal_tex, sample_uv).rgb * 2.0 - 1.0;
	n.y *= -1.0;
	n = normalize(vec3(n.xy * normal_strength, max(n.z, 0.001)));
	// 個体ごとのMeshInstance2Dの回転は、fragment後にGodotが法線へ適用する。
	NORMAL = n;
}
void light() {
	LIGHT = vec4(albedo.rgb * albedo.a * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * max(dot(NORMAL, LIGHT_DIRECTION), 0.0), LIGHT_COLOR.a);
}
