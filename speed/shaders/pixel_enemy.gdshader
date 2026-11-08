shader_type canvas_item;
// 縁を焼き込んだ下地（base_tex）と、照明を受ける装甲（TEXTURE＋法線）を1体ずつまとめて描く。
// 層ごとに全個体を描くと後ろの個体の装甲が前の個体の縁を覆うため、1回の描画で重ねる。
// 絵は外周を outline_pad ドット広げてある。崩壊の座標アトラスは広げる前の大きさで引く。
#include "res://shaders/elite_death.gdshaderinc"
#include "res://shaders/hero_stone.gdshaderinc"
varying float death_age;
uniform sampler2D base_tex : filter_nearest;
uniform float outline_pad = 1.0;
// 部位に分けた絵（噛みつく雑魚）は、装甲の色を共通の確定塗装から、アルファと法線を部位から取る
uniform bool use_paint = false;
uniform sampler2D paint_tex : filter_nearest;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
// HDR の画面へ描くときは true（石の色をリニアで出す）
uniform bool stone_linear = false;

varying float hit_flash;
varying float fuse_flash;
varying float stone_since;
varying vec2 instance_x;
varying vec2 instance_y;

vec3 padded_sample(vec2 uv, float age) {
	vec2 size = vec2(textureSize(base_tex, 0));
	vec2 inner = size - 2.0 * outline_pad;
	vec3 mapped = death_sample((uv * size - outline_pad) / inner, age);
	return vec3((mapped.xy * inner + outline_pad) / size, mapped.z);
}

void vertex() {
	death_age = COLOR.a;
	hit_flash = COLOR.r;
	fuse_flash = COLOR.g;
	stone_since = COLOR.b;
	instance_x = normalize(MODEL_MATRIX[0].xy);
	instance_y = normalize(MODEL_MATRIX[1].xy);
}

void fragment() {
	vec3 mapped = padded_sample(UV, death_age);
	if (mapped.z < 0.5) discard;
	vec2 sprite_uv = mapped.xy;
	vec2 size = vec2(textureSize(base_tex, 0));
	vec4 armor = texture(TEXTURE, sprite_uv);
	if (use_paint) armor.rgb = texture(paint_tex, sprite_uv).rgb;
	if (armor.a > 0.0) {
		armor.rgb = hero_stone(armor.rgb, sprite_uv, size, stone_since, TIME, stone_linear);
		vec3 lit = mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient;
		lit = mix(lit, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9 * (1.0 - hit_flash));
		COLOR = vec4(lit * brightness, armor.a);
		// MultiMeshの個体ごとの回転も法線へ反映する（描画ノード自体の変換は単位行列）。
		if (death_enabled) NORMAL = texture(NORMAL_TEXTURE, sprite_uv).rgb * vec3(2.0, -2.0, 2.0) + vec3(-1.0, 1.0, -1.0);
		vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
		NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
	} else {
		vec4 base = texture(base_tex, sprite_uv);
		if (base.a <= 0.0) discard;
		base.rgb = hero_stone(base.rgb, sprite_uv, size, stone_since, TIME, stone_linear);
		COLOR = vec4(mix(base.rgb, vec3(1.0), hit_flash * 0.8) * brightness, base.a);
	}
}

void light() {
	vec2 sprite_uv = padded_sample(UV, death_age).xy;
	vec4 armor = texture(TEXTURE, sprite_uv);
	if (use_paint) armor.rgb = texture(paint_tex, sprite_uv).rgb;
	// 下地と縁は照明を受けない
	if (armor.a <= 0.0) {
		LIGHT = vec4(0.0);
	} else {
		vec3 albedo = hero_stone(armor.rgb, sprite_uv, vec2(textureSize(base_tex, 0)), stone_since, TIME, stone_linear);
		albedo = mix(albedo, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9);
		albedo = mix(albedo, vec3(1.0), hit_flash * 0.8);
		float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
		LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse, LIGHT_COLOR.a);
	}
}
