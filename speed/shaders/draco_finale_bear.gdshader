shader_type canvas_item;
render_mode unshaded;
// りゅう座の決着で吠えるこぐま座。体の中は琥珀から金へ流れる星雲に、まばらな星が瞬く。上ほど明るく、奥の後ろ脚は暗い。
// 外側のふちだけを淡い金に光らせる。絵は ursa_minor_parts.png（R：後ろ脚、G：ふちまでの距離÷8、B：上下の高さ、A：形）で受ける。
// ノイズは焼いた boss_finish_noise.png を読む。色は sRGB で求め、HDR の画面ではリニアへ直す。
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float time = 0.0;
uniform bool linear_output = false;
uniform vec4 deep = vec4(0.420, 0.180, 0.047, 1.0);
uniform vec4 amber = vec4(0.722, 0.392, 0.118, 1.0);
uniform vec4 gold = vec4(0.941, 0.659, 0.227, 1.0);
uniform vec4 light = vec4(1.0, 0.843, 0.467, 1.0);
uniform vec4 star = vec4(1.0, 0.965, 0.863, 1.0);
uniform vec4 rim = vec4(1.0, 0.945, 0.769, 1.0);
// 1コマの幅（絵のドット）と、ノイズの1周（ドット）
const float FRAME = 200.0;
const float NOISE = 252.0;

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
// HDR の画面では絵とノイズがリニアで読めるので、焼いた値へ戻す
vec4 baked(vec4 c) { return linear_output ? vec4(to_srgb(c.rgb), c.a) : c; }

float nebula(vec2 at) {
	return baked(texture(noise, (at + 0.5) / NOISE)).b;
}

void fragment() {
	vec4 part = baked(texture(TEXTURE, UV));
	if (part.a < 0.5) discard;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = vec2(mod(px.x, FRAME), px.y);
	vec2 p = local * 0.16;
	float n = nebula(p + vec2(time * 1.2, 40.0)) * 0.65 + nebula(p * 1.9 + vec2(90.0 - time * 1.8, time * 0.6)) * 0.35;
	float v = clamp(n * 0.75 + part.b * 0.45 - 0.1, 0.0, 1.0);
	vec3 col = mix(deep.rgb, amber.rgb, smoothstep(0.2, 0.5, v));
	col = mix(col, gold.rgb, smoothstep(0.45, 0.75, v));
	col = mix(col, light.rgb, smoothstep(0.72, 0.95, v));
	col = floor(col * 20.0) / 20.0;
	float h = texelFetch(noise, ivec2(mod(local, NOISE)), 0).a;
	float twinkle = 0.5 + 0.5 * sin(time * 4.0 + h * 60.0);
	if (h > 0.988) col = mix(col, star.rgb, 0.55 + 0.45 * twinkle);
	else if (h > 0.978) col = mix(col, star.rgb, 0.35);
	col *= mix(1.0, 0.55, step(0.5, part.r));
	col = mix(col, rim.rgb, clamp(exp(-(part.g * 8.0 - 1.0) / 1.6) * 0.85, 0.0, 1.0));
	COLOR = vec4(linear_output ? to_linear(col) : col, 0.94 * COLOR.a);
}
