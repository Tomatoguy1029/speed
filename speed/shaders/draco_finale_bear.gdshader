shader_type canvas_item;
render_mode unshaded, blend_add;
// りゅう座の決着で吠えるこぐま座。届いた絵は形と部位の重なりだけを読み、色は金の濃淡で塗り替える。
// 重なりが深いほど明るい金、ふちは淡い金。斜めに流れる光の筋と、まばらに瞬く点を乗せる。
// 決着の光の層（sRGB）へ足し、光の合成でにじませる。
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float time = 0.0;
uniform float strength = 0.6;
uniform vec4 deep : source_color = vec4(0.722, 0.392, 0.118, 1.0);
uniform vec4 amber : source_color = vec4(0.910, 0.584, 0.180, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.761, 0.302, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.843, 0.467, 1.0);
uniform vec4 pale : source_color = vec4(1.0, 0.957, 0.812, 1.0);
// 1コマの大きさ（絵のドット）
const float FRAME = 200.0;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	if (a < 0.05) discard;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 local = vec2(mod(px.x, FRAME), px.y);
	// 部位の重なり：1枚は0.85前後、2枚で0.97前後、3枚以上でほぼ1
	float depth = smoothstep(0.88, 0.96, a) + smoothstep(0.975, 0.995, a);
	vec4 n = texture(noise, local / 252.0 * 0.6);
	vec3 col = mix(deep.rgb, amber.rgb, smoothstep(0.25, 0.75, n.b));
	col = mix(col, gold.rgb, clamp(depth, 0.0, 1.0));
	col = mix(col, light.rgb, clamp(depth - 1.0, 0.0, 1.0));
	// ふち：上下左右のどれかが空いていれば淡い金
	float edge = 0.0;
	edge = max(edge, step(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a, 0.05));
	edge = max(edge, step(texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a, 0.05));
	edge = max(edge, step(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, 0.05));
	edge = max(edge, step(texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a, 0.05));
	col = mix(col, pale.rgb, edge * 0.8);
	// 斜めに流れる光の筋
	float sweep = fract((local.x * 0.8 + local.y * 0.6) / 260.0 - time * 0.45);
	float band = smoothstep(0.0, 0.06, sweep) * (1.0 - smoothstep(0.06, 0.16, sweep));
	col = mix(col, pale.rgb, band * 0.7);
	// まばらに瞬く点
	float h = texture(noise, (floor(local / 2.0) + 0.5) / 252.0).a;
	float twinkle = step(0.97, h) * pow(0.5 + 0.5 * sin(time * 5.0 + h * 80.0), 3.0);
	col = mix(col, vec3(1.0), twinkle);
	COLOR = vec4(col, a * COLOR.a * strength * (1.0 + 0.6 * edge + 0.8 * band + twinkle));
}
