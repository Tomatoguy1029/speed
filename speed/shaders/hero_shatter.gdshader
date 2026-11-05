// pixelfx の status/petrified の砕け方を元にした、石になった敵が砕ける破片。破片・細かい粒・土ぼこりを
// 1つの MultiMesh にまとめ、砕けた瞬間に置いた値から、飛び方・回転・消え方を頂点で求める。
// 破片は凹んだ形も混じる不揃いな石のかけらで、中はドット単位のまだらな灰色、割れ口の片側は明るく反対は暗い。長さはドット単位。
// インスタンスの値：x 飛ぶ向き（ラジアン）、y 飛ぶ速さ（ドット/秒）、z 回転の速さ、w 砕けた時刻。
// 色の a に種類（0 破片、0.5 粒、1 土ぼこり）、r に形の種、g に寿命（秒÷4）、b に大きさ（ドット÷32）を入れる。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/hero_color.gdshaderinc"
uniform float time = 0.0;
// HDR の画面へ描くときは true（色を最後にリニアへ直す）
uniform bool linear_output = false;
group_uniforms tuning;
uniform vec4 s0 = vec4(0.086, 0.078, 0.110, 1.0);
uniform vec4 s2 = vec4(0.263, 0.247, 0.302, 1.0);
uniform vec4 s3 = vec4(0.373, 0.353, 0.416, 1.0);
uniform vec4 s4 = vec4(0.490, 0.471, 0.537, 1.0);
uniform vec4 s5 = vec4(0.635, 0.616, 0.671, 1.0);
uniform vec4 s6 = vec4(0.804, 0.784, 0.824, 1.0);
uniform vec4 s7 = vec4(0.941, 0.929, 0.953, 1.0);
// 飛ぶ勢いの減り方（大きいほどすぐ止まる）
uniform float drag : hint_range(0.5, 8.0, 0.1) = 3.0;
group_uniforms;

varying vec2 v_local;
varying flat vec4 v_info;
varying flat float v_size;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	vec4 d = INSTANCE_CUSTOM;
	float age = time - d.w;
	float life = COLOR.g * 4.0;
	v_info = vec4(COLOR.a, COLOR.r, age / max(life, 0.01), age);
	v_local = VERTEX;
	v_size = max(COLOR.b * 32.0, 0.5);
	float travel = (1.0 - exp(-drag * max(age, 0.0))) / drag * d.y;
	vec2 dir = vec2(cos(d.x), sin(d.x));
	float spin = d.z * travel / max(d.y, 1.0) * 3.0;
	// 土ぼこりは膨らみ、破片と粒は回りながら飛ぶ
	float grow = COLOR.a > 0.75 ? 0.6 + 1.2 * clamp(age / life, 0.0, 1.0) : 1.0;
	vec2 v = VERTEX * grow;
	v = vec2(v.x * cos(spin) - v.y * sin(spin), v.x * sin(spin) + v.y * cos(spin));
	// インスタンスの変換は原点が砕けた位置、大きさが破片の半径。飛んだドット数を破片の大きさで割って足す
	VERTEX = v + dir * travel / max(COLOR.b * 32.0, 0.1);
}

vec4 rock(vec2 l, float seed) {
	// 破片の中をドットの格子にそろえ、格子の中心で形と色を決める
	vec2 cell = floor(l * v_size);
	vec2 q = (cell + 0.5) / v_size;
	// 頂点ごとの出っ張りと凹みの差が大きい、えぐれた形も混じる不揃いな多角形
	q.y *= 1.0 + 0.6 * hash(seed * 3.0);
	float n = 7.0;
	float a = atan(q.y, q.x);
	float k = floor((a + 3.14159265) / 6.2831853 * n);
	float f = fract((a + 3.14159265) / 6.2831853 * n);
	float r0 = 0.3 + 0.7 * hash(seed * 7.0 + k);
	float r1 = 0.3 + 0.7 * hash(seed * 7.0 + mod(k + 1.0, n));
	float edge = mix(r0, r1, f);
	// ところどころ、ふちから欠け込みが入る
	vec2 bite = vec2(cos(hash(seed * 5.0) * 6.2831853), sin(hash(seed * 5.0) * 6.2831853)) * 0.95;
	if (hash(seed * 11.0) > 0.4 && length(q - bite) < 0.35 + 0.25 * hash(seed * 13.0)) return vec4(0.0, 0.0, 0.0, -1.0);
	float d = length(q);
	if (d > edge) return vec4(0.0, 0.0, 0.0, -1.0);
	// 割れ口：片側は明るく、反対は暗い。中はまだらな灰色
	float lit = dot(normalize(q + 0.0001), normalize(vec2(-0.7, -0.7)));
	if (d > edge - 1.0 / v_size) return lit > 0.0 ? s6 : s2;
	float mottle = hash(cell.x * 13.0 + cell.y * 7.0 + seed * 3.0);
	return mottle > 0.66 ? s5 : mottle > 0.33 ? s4 : s3;
}

void fragment() {
	float kind = v_info.x;
	float u = v_info.z;
	if (u >= 1.0 || v_info.w < 0.0) discard;
	vec4 col;
	if (kind < 0.25) {
		col = rock(v_local, v_info.y * 31.0);
		if (col.a < 0.0) discard;
		// 消えぎわは2コマに1回だけ描いてまたたく
		if (u > 0.75 && mod(floor(v_info.w * 30.0), 2.0) < 1.0) discard;
	} else if (kind < 0.75) {
		col = v_info.y > 0.7 ? s7 : s5;
	} else {
		float d = length(v_local);
		if (d > 1.0) discard;
		col = vec4(s5.rgb, floor((1.0 - d) * 3.0 + 1.0) / 3.0 * 0.22 * (1.0 - u));
	}
	COLOR = vec4(linear_output ? to_linear(col.rgb) : col.rgb, col.a);
}
