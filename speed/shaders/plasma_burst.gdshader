// pixelfx の plasma-explosion を元にした、ドット単位のプラズマの球（エンドブラスト）。
// 球は一気に膨らみ、内側から中空になって殻になる。外のふちは煮え立ち、殻の中を白い筋が渦を巻く。
// 後半は殻が渦の向きにねじれた不規則な欠片に裂け、細りながら市松で薄れて消える。
// 長さはドット単位。四角の中心が球の中心。ノイズは焼いた値ノイズを読む。
// tuning の値は戦闘エフェクトツールで装備ごとに上書きする（ShaderTuning）。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D value_noise : repeat_disable, filter_nearest;
uniform float half_cells = 30.0;
uniform float radius = 20.0;
// 置いてからの秒と、球が消えきるまでの秒
uniform float age = 0.0;
uniform float ball = 0.42;
// 球ごとにノイズの場所をずらす種
uniform float seed = 0.0;
group_uniforms tuning;
uniform vec4 hot : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pale : source_color = vec4(0.902, 0.824, 1.0, 1.0);
uniform vec4 mid : source_color = vec4(0.690, 0.439, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.541, 0.235, 0.878, 1.0);
uniform vec4 soft : source_color = vec4(0.784, 0.627, 1.0, 1.0);
uniform vec4 rim : source_color = vec4(0.541, 0.298, 0.941, 1.0);
group_uniforms;

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

// -1〜1 の2D値ノイズ。layer ごとに別の面を読む
float noise2(vec2 p, float layer) {
	return vnoise(vec3(p + seed * 7.3, layer)) * 2.0 - 1.0;
}

float fbm(vec2 p, float layer) {
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int o = 0; o < 3; o++) {
		sum += noise2(p, layer + float(o) * 11.0) * amp;
		total += amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum / total;
}

float bayer(vec2 c) {
	ivec2 i = ivec2(mod(c, 4.0));
	int b[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(b[i.y * 4 + i.x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 cell = floor((UV - 0.5) * 2.0 * half_cells);
	vec2 c = cell + 0.5;
	float t = age;
	float u = t / ball;
	if (u >= 1.0) {
		discard;
	}
	float grow = 1.0 - pow(1.0 - clamp(u, 0.0, 1.0), 3.0);
	float r = radius * (0.14 + 0.86 * grow);
	float hollow = smoothstep(0.35, 1.0, u);
	float boil = floor(t * 20.0);
	float f = 35.0 / radius;
	float d = length(c);
	float a = atan(c.y, c.x);
	// 角度は cos/sin でノイズへ渡す（±180° でノイズが切れない）
	float edge = r * (1.0 + 0.1 * noise2(vec2(cos(a) * 2.0 + boil * 0.35, sin(a) * 2.0), 3.0));
	if (d > edge) {
		discard;
	}
	float v = d / edge;
	if (v < hollow) {
		discard;
	}
	if (u > 0.75 && 1.0 - smoothstep(0.75, 1.0, u) <= bayer(cell)) {
		discard;
	}
	if (u > 0.45) {
		// 殻が裂ける：渦の向きにねじった fbm で欠片の形を決め、しきい値を上げて欠片を細らせる
		float tw = 1.3 * v + t * 1.5;
		vec2 q = vec2(c.x * cos(tw) - c.y * sin(tw), c.x * sin(tw) + c.y * cos(tw));
		float m = fbm(vec2(q.x * f * 0.11 + 3.0, q.y * f * 0.11), 7.0) - (-0.3 + (u - 0.45) * 2.0);
		if (m < 0.0) {
			discard;
		}
		float fr = (v - hollow) / max(0.05, 1.0 - hollow);
		if (m < 0.05) {
			COLOR = u < 0.62 ? hot : pale;
		} else {
			COLOR = fr > 0.82 ? rim : fr > 0.45 ? mid : soft;
		}
	} else {
		float n = noise2(vec2(c.x * f * 0.12 + boil * 0.5, c.y * f * 0.12), 5.0);
		float w = v + n * 0.14;
		bool fil = abs(sin(a * 5.0 + d * f * 0.32 - t * 14.0 + n * 2.5)) < 0.08;
		if (v > 0.93) {
			COLOR = rim;
		} else if (fil && v > 0.3) {
			COLOR = u < 0.5 ? hot : pale;
		} else if (w < 0.32 - u * 0.25) {
			COLOR = hot;
		} else if (w < 0.52) {
			COLOR = pale;
		} else if (w < 0.72) {
			COLOR = mid;
		} else if (w < 0.86) {
			COLOR = u < 0.5 ? deep : soft;
		} else {
			COLOR = rim;
		}
	}
}
