// ペルセウス座の目が開ききった瞬間の、画面全体の演出。画面に重ねる四角に描く。
// 目を中心に画面がブラーで引き込まれるように揺らぎ、一瞬だけ色がずれ（色収差）、蛇のようにうねる闇のオーラが画面の端まで一気に走って薄れる。
// オーラは蛇そのものではなく、うねる煙の帯。長さは画面のドット単位（cell_px で1ドットの画素数）。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 目の位置（四角の UV）と、目が開ききってからの秒
uniform vec2 center = vec2(0.5);
uniform float since = -1.0;
uniform vec2 rect_size = vec2(800.0, 450.0);
uniform float cell_px = 2.0;
// HDR の画面では、取り込んだ画面の色を sRGB へ戻して混ぜ、最後にリニアへ直す
uniform bool linear_output = false;
group_uniforms tuning;
uniform vec4 abyss = vec4(0.000910581, 0.008568126, 0.004024717, 1.0);
uniform vec4 murk = vec4(0.005181517, 0.059511238, 0.023153366, 1.0);
uniform vec4 moss = vec4(0.008023193, 0.274677312, 0.072271851, 1.0);
uniform vec4 venom = vec4(0.039546235, 0.708375780, 0.124771818, 1.0);
uniform float blur_strength : hint_range(0.0, 0.3, 0.005) = 0.12;
uniform float aberration : hint_range(0.0, 0.05, 0.001) = 0.012;
uniform float strands : hint_range(4.0, 16.0, 1.0) = 11.0;
group_uniforms;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	if (since < 0.0 || since > 1.6) discard;
	// ブラー：目の中心へ引き込むように、一瞬強くかかってすぐ戻る
	float pulse = smoothstep(0.0, 0.04, since) * exp(-3.5 * since);
	vec2 to_c = SCREEN_UV - center;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 10; i++) {
		sum += texture(screen_texture, SCREEN_UV - to_c * blur_strength * pulse * float(i) / 9.0).rgb;
	}
	vec3 col = sum / 10.0;
	if (linear_output) col = to_srgb(col);
	// 色収差：見開いた瞬間だけ、赤と青が目から外と内へずれる
	float split = aberration * exp(-16.0 * since) * smoothstep(0.0, 0.02, since);
	if (split > 0.0005) {
		vec3 out_r = texture(screen_texture, SCREEN_UV + to_c * split * 3.0).rgb;
		vec3 out_b = texture(screen_texture, SCREEN_UV - to_c * split * 3.0).rgb;
		if (linear_output) {out_r = to_srgb(out_r);out_b = to_srgb(out_b);}
		col.r = mix(col.r, out_r.r, 0.85);
		col.b = mix(col.b, out_b.b, 0.85);
	}
	// オーラ：目からうねりながら外へ走る闇の帯。先端は速く伸び、根元から薄れる
	vec2 cell = floor(UV * rect_size / cell_px) + 0.5;
	vec2 cc = floor(center * rect_size / cell_px) + 0.5;
	vec2 d = cell - cc;
	float r = length(d);
	float a = atan(d.y, d.x);
	float front = (1.0 - exp(-3.2 * since)) * length(rect_size / cell_px) * 0.62;
	float fade = 1.0 - smoothstep(0.5, 1.6, since);
	float aura = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		if (fi >= strands) break;
		float base = fi / strands * 6.2831853 + (hash(fi) - 0.5) * 0.6;
		float wave = sin(r * 0.06 - since * 5.0 + hash(fi + 3.0) * 6.28) * 0.35 + sin(r * 0.13 + hash(fi + 5.0) * 6.28) * 0.12;
		float da = mod(a - base - wave * smoothstep(0.0, 40.0, r) + 3.14159265, 6.2831853) - 3.14159265;
		float lateral = abs(da) * r;
		float tip = clamp(r / max(front, 1.0), 0.0, 1.0);
		if (r > front) continue;
		float smoke = vnoise(vec3(cell * 0.06 + vec2(since * 2.0, 0.0), fi));
		float width = mix(14.0, 3.0, tip) * (0.7 + 0.6 * smoke);
		float k = 1.0 - lateral / width;
		if (k > 0.0) {
			aura = max(aura, k);
			rim = max(rim, k < 0.3 ? 1.0 - k / 0.3 : 0.0);
		}
	}
	aura = floor(aura * 4.0) / 4.0 * fade;
	if (aura > 0.0) {
		vec3 dark = mix(abyss.rgb, murk.rgb, 0.4);
		col = mix(col, dark, aura * 0.8);
		// 細い縁と交差部を保ち、うねる煙の面だけを濃い緑で塗る。
		float body_mask = (1.0 - smoothstep(0.0, 0.12, rim)) * aura * fade;
		col = mix(col, mix(moss.rgb, venom.rgb, 0.28), body_mask);
		col = mix(col, moss.rgb, (aura * 0.25 + rim * 0.45) * fade);
		col = mix(col, venom.rgb, rim * rim * 0.3 * fade);
	}
	if (pulse < 0.01 && aura <= 0.0 && split <= 0.0005) discard;
	COLOR = vec4(linear_output ? to_linear(col) : col, 1.0);
}
