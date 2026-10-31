// ドット単位の爆発（自爆する雑魚・機雷）。閃光・火球・衝撃波の輪・煙・燃えかす・火の粉を1枚の四角に描く。
// 火球は fire_burst と同じく、焼いた値ノイズで縁を崩し、密度で4段の色に分け、一番外を半透明にする。
// 長さはドット単位、時間は秒。粒の並びは seed から決まり、age だけで各時刻の絵が決まる。
// tuning の値は戦闘エフェクトツールで装備・攻撃ごとに上書きする（ShaderTuning）。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D value_noise : repeat_disable, filter_nearest;
uniform float half_cells = 120.0;
uniform float radius = 38.0;
uniform float age = 0.0;
// 爆発の中心のドット座標と種（ノイズと粒の並びを爆発ごとに変える）
uniform vec2 origin = vec2(0.0);
uniform float seed = 0.0;
group_uniforms tuning;
uniform vec4 c0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 c1 : source_color = vec4(1.0, 0.949, 0.659, 1.0);
uniform vec4 c2 : source_color = vec4(1.0, 0.690, 0.188, 1.0);
uniform vec4 c3 : source_color = vec4(0.824, 0.275, 0.110, 1.0);
uniform vec4 smoke_dark : source_color = vec4(0.227, 0.165, 0.173, 1.0);
uniform vec4 smoke_mid : source_color = vec4(0.369, 0.275, 0.267, 1.0);
uniform vec4 smoke_light : source_color = vec4(0.541, 0.416, 0.369, 1.0);
uniform float noise_scale : hint_range(0.04, 0.5, 0.01) = 0.16;
uniform float roughness : hint_range(0.0, 2.0, 0.05) = 0.95;
uniform float outer_alpha : hint_range(0.0, 1.0, 0.05) = 0.5;
uniform float grow_seconds : hint_range(0.05, 0.6, 0.01) = 0.2;
uniform float start_size : hint_range(0.0, 1.0, 0.05) = 0.25;
uniform float fire_seconds : hint_range(0.2, 2.0, 0.05) = 0.75;
uniform float burn_speed : hint_range(0.0, 3.0, 0.05) = 0.85;
uniform float cool_speed : hint_range(0.0, 3.0, 0.05) = 0.8;
uniform float hole_size : hint_range(0.0, 0.9, 0.05) = 0.65;
uniform float flash_seconds : hint_range(0.0, 0.2, 0.01) = 0.04;
uniform float flash_size : hint_range(0.0, 1.5, 0.05) = 0.5;
uniform float ring_seconds : hint_range(0.05, 1.0, 0.01) = 0.3;
uniform float ring_size : hint_range(0.0, 2.5, 0.05) = 1.25;
uniform float ring_alpha : hint_range(0.0, 1.0, 0.05) = 0.95;
uniform float spark_count : hint_range(0.0, 64.0, 1.0) = 40.0;
uniform float spark_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float spark_seconds : hint_range(0.1, 1.5, 0.05) = 0.5;
uniform float cinder_count : hint_range(0.0, 96.0, 1.0) = 60.0;
uniform float cinder_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float cinder_seconds : hint_range(0.1, 1.5, 0.05) = 0.7;
uniform float smoke_count : hint_range(0.0, 24.0, 1.0) = 13.0;
uniform float smoke_alpha : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform float smoke_seconds : hint_range(0.1, 2.0, 0.05) = 0.8;
group_uniforms;

const int MAX_SPARKS = 64;
const int MAX_CINDERS = 96;
const int MAX_SMOKE = 24;

