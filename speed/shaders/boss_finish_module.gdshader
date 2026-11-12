shader_type canvas_item;
render_mode unshaded;
// 獲得の場面の伝説のモジュール。白く焼けた影から色が出て、光沢がひとすじ横切る。
uniform bool linear_output = false;
uniform float hot = 0.0;
uniform float gloss = -1.0;
uniform vec2 art_size = vec2(64.0);

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	if (art.a < 0.04) discard;
	vec3 rgb = linear_output ? to_srgb(art.rgb) : art.rgb;
	vec3 white = vec3(1.0, 242.0 / 255.0, 200.0 / 255.0);
	rgb += white * hot;
	if (gloss > 0.0 && gloss < 1.0) {
		vec2 local = UV * art_size - art_size * 0.5;
		float gh = art_size.y * 0.6, gx = mix(-art_size.x, art_size.x, gloss), s = (local.y + gh) / (2.0 * gh);
		if (local.x >= gx - 7.0 - 18.0 * s && local.x <= gx + 5.0 - 18.0 * s) rgb += white * 0.75 * sin(gloss * PI);
	}
	rgb = min(rgb, vec3(1.0));
	COLOR = vec4(linear_output ? to_linear(rgb) : rgb, art.a);
}
