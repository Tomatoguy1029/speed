shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/elite_death.gdshaderinc"
varying float death_age;
uniform float brightness = 1.0;

// INSTANCE_COLOR.r を被弾フラッシュに使う。素材本来の色を保持する。
varying float hit_flash;
void vertex() {
	death_age = COLOR.a;
	hit_flash = COLOR.r;
}
void fragment() {
	vec3 mapped = death_sample(UV, death_age);
	if (mapped.z < 0.5) discard;
	vec2 sprite_uv = mapped.xy;
	vec4 sprite = texture(TEXTURE, sprite_uv);
	COLOR = vec4(mix(sprite.rgb, vec3(1.0), hit_flash * 0.8) * brightness, sprite.a);
}
