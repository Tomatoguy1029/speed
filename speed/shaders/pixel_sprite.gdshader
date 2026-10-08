shader_type canvas_item;
render_mode unshaded;

// INSTANCE_COLOR.r を被弾フラッシュに使う。素材本来の色を保持する。
varying float hit_flash;
void vertex() {
	hit_flash = COLOR.r;
}
void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	COLOR = vec4(mix(sprite.rgb, vec3(1.0), hit_flash * 0.8), sprite.a);
}
