// ふたご座の分裂：光の機体（本物の機体。ここでは描かない）から、影の機体が横へ離れていき、間の物質が粘って伸び、
// 穴があいて糸だけが残り、糸が順にちぎれる。四角は光の機体の絵の左上を原点に、横へ sep セル離れた影の機体までを覆う。
// 粘りは2つの機体の形を滑らかにつないだ形（smin）で、つなぎの幅 join が縮むほど首が細くなる。
// 穴は離れる向きに長い（横に引き伸ばした）ノイズで開けるので、残る部分が横向きの糸になる。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/hero_gemini.gdshaderinc"

uniform float sep = 0.0;
uniform float join = 18.0;
// 穴の開き具合（0〜1）と、糸のちぎれ具合（0〜1。1 で何も残らない）
uniform float holes = 0.0;
uniform float cut = 0.0;
uniform float seed = 0.0;
uniform float shadow_strength = 1.0;

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

void fragment() {
	vec2 size = vec2(sep + SHIP.x + 2.0 * PAD, SHIP.y + 2.0 * PAD);
	vec2 cell = floor(UV * size) - PAD;
	vec2 offset = vec2(sep, 0.0);
	if (ship_at(cell).a >= 0.5) discard;
	vec4 c = shadow_body(cell - offset, seed, 0.0);
	if (c.a <= 0.0) {
		float da = ship_dist(cell), db = ship_dist(cell - offset);
		float t = clamp((cell.x - SHIP.x * 0.5) / max(sep, 1.0), 0.0, 1.0);
		float d = smin(da, db, max(join, 0.01));
		bool between = cell.x > SHIP.x * 0.5 && cell.x < sep + SHIP.x * 0.5;
		if (between && d < 0.5 && cut < 1.0) {
			float mid = 1.0 - abs(2.0 * t - 1.0);
			// 揺れながら伸びる膜の穴。中ほどほど先に開く
			float n = vnoise(vec3(cell.x * 0.07 - time * 0.4, cell.y * 0.34, seed));
			float th = holes * (0.3 + 0.9 * mid) + cut * 1.25 * (0.6 + 0.4 * mid);
			if (n >= th) {
				vec3 col = mix(LIGHT_MID, SHADOW_BODY, smoothstep(0.1, 0.9, t));
				// 膜のふちと穴のふちは、粘る物質のつやで明るくする
				if (d > -0.9 || n < th + 0.045) col = t < 0.5 ? LIGHT_CORE : SHADOW_RIM;
				c = vec4(col, 0.95);
			}
		}
		if (c.a <= 0.0) c = shadow_aura(cell - offset, seed, shadow_strength);
	}
	if (c.a <= 0.001) discard;
	COLOR = finish(c);
}
