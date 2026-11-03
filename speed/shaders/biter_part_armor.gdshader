shader_type canvas_item;
uniform sampler2D paint_tex : source_color, filter_nearest;
#include "res://shaders/elite_death.gdshaderinc"
varying float death_age;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
varying float hit_flash;
varying vec2 instance_x;
varying vec2 instance_y;

void vertex() {
	death_age = COLOR.a;
	hit_flash = COLOR.r;
	instance_x = normalize(MODEL_MATRIX[0].xy);
	instance_y = normalize(MODEL_MATRIX[1].xy);
}
void fragment() {
	vec3 mapped = death_sample(UV, death_age);
	if (mapped.z < 0.5) discard;
	vec2 sprite_uv = mapped.xy;
	// RGBは共通の確定塗装、アルファと法線は制作時に分割した部位。
	vec4 armor = texture(paint_tex, sprite_uv);
	float alpha = texture(TEXTURE, sprite_uv).a;
	COLOR = vec4(mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient * brightness, alpha);
	if (death_enabled) NORMAL = texture(NORMAL_TEXTURE, sprite_uv).rgb * vec3(2.0, -2.0, 2.0) + vec3(-1.0, 1.0, -1.0);
	vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
	NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
}
void light() {
	vec2 sprite_uv = death_sample(UV, death_age).xy;
	vec3 albedo = mix(texture(paint_tex, sprite_uv).rgb, vec3(1.0), hit_flash * 0.8);
	LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * max(dot(NORMAL, LIGHT_DIRECTION), 0.0), LIGHT_COLOR.a);
}
