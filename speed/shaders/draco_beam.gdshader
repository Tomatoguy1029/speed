shader_type canvas_item;
render_mode unshaded;

// りゅう座の吐き出しの光線。口元の光の溜めと、口から伸びる光線をピクセルの升目で描く。
// 頂点の色で描き方を渡す：r = 0 溜め／1 光線、g = 強さ（溜めの進み・光線の消え方）、b = 個体ごとのずれ。
// UV は口を原点とした光線の座標（×1000）。x が光線の向き、y が横。
// 光のにじみは後処理が担当するので、ここでは明るさだけを出す。

uniform bool linear_colors = false;
// 作っておいたノイズ画像を使い回す（毎フレーム計算しない）
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float half0 = 40.0;
uniform float beam_len = 1800.0;
uniform float clock = 0.0;
uniform float pixel = 3.0;
uniform vec3 tint = vec3(0.83, 0.73, 1.0);
uniform float opacity = 1.0;

group_uniforms tuning;
uniform float core_ratio : hint_range(0,1,0.01) = 0.3;
uniform float mid_ratio : hint_range(0,1,0.01) = 0.62;
uniform float pale_mix : hint_range(0,1,0.05) = 0.55;
uniform float core_emission : hint_range(0,4,0.05) = 1.2;
uniform float spark_emission : hint_range(0,4,0.05) = 0.8;
uniform float rim_opacity : hint_range(0,1,0.01) = 0.92;
uniform float haze_opacity : hint_range(0,1,0.01) = 0.38;
uniform float width_wobble : hint_range(0,1,0.05) = 0.2;
uniform float width_frequency : hint_range(0.0001,0.02,0.0001) = 0.0015;
uniform float width_speed : hint_range(0,8,0.1) = 1.6;
uniform float haze_width : hint_range(1,1.6,0.05) = 1.45;
uniform float haze_noise_x : hint_range(0.0001,0.04,0.0001) = 0.004;
uniform float haze_noise_y : hint_range(0.001,0.08,0.001) = 0.01;
uniform float haze_speed : hint_range(0,10,0.1) = 2.4;
uniform float haze_threshold : hint_range(0,1,0.01) = 0.6;
uniform float streak_noise_x : hint_range(0.0001,0.04,0.0001) = 0.003;
uniform float streak_noise_y : hint_range(0.001,0.08,0.001) = 0.012;
uniform float streak_speed : hint_range(0,12,0.1) = 3.5;
uniform float streak_threshold : hint_range(0,1,0.01) = 0.74;
uniform float orb_reach : hint_range(0.5,2.8,0.05) = 2.6;
uniform float orb_start : hint_range(0.05,1.4,0.05) = 0.25;
uniform float orb_growth : hint_range(0,1.4,0.05) = 0.7;
uniform float orb_core_ratio : hint_range(0,1,0.01) = 0.42;
uniform float orb_mid_ratio : hint_range(0,1,0.01) = 0.72;
uniform float orb_ring_shrink : hint_range(0,1,0.05) = 0.8;
uniform float orb_spark_speed : hint_range(0,8,0.1) = 1.6;
uniform float orb_spark_threshold : hint_range(0,1,0.01) = 0.76;
group_uniforms;

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float noise(vec2 at) {
	return texture(noise_tex, at).r;
}

void fragment() {
	vec3 raw = linear_colors ? to_srgb(COLOR.rgb) : COLOR.rgb;
	float mode = raw.r;
	float strength = raw.g;
	float seed = raw.b;
	vec2 p = (floor(UV * 1000.0 / pixel) + 0.5) * pixel;
	vec3 deep = tint * vec3(0.55, 0.42, 0.95);
	vec3 pale = mix(tint, vec3(1.0), pale_mix);
	float core = 0.0;
	float mid = 0.0;
	float rim = 0.0;
	float haze = 0.0;
	float spark = 0.0;
	if (mode < 0.5) {
		// 口元に光が集まる。外から内へ縮む輪と、中心へ吸い寄せられる光の粒。
		float r = length(p);
		float reach = half0 * orb_reach;
		float orb = half0 * (orb_start + orb_growth * strength);
		core = step(r, orb * orb_core_ratio);
		mid = step(r, orb * orb_mid_ratio);
		rim = step(r, orb);
		float ring_r = reach * (1.0 - strength * orb_ring_shrink);
		float ring = step(abs(r - ring_r), pixel * 0.6) * step(0.35, noise(vec2(atan(p.y, p.x) * 0.6 + seed, 0.37)));
		float angle = atan(p.y, p.x) / 6.2831853;
		float fall = noise(vec2(angle * 5.0 + seed, r / reach * 0.8 + clock * orb_spark_speed));
		spark = max(ring, step(orb_spark_threshold, fall) * step(orb, r) * step(r, reach) * (1.0 - r / reach) * 1.4);
	} else {
		if (p.x < 0.0) discard;
		float y = abs(p.y);
		// 口元で細く、先へ向かって太くなる。縁はノイズで揺らぐ。
		float flare = smoothstep(0.0, half0 * 3.0, p.x);
		float width = half0 * (0.38 + 0.62 * flare);
		width *= (1.0 - width_wobble * 0.5) + width_wobble * noise(vec2(p.x * width_frequency - clock * width_speed, seed));
		// 先端は丸く閉じる
		float cap_from = beam_len - width;
		if (p.x > cap_from) width *= sqrt(max(0.0, 1.0 - pow((p.x - cap_from) / max(width, 1.0), 2.0)));
		float d = y / max(width, 0.001);
		core = step(d, core_ratio);
		mid = step(d, mid_ratio);
		rim = step(d, 1.0);
		float edge = step(abs(d - 1.0), pixel / max(width, 1.0));
		float drift = noise(vec2(p.x * haze_noise_x - clock * haze_speed, y * haze_noise_y + seed));
		haze = step(d, haze_width) * step(haze_threshold, drift) * (1.0 - rim);
		// 光線の中を口から先へ流れる光の筋
		float flow = noise(vec2(p.x * streak_noise_x - clock * streak_speed, p.y * streak_noise_y + seed));
		spark = max(step(streak_threshold, flow) * mid * (1.0 - core), edge * 0.6);
		// 口元は撃ち出しの光で明るくする
		core = max(core, step(p.x, half0 * 1.2) * step(d, 0.7));
	}
	vec3 color = deep;
	color = mix(color, tint, mid);
	color = mix(color, pale, spark);
	color = mix(color, vec3(1.0), core);
	float emission = 1.0 + core * core_emission + spark * spark_emission;
	float alpha = max(max(rim * rim_opacity, haze * haze_opacity), spark) * strength;
	COLOR = vec4(color * emission, alpha * opacity);
}
