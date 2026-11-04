// ピカロの共通の見た目（docs/game/bosses/draco.md 8.2）。元の敵の絵を、絵の画素ごとに「星空の窓」で塗り直す。
// 陰影を紫の段に置き換え、桃と青の星雲が中をゆっくり流れ、色つきの星がまたたく。縁は水色〜桃色に移ろって光る。
// morphing のときは、紫の塊（うねる円と回るこぶ）の距離場から敵の絵の距離場へ form で移す（生成の「星を吸い込んで育つ」）。
// ノイズは scripts/render/picaro_look.gd が実行時に一度だけ焼いたテクスチャを読む。光のにじみは後処理に任せる。
shader_type canvas_item;
render_mode unshaded;

uniform float boss_hit_white : hint_range(0.0, 0.28) = 0.0;
uniform float preview_clock = -1.0;
// R・G：なめらかな値ノイズ（8テクセルごとの格子）、B・A：テクセルごとのばらばらの値
uniform sampler2D noise_smooth : hint_default_black, filter_linear, repeat_enable;
uniform sampler2D noise_dots : hint_default_black, filter_nearest, repeat_enable;
// 余白つきの絵と同じ大きさの、敵の形の符号つき距離（中が負、画素単位）
uniform sampler2D form_field : hint_default_black, filter_nearest;
uniform bool morphing = false;
uniform float form : hint_range(0.0, 1.0) = 1.0;
uniform float jig = 0.0;
uniform float seed = 0.0;
uniform float blob_radius = 10.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

const vec3 VIOLET[6] = vec3[6](vec3(0.051, 0.031, 0.125), vec3(0.114, 0.078, 0.275), vec3(0.208, 0.165, 0.486), vec3(0.369, 0.322, 0.722), vec3(0.604, 0.549, 0.941), vec3(0.902, 0.878, 1.0));
const vec3 BLOB[6] = vec3[6](vec3(0.165, 0.047, 0.306), vec3(0.290, 0.102, 0.525), vec3(0.478, 0.184, 0.769), vec3(0.698, 0.361, 1.0), vec3(0.890, 0.722, 1.0), vec3(1.0));
const vec3 NEB_PINK = vec3(1.0, 0.435, 0.847);
const vec3 NEB_BLUE = vec3(0.310, 0.722, 1.0);
const vec3 NEB_CYAN = vec3(0.561, 0.941, 1.0);
const vec3 STAR[3] = vec3[3](vec3(1.0), vec3(0.624, 0.957, 1.0), vec3(1.0, 0.690, 0.941));

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

float alpha_at(vec2 pixel, vec2 texel) {
	return texture(TEXTURE, (pixel + 0.5) * texel).a;
}

// 形ができたピカロの色（p：絵の画素の位置）
vec3 formed_color(vec2 p, vec2 texel, float t, vec3 base, bool rim) {
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 color = VIOLET[min(4, int(floor(lum * 4.2)))];
	float neb = texture(noise_smooth, vec2(p.x * 0.11 + t * 0.33 + seed, p.y * 0.11 - t * 0.165) / 8.0).r;
	float neb2 = texture(noise_smooth, vec2(p.x * 0.07 - t * 0.14 + 2.8, p.y * 0.07 + t * 0.07 + seed * 0.35) / 8.0).g;
	color = mix(color, neb2 > 0.5 ? NEB_PINK : NEB_BLUE, smoothstep(0.45, 0.85, neb) * 0.55 * (0.4 + lum));
	vec4 dots = texture(noise_dots, (floor(p + vec2(t * 5.0 + seed * 7.0, -t * 2.5)) + 0.5) / 64.0);
	if (dots.b > 0.972) {
		float twinkle = 0.5 + 0.5 * sin(t * 7.0 + dots.a * 60.0);
		color = twinkle > 0.55 ? STAR[int(dots.a * 2.99)] : VIOLET[4];
	}
	if (rim) {
		float hue = 0.5 + 0.5 * sin(p.x * 0.25 + p.y * 0.18 + t * 2.2 + seed);
		color = mix(NEB_CYAN, NEB_PINK, hue);
		float pulse = 0.5 + 0.5 * sin(t * 4.0 + (p.x + p.y) * 0.25 + seed);
		if (pulse > 0.7) color = mix(color, VIOLET[5], 0.6);
	}
	return color;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 size = 1.0 / texel;
	vec2 p = floor(UV * size);
	float t = preview_clock >= 0.0 ? preview_clock : TIME;
	vec4 base = texture(TEXTURE, (p + 0.5) * texel);
	bool inside = base.a > 0.4;
	bool rim = inside && (alpha_at(p + vec2(-1.0, 0.0), texel) < 0.4 || alpha_at(p + vec2(1.0, 0.0), texel) < 0.4 || alpha_at(p + vec2(0.0, -1.0), texel) < 0.4 || alpha_at(p + vec2(0.0, 1.0), texel) < 0.4);
	vec3 color;
	if (!morphing) {
		if (!inside) discard;
		color = formed_color(p, texel, t, base.rgb, rim);
	} else {
		// 塊：うねる円に、回る3つのこぶをなめらかにつなぐ。押しつぶれと伸びで揺れる
		vec2 c = size * 0.5;
		float wobble = (1.0 - smoothstep(0.55, 1.0, form)) * (1.0 + jig);
		float squash = sin(t * 9.0) * 0.12 * wobble;
		vec2 q = (p + 0.5 - c) / vec2(1.0 + squash, 1.0 - squash);
		float angle = atan(q.y, q.x);
		float rho = length(q);
		float r0 = blob_radius;
		float blob = rho - r0 * (1.0 + 0.12 * sin(3.0 * angle + t * 6.0) + 0.035 * sin(5.0 * angle - t * 8.0) + 0.08 * sin(2.0 * angle + t * 4.0));
		for (int n = 0; n < 3; n++) {
			float fn = float(n);
			float a = t * (2.2 + fn * 0.7) + fn * 2.1;
			vec2 lobe = c + vec2(cos(a) * r0 * 0.55, sin(a * 1.3) * r0 * 0.45);
			float d = length(p + 0.5 - lobe) - r0 * (0.42 + 0.1 * sin(t * 5.0 + fn));
			float h = clamp(0.5 + 0.5 * (d - blob) / 6.0, 0.0, 1.0);
			blob = mix(d, blob, h) - 6.0 * h * (1.0 - h);
		}
		float target = texture(form_field, (p + 0.5) * texel).r;
		float field = mix(blob, target, smoothstep(0.0, 1.0, form)) + sin(p.x * 0.18 + t * 5.0) * cos(p.y * 0.16 - t * 4.5) * 0.7 * wobble;
		if (field > 0.0) discard;
		float depth = clamp(-field / (r0 * 0.55), 0.0, 1.0);
		float swirl = 0.5 + 0.5 * sin(angle * 3.0 + rho * 0.35 - t * 6.0);
		int level = depth < 0.12 ? 4 : depth < 0.3 ? 3 : swirl > 0.75 ? 3 : depth < 0.6 ? 2 : 1;
		color = BLOB[level];
		if (depth < 0.08 && swirl > 0.6) color = BLOB[5];
		float show = smoothstep(0.62, 1.0, form);
		if (show > 0.0 && inside) color = mix(color, formed_color(p, texel, t, base.rgb, rim), show);
	}
	color = mix(color, vec3(1.0), max(boss_hit_white, flash));
	COLOR = vec4(color, modulate.a);
}
