shader_type canvas_item;
#include "res://shaders/elite_death.gdshaderinc"
varying float death_age;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;

varying float hit_flash;
varying float fuse_flash;
varying vec2 instance_x;
varying vec2 instance_y;

void vertex() {
	death_age = COLOR.a;
	hit_flash = COLOR.r;
	fuse_flash = COLOR.g;
	instance_x = normalize(MODEL_MATRIX[0].xy);
	instance_y = normalize(MODEL_MATRIX[1].xy);
}

void fragment() {
	vec3 mapped = death_sample(UV, death_age);
	if (mapped.z < 0.5) discard;
	vec2 sprite_uv = mapped.xy;
	vec4 armor = texture(TEXTURE, sprite_uv);
	vec3 base = mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient;
	base = mix(base, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9 * (1.0 - hit_flash));
	COLOR = vec4(base * brightness, armor.a);
	// MultiMeshの個体ごとの回転も法線へ反映する（描画ノード自体の変換は単位行列）。
	if (death_enabled) NORMAL = texture(NORMAL_TEXTURE, sprite_uv).rgb * vec3(2.0, -2.0, 2.0) + vec3(-1.0, 1.0, -1.0);
	vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
	NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
}

void light() {
	vec2 sprite_uv = death_sample(UV, death_age).xy;
	vec3 albedo = mix(texture(TEXTURE, sprite_uv).rgb, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9);
	albedo = mix(albedo, vec3(1.0), hit_flash * 0.8);
	float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse, LIGHT_COLOR.a);
}