float lattice(vec3 p) {
	vec3 i = mod(p, 64.0);
	vec2 tile = vec2(mod(i.z, 8.0), floor(i.z / 8.0));
	return texture(value_noise, (tile * 64.0 + i.xy + 0.5) / 512.0).r;
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(lattice(i), lattice(i + vec3(1, 0, 0)), u.x), mix(lattice(i + vec3(0, 1, 0)), lattice(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(lattice(i + vec3(0, 0, 1)), lattice(i + vec3(1, 0, 1)), u.x), mix(lattice(i + vec3(0, 1, 1)), lattice(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

// 粒 i の k 番目の乱数（0〜1）
float rnd(float i, float k) {
	return fract(sin(dot(vec3(i, k, seed), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// 下に重ねた色の上へ、色 c を不透明度 a で重ねる
vec4 over(vec4 dst, vec3 c, float a) {
	float out_a = a + dst.a * (1.0 - a);
	if (out_a <= 0.0) return vec4(0.0);
	return vec4((c * a + dst.rgb * dst.a * (1.0 - a)) / out_a, out_a);
}

float out_quart(float t) { return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 4.0); }
float out_cubic(float t) { return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 3.0); }

// 減速しながら飛ぶ粒の、t 秒までに進んだ距離（抵抗は毎秒 0.6）
float drift(float v0, float t) { return v0 * (1.0 - exp(-0.6 * t)) / 0.6; }

void fragment() {
	vec2 cell = floor((UV - 0.5) * 2.0 * half_cells);
	vec2 p = cell + 0.5;
	float dist = length(p);
	float R = max(radius, 1.0);
	// 今の時刻に何かが届く距離より外は描かない
	float reach = R * 1.7;
	if (age < spark_seconds + 0.06) reach = max(reach, R * 0.16 + drift(R * 6.6 * spark_speed, age) + 17.0);
	if (age < ring_seconds) reach = max(reach, R * (0.21 + ring_size) + 3.0);
	if (dist > reach) discard;
	vec4 col = vec4(0.0);

	// 煙：火球の中に散らした塊が、少し広がりながら薄れる。火の後ろに描く
	if (age > 0.12) {
		for (int j = 0; j < MAX_SMOKE; j++) {
			float i = float(j);
			if (i >= smoke_count) break;
			float t0 = mix(0.12, 0.3, rnd(i, 21.0));
			float span = mix(0.75, 1.0, rnd(i, 22.0)) * smoke_seconds;
			float u = (age - t0) / span;
			if (u <= 0.0 || u >= 1.0) continue;
			float a = rnd(i, 23.0) * TAU;
			vec2 dir = vec2(cos(a), sin(a));
			vec2 v = vec2(dir.x * mix(4.0, 12.0, rnd(i, 24.0)), dir.y * mix(4.0, 12.0, rnd(i, 25.0)) - mix(1.0, 4.0, rnd(i, 26.0))) / 38.0 * R;
			vec2 c = dir * mix(0.25, 0.8, rnd(i, 27.0)) * R + v * u * span;
			float r = mix(10.0, 15.0, rnd(i, 28.0)) / 38.0 * R * (0.7 + 0.6 * out_cubic(u));
			float k = smoke_alpha * pow(1.0 - u, 1.3) * smoothstep(0.0, 0.2, u);
			if (length(p - c) <= r) col = over(col, smoke_dark.rgb, k);
			if (length(p - c + vec2(0.2, 0.25) * r) <= r * 0.75) col = over(col, smoke_mid.rgb, k * 0.55);
			if (length(p - c + vec2(0.35, 0.4) * r) <= r * 0.4) col = over(col, smoke_light.rgb, k * 0.35);
		}
	}

	// 火球：速く膨らみ、密度の山が中心から外へ動いて輪になり、冷えて途切れる
	float life = age / fire_seconds;
	if (life < 1.0) {
		float rt = R * (start_size + (1.0 - start_size) * out_quart(age / grow_seconds));
		float d = length(cell) / max(rt, 0.1);
		if (d <= 1.2) {
			vec2 at = cell + origin;
			float n = vnoise(vec3(at.x * noise_scale + seed, at.y * noise_scale - life * 3.0, life * 5.0 + seed));
			float hole = hole_size * smoothstep(0.15, 0.6, life);
			float den = (1.0 - abs(d - hole) / (1.0 - hole * 0.6)) * 1.35 + (n - 0.5) * roughness - life * burn_speed - smoothstep(0.35, 1.0, life) * cool_speed;
			if (age < flash_seconds) den += 0.6;
			if (den > 0.8) col = over(col, c0.rgb, c0.a);
			else if (den > 0.55) col = over(col, c1.rgb, c1.a);
			else if (den > 0.33) col = over(col, c2.rgb, c2.a);
			else if (den > 0.16) col = over(col, c3.rgb, c3.a * outer_alpha);
		}
	}

	// 閃光：最初の数フレームだけ白い円
	if (age < flash_seconds && dist <= R * 0.16 + R * flash_size * age / flash_seconds) col = over(col, c0.rgb, c0.a);

	// 衝撃波の輪：火球の外を速く走り、ノイズで途切れて半透明で消える
	float ru = age / ring_seconds;
	if (ru < 1.0) {
		float rr = R * (0.21 + ring_size * out_cubic(ru));
		float w = ru < 0.4 ? 2.0 : 1.0;
		if (abs(dist - rr) <= w && vnoise(vec3(p * 0.25 + seed, ru * 3.0 + 9.0)) >= 0.2 + ru * 0.5)
			col = over(col, ru < 0.3 ? c0.rgb : c1.rgb, ring_alpha * (ru < 0.5 ? 1.0 : 0.58));
	}

	// 燃えかす：火の輪の上から出て、ゆっくり外へ流れながら冷え、最後は点滅して消える
	if (age > 0.18 * fire_seconds / 0.75) {
		for (int j = 0; j < MAX_CINDERS; j++) {
			float i = float(j);
			if (i >= cinder_count) break;
			float t0 = mix(0.24, 0.67, rnd(i, 31.0)) * fire_seconds;
			float span = mix(0.43, 1.0, rnd(i, 32.0)) * cinder_seconds;
			float k = (age - t0) / span;
			if (k <= 0.0 || k >= 1.0) continue;
			if (k > 0.6 && sin(age * 40.0 + rnd(i, 33.0) * 9.0) < 0.0) continue;
			float a = rnd(i, 34.0) * TAU;
			float r0 = mix(0.55, 1.05, rnd(i, 35.0)) * R * (0.6 + 0.4 * smoothstep(0.15, 0.6, t0 / fire_seconds));
			float r = r0 + mix(6.0, 22.0, rnd(i, 36.0)) / 38.0 * R * cinder_speed * k * span;
			vec2 at = floor(vec2(cos(a), sin(a)) * r);
			vec3 c = k < 0.3 ? c0.rgb : k < 0.65 ? c1.rgb : c2.rgb;
			bool big = rnd(i, 37.0) < 0.5 && k < 0.6;
			if (cell == at || (big && cell == at + vec2(1.0, 0.0))) col = over(col, c, 1.0);
			else if (big && cell == at + vec2(0.0, 1.0)) col = over(col, c2.rgb, 1.0);
		}
	}

	// 火の粉：外へ飛んで減速する短い筋。頭が明るく、尾は暗い。最後は薄れて消える
	if (age < spark_seconds + 0.06) {
		for (int j = 0; j < MAX_SPARKS; j++) {
			float i = float(j);
			if (i >= spark_count) break;
			float t = age - rnd(i, 41.0) * 0.06;
			float span = mix(0.4, 1.0, rnd(i, 42.0)) * spark_seconds;
			if (t < 0.0 || t >= span) continue;
			float a = rnd(i, 43.0) * TAU;
			vec2 dir = vec2(cos(a), sin(a));
			float v0 = R * mix(2.4, 6.6, rnd(i, 44.0)) * spark_speed;
			vec2 head = dir * (R * 0.16 + drift(v0, t));
			float len = min(16.0, 0.5 + v0 * exp(-0.6 * t) * 0.026) * mix(0.7, 1.4, rnd(i, 45.0));
			vec2 rel = p - head;
			float along = dot(rel, dir);
			if (along > 0.5 || along < -len || abs(rel.x * dir.y - rel.y * dir.x) > 0.55) continue;
			float k = 1.0 - t / span;
			float pick = rnd(i, 46.0);
			vec3 c = pick < 0.25 ? c0.rgb : pick < 0.75 ? c1.rgb : c2.rgb;
			if (along < -len * 0.4) c *= 0.55;
			col = over(col, c, k < 0.35 ? k / 0.35 : 1.0);
		}
	}

	if (col.a <= 0.0) discard;
	COLOR = col;
}
