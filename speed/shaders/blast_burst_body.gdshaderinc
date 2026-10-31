// 共通の爆発計算。artist値のuniform宣言と所有は各専用shaderに置く。
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

// 煙の中心・半径・不透明度。従来と同じ乱数と軌道を、粒の4頂点で求める。
vec4 smoke_state(float i) {
	if (i >= smoke_count || age <= 0.12) return vec4(0.0);
	float R = max(radius, 1.0);
	float t0 = mix(0.12, 0.3, rnd(i, 21.0));
	float span = mix(0.75, 1.0, rnd(i, 22.0)) * smoke_seconds;
	float u = (age - t0) / span;
	if (u <= 0.0 || u >= 1.0) return vec4(0.0);
	float a = rnd(i, 23.0) * TAU;
	vec2 dir = vec2(cos(a), sin(a));
	vec2 v = vec2(dir.x * mix(4.0, 12.0, rnd(i, 24.0)), dir.y * mix(4.0, 12.0, rnd(i, 25.0)) - mix(1.0, 4.0, rnd(i, 26.0))) / 38.0 * R;
	vec2 c = dir * mix(0.25, 0.8, rnd(i, 27.0)) * R + v * u * span;
	float r = mix(10.0, 15.0, rnd(i, 28.0)) / 38.0 * R * (0.7 + 0.6 * out_cubic(u));
	float k = smoke_alpha * pow(1.0 - u, 1.3) * smoothstep(0.0, 0.2, u);
	return vec4(c, r, k);
}

// 燃えかすの左上のセル・寿命比・大きさ。非表示の粒は寿命比を負にする。
vec4 cinder_state(float i) {
	if (i >= cinder_count || age <= 0.18 * fire_seconds / 0.75) return vec4(0.0, 0.0, -1.0, 0.0);
	float R = max(radius, 1.0);
	float t0 = mix(0.24, 0.67, rnd(i, 31.0)) * fire_seconds;
	float span = mix(0.43, 1.0, rnd(i, 32.0)) * cinder_seconds;
	float k = (age - t0) / span;
	if (k <= 0.0 || k >= 1.0) return vec4(0.0, 0.0, -1.0, 0.0);
	if (k > 0.6 && sin(age * 40.0 + rnd(i, 33.0) * 9.0) < 0.0) return vec4(0.0, 0.0, -1.0, 0.0);
	float a = rnd(i, 34.0) * TAU;
	float r0 = mix(0.55, 1.05, rnd(i, 35.0)) * R * (0.6 + 0.4 * smoothstep(0.15, 0.6, t0 / fire_seconds));
	float r = r0 + mix(6.0, 22.0, rnd(i, 36.0)) / 38.0 * R * cinder_speed * k * span;
	vec2 at = floor(vec2(cos(a), sin(a)) * r);
	return vec4(at, k, rnd(i, 37.0) < 0.5 && k < 0.6 ? 1.0 : 0.0);
}

// 火の粉の頭・向き、長さ・不透明度、色。
void spark_state(float i, out vec4 state, out vec4 extra, out vec4 color) {
	state = vec4(0.0);
	extra = vec4(0.0);
	color = vec4(0.0);
	if (i >= spark_count || age >= spark_seconds + 0.06) return;
	float t = age - rnd(i, 41.0) * 0.06;
	float span = mix(0.4, 1.0, rnd(i, 42.0)) * spark_seconds;
	if (t < 0.0 || t >= span) return;
	float R = max(radius, 1.0);
	float a = rnd(i, 43.0) * TAU;
	vec2 dir = vec2(cos(a), sin(a));
	float v0 = R * mix(2.4, 6.6, rnd(i, 44.0)) * spark_speed;
	vec2 head = dir * (R * 0.16 + drift(v0, t));
	float len = min(16.0, 0.5 + v0 * exp(-0.6 * t) * 0.026) * mix(0.7, 1.4, rnd(i, 45.0));
	float k = 1.0 - t / span;
	float pick = rnd(i, 46.0);
	state = vec4(head, dir);
	extra = vec4(len, k < 0.35 ? k / 0.35 : 1.0, 0.0, 0.0);
	color = vec4(pick < 0.25 ? c0.rgb : pick < 0.75 ? c1.rgb : c2.rgb, 1.0);
}

