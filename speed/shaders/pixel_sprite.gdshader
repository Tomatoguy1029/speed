shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/elite_death.gdshaderinc"
#include "res://shaders/hero_stone.gdshaderinc"
varying float death_age;
uniform float brightness = 1.0;
// 敵の描画だけが有効にする。ほかの絵では b を石の時刻として読まない
uniform bool stone_enabled = false;
// HDR の画面へ描くときは true（石の色をリニアで出す）
uniform bool stone_linear = false;

// INSTANCE_COLOR.r を被弾フラッシュ、b を石になってからの秒に使う。素材本来の色を保持する。
varying float hit_flash;
varying float stone_since;
void vertex() {
	death_age = COLOR.a;
	hit_flash = COLOR.r;
	stone_since = COLOR.b;
}
void fragment() {
	vec3 mapped = death_sample(UV, death_age);
	if (mapped.z < 0.5) discard;
	vec2 sprite_uv = mapped.xy;
	vec4 sprite = texture(TEXTURE, sprite_uv);
	if (stone_enabled) sprite.rgb = hero_stone(sprite.rgb, sprite_uv, vec2(textureSize(TEXTURE, 0)), stone_since, TIME, stone_linear);
	COLOR = vec4(mix(sprite.rgb, vec3(1.0), hit_flash * 0.8) * brightness, sprite.a);
}