void vertex() {
	float R = max(radius, 1.0);
	max_reach = R * 1.7;
	if (age < spark_seconds + 0.06) max_reach = max(max_reach, R * 0.16 + drift(R * 6.6 * spark_speed, age) + 17.0);
	if (age < ring_seconds) max_reach = max(max_reach, R * (0.21 + ring_size) + 3.0);
	particle_state = vec4(0.0);
	particle_extra = vec4(0.0);
	particle_color = vec4(0.0);
	if (pass_mode == 0) {
		// 火球の四角を火の粉の最大到達距離まで広げない。
		float core_reach = 0.0;
		if (age < fire_seconds) core_reach = R * (start_size + (1.0 - start_size) * out_quart(age / grow_seconds)) * 1.2 + 1.0;
		if (age < flash_seconds) core_reach = max(core_reach, R * 0.16 + R * flash_size * age / flash_seconds);
		if (age < ring_seconds) {
			float ru = age / ring_seconds;
			core_reach = max(core_reach, R * (0.21 + ring_size * out_cubic(ru)) + (ru < 0.4 ? 2.0 : 1.0));
		}
		float bound = min(half_cells, ceil(core_reach));
		burst_position = (UV - 0.5) * 2.0 * bound;
		VERTEX = burst_position / half_cells;
	} else {
		// UV.x は粒番号 * 2 + 四角内の x。全頂点で同じ粒番号を復元する。
		float i = floor(UV.x * 0.5);
		vec2 corner = vec2(UV.x - i * 2.0, UV.y);
		vec2 low = vec2(0.0);
		vec2 high = vec2(0.0);
		if (pass_mode == 1) {
			particle_state = smoke_state(i);
			if (particle_state.w > 0.0) {
				low = floor(particle_state.xy - particle_state.z - 1.0);
				high = ceil(particle_state.xy + particle_state.z + 1.0);
			}
		} else if (pass_mode == 2) {
			particle_state = cinder_state(i);
			if (particle_state.z > 0.0) {
				low = particle_state.xy;
				high = low + vec2(2.0);
			}
		} else {
			// varying は vertex 本体で代入する。
			vec4 state;
			vec4 extra;
			vec4 color;
			spark_state(i, state, extra, color);
			particle_state = state;
			particle_extra = extra;
			particle_color = color;
			if (extra.y > 0.0) {
				vec2 tail = state.xy - state.zw * extra.x;
				low = floor(min(state.xy, tail) - 2.0);
				high = ceil(max(state.xy, tail) + 2.0);
			}
		}
		// 元の四角の範囲とセルの格子を保つ。非表示の粒は面積ゼロ。
		low = clamp(low, vec2(-half_cells), vec2(half_cells));
		high = clamp(high, vec2(-half_cells), vec2(half_cells));
		burst_position = mix(low, high, corner);
		VERTEX = burst_position / half_cells;
	}
}

void fragment() {
	vec2 cell = floor(burst_position);
	vec2 p = cell + 0.5;
	float dist = length(p);
	if (dist > max_reach) discard;
	float R = max(radius, 1.0);
	vec4 col = vec4(0.0);
	if (pass_mode == 1) {
		vec2 c = particle_state.xy;
		float r = particle_state.z;
		float k = particle_state.w;
		if (length(p - c) <= r) col = over(col, smoke_dark.rgb, k);
		if (length(p - c + vec2(0.2, 0.25) * r) <= r * 0.75) col = over(col, smoke_mid.rgb, k * 0.55);
		if (length(p - c + vec2(0.35, 0.4) * r) <= r * 0.4) col = over(col, smoke_light.rgb, k * 0.35);
	} else if (pass_mode == 2) {
		vec2 at = particle_state.xy;
		float k = particle_state.z;
		bool big = particle_state.w > 0.5;
		vec3 c = k < 0.3 ? c0.rgb : k < 0.65 ? c1.rgb : c2.rgb;
		if (cell == at || (big && cell == at + vec2(1.0, 0.0))) col = vec4(c, 1.0);
		else if (big && cell == at + vec2(0.0, 1.0)) col = vec4(c2.rgb, 1.0);
	} else if (pass_mode == 3) {
		vec2 dir = particle_state.zw;
		vec2 rel = p - particle_state.xy;
		float along = dot(rel, dir);
		float len = particle_extra.x;
		if (along > 0.5 || along < -len || abs(rel.x * dir.y - rel.y * dir.x) > 0.55) discard;
		vec3 c = particle_color.rgb;
		if (along < -len * 0.4) c *= 0.55;
		col = vec4(c, particle_extra.y);
	} else {
		// 火球：煙の上、燃えかすと火の粉の下。
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
		if (age < flash_seconds && dist <= R * 0.16 + R * flash_size * age / flash_seconds) col = over(col, c0.rgb, c0.a);
		float ru = age / ring_seconds;
		if (ru < 1.0) {
			float rr = R * (0.21 + ring_size * out_cubic(ru));
			float w = ru < 0.4 ? 2.0 : 1.0;
			if (abs(dist - rr) <= w && vnoise(vec3(p * 0.25 + seed, ru * 3.0 + 9.0)) >= 0.2 + ru * 0.5)
				col = over(col, ru < 0.3 ? c0.rgb : c1.rgb, ring_alpha * (ru < 0.5 ? 1.0 : 0.58));
		}
	}
	if (col.a <= 0.0) discard;
	COLOR = col;
}
