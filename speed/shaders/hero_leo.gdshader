// しし座の力：機体が真上から見た獅子になる。形は絵（lion_body：コマごとの胴・脚・背の毛・顔、lion_aux：顔のマスク・目・尾）で受け、
// 体の中は紫とマゼンタの星雲に細かい星が散る宇宙、全身から金のオーラが立ちのぼってふちにもかかる。
// たてがみは頭から体の6割ほどまで後ろへなびき、顔のマスクの上には描かない。尾は絵の形を根元から先へしならせる。
// ドットの格子は世界にそろえ（1ドット＝機体の1ドット）、絵は向きに合わせて回して読む。色は sRGB で求め、HDR の画面ではリニアへ直す。
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/burst_noise.gdshaderinc"
#include "res://shaders/hero_color.gdshaderinc"
uniform sampler2D body_tex : filter_nearest;
uniform sampler2D aux_tex : filter_nearest;
uniform float half_cells = 95.0;
uniform float time = 0.0;
uniform float heading = 0.0;
uniform float strength = 1.0;
uniform int frame = 0;
// 駆け足の体のしなり：stretch は胴の伸び縮み（1 で絵のまま）、bend は腰の左右のしなり（絵のドット）
uniform float stretch = 1.0;
uniform float bend = 0.0;
// 宙に浮く間に少し大きく見せる倍率
uniform float lift = 1.0;
// 描く層：0 は全部、1 は体とたてがみだけ、2 は体の外のオーラだけ、
// 3 は本体のぶれの元（体とたてがみだけで、ふちの金と目の光をのせない）
uniform int layer = 0;
// 変身の閃光（0〜1）。形がそろった瞬間に、獅子全体が金に光る
uniform float flash = 0.0;
uniform bool linear_output = false;
group_uniforms tuning;
uniform vec4 night = vec4(0.102, 0.059, 0.290, 1.0);
uniform vec4 violet = vec4(0.294, 0.122, 0.627, 1.0);
uniform vec4 purple = vec4(0.478, 0.184, 0.753, 1.0);
uniform vec4 magenta = vec4(0.753, 0.251, 0.690, 1.0);
uniform vec4 blush = vec4(0.941, 0.627, 0.878, 1.0);
uniform vec4 azure = vec4(0.188, 0.314, 0.816, 1.0);
uniform vec4 shine = vec4(1.0, 0.984, 0.957, 1.0);
uniform vec4 aura_deep = vec4(0.851, 0.561, 0.157, 1.0);
uniform vec4 aura = vec4(1.0, 0.776, 0.322, 1.0);
uniform vec4 aura_hot = vec4(1.0, 0.933, 0.678, 1.0);
// 機体の1ドットに入る絵のドット数（大きいほど獅子が小さい）
uniform float art_per_cell : hint_range(0.8, 3.0, 0.05) = 1.65;
// たてがみの長さ（頭のうしろから腰へ、絵のドット）
uniform float mane_length : hint_range(20.0, 140.0, 1.0) = 98.0;
uniform float body_alpha : hint_range(0.3, 1.0, 0.05) = 0.9;
group_uniforms;

const vec2 ART = vec2(120.0, 220.0);
// 絵の中で、機体の位置にあたる点（胸）
const vec2 PIVOT = vec2(60.0, 100.0);
const vec2 HEAD = vec2(59.0, 28.0);
const float TAIL_ROOT = 140.0;
// これより後ろの脚を後ろ脚とする（絵の y）
const float HIND_FROM = 105.0;
// 首（絵の y）。これより前の頭は駆け足で伸び縮みしない
const float NECK = 44.0;
// たてがみの根元（顔のマスクの後ろのふちより少し前。マスクの上には描かないので、ふちから生えて見える）
const float MANE_ROOT = 34.0;

varying vec2 v_cell;

void vertex() {
	v_cell = (UV - 0.5) * 2.0 * half_cells;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

bool inside_art(vec2 a) {
	return a.x >= 0.0 && a.y >= 0.0 && a.x < ART.x && a.y < ART.y;
}

vec4 body_at(vec2 a) {
	if (!inside_art(a)) return vec4(0.0);
	return texelFetch(body_tex, ivec2(floor(a)) + ivec2(frame * int(ART.x), 0), 0);
}

vec3 aux_at(vec2 a) {
	if (!inside_art(a)) return vec3(0.0);
	return texelFetch(aux_tex, ivec2(floor(a)), 0).rgb;
}

// 尾：根元を中心に左右へ振れ、先ほど遅れて大きく曲がる
float tail_at(vec2 a) {
	vec2 root = vec2(60.0, TAIL_ROOT);
	vec2 d = a - root;
	float t = clamp(length(d) / 70.0, 0.0, 1.0);
	float swing = sin(time * 4.5 - t * 2.2) * (0.18 + 0.32 * t) + sin(time * 9.0 - t * 4.0) * 0.06 * t;
	vec2 back = vec2(cos(swing) * d.x + sin(swing) * d.y, -sin(swing) * d.x + cos(swing) * d.y);
	return aux_at(root + back).b;
}

float covered(vec2 a) {
	return max(body_at(a).a, tail_at(a));
}

// 星雲：紫にマゼンタと青がにじむ（絵のドットの座標で読み、獅子と一緒に動く）
vec3 nebula(vec2 a) {
	float n1 = vnoise(vec3(a * 0.045 + vec2(0.0, time * 0.25), 3.0));
	float n2 = vnoise(vec3(a * 0.09 - vec2(time * 0.2, 0.0), 7.0));
	float n3 = vnoise(vec3(a * 0.18 + vec2(0.0, -time * 0.4), 11.0));
	vec3 col = mix(night.rgb, violet.rgb, smoothstep(0.25, 0.6, n1));
	col = mix(col, purple.rgb, smoothstep(0.5, 0.75, n1 * 0.6 + n2 * 0.5));
	col = mix(col, azure.rgb, smoothstep(0.65, 0.9, n2) * 0.6);
	col = mix(col, magenta.rgb, smoothstep(0.6, 0.85, n1 * 0.5 + n3 * 0.6));
	return mix(col, blush.rgb, smoothstep(0.84, 0.97, n1 * 0.45 + n3 * 0.65));
}

// 宇宙：星雲に、明るさのばらつく星がびっしり散る
vec3 cosmos(vec2 a, vec2 cell) {
	vec3 col = nebula(a);
	float h = hash(floor(a / 1.5));
	float tw = 0.5 + 0.5 * sin(time * 4.0 + h * 50.0);
	if (h > 0.93) return mix(col, shine.rgb, 0.45 + 0.5 * tw);
	if (h > 0.88) return mix(col, shine.rgb, 0.3);
	return floor(col * 14.0) / 14.0;
}

vec3 gold(float heat) {
	return heat > 0.78 ? aura_hot.rgb : heat > 0.5 ? aura.rgb : aura_deep.rgb;
}

// たてがみ：唐獅子のように、顔（マスク）の後ろのふちを境目に生え、顔の幅のまま腰のあたりまで後ろへたなびく。返り値は濃さ（0 なら無し）、heat に金の強さ
float mane_at(vec2 a, out float heat, out float side_out) {
	heat = 0.0;
	side_out = 1.0;
	float back = a.y - MANE_ROOT;
	if (back < 0.0 || back > mane_length) return 0.0;
	float k = clamp(back / mane_length, 0.0, 1.0);
	// たなびき：波が根元から先へ流れ、先ほど大きく振れる
	float sway = sin(back * 0.05 - time * 4.5) * 12.0 * k * k + sin(back * 0.12 - time * 7.5) * 3.0 * k;
	float u = a.x - HEAD.x - sway;
	// 根元は顔の幅で、肩のあたりで左右に少し膨らみ、腰へ向けて細る
	float hw = (25.0 + 7.0 * sin(3.14159 * clamp(k / 0.7, 0.0, 1.0))) * (1.0 - 0.6 * smoothstep(0.45, 1.0, k));
	float lobes = vnoise(vec3(u * 0.08, back * 0.022 - time * 1.0, 1.0));
	// ふさふさのふち：細かな毛の房で波打ち、後ろほど大きく乱れる
	float fluff = vnoise(vec3(u * 0.35, back * 0.3 - time * 3.0, 9.0)) - 0.5;
	float edge = hw * (0.9 + 0.15 * lobes) + fluff * (3.0 + 7.0 * k);
	float side = abs(u) / max(edge, 0.5);
	side_out = side;
	// 先は房ごとに長さがばらけ、炎の舌のように抜ける
	// 先はゆるく長さがばらける
	float tip = vnoise(vec3(u * 0.12, time * 0.7, 6.0));
	float reach = 0.78 + 0.2 * tip;
	// 毛先は前後にも細かくばらけ、ふさふさに抜ける
	float curl = vnoise(vec3(u * 0.45, back * 0.4 - time * 3.0, 14.0)) - 0.5;
	reach += curl * 0.22;
	if (side > 1.0 || k > reach) return 0.0;
	// 房：毛の流れにそった明るさのゆらぎ
	float strand = 0.5 + 0.5 * sin(u * 0.42 + vnoise(vec3(u * 0.05, back * 0.03 - time * 1.4, 4.0)) * 6.0);
	// 真ん中ほど毛量が多く明るい。左右は薄く透ける
	heat = (1.0 - side * side) * 0.75 + strand * 0.3;
	// 左右のふちと先は透けて、炎のように抜ける
	return 0.9 - 0.45 * smoothstep(0.55, 1.0, side) - 0.35 * smoothstep(0.6, 1.0, k / reach);
}

// 絵の塗り分け：0 胴、1 脚（手前）、2 脚（奥）・背の毛の影、3 背の毛、4 顔。数が大きいほど上に重なる
int part_of(vec4 b) {
	if (b.a < 0.5) return -1;
	float c = floor(b.r * 255.0 + 0.5);
	if (c >= 160.0) return 4;
	if (c >= 148.0) return 3;
	if (c >= 139.0) return 2;
	if (c >= 135.0) return 1;
	return 0;
}

// 部位ごとの色：明るさは顔、胴、脚の順（前脚と後ろ脚はそろえる）。脚は青く、顔は暖かくする。hind は後ろ脚か
vec3 part_color(int part, bool hind, vec3 space) {
	if (part == 4) return mix(space * 1.15, blush.rgb, 0.22);
	if (part == 3) return mix(space, purple.rgb, 0.25) * 1.05;
	if (part == 1 || part == 2) return mix(mix(space, azure.rgb, 0.2), night.rgb, 0.35) * 0.82;
	return mix(space, night.rgb, 0.25) * 0.9;
}

vec4 paint(vec2 cell_position) {
	vec2 cell = floor(cell_position) + 0.5;
	vec2 f = vec2(cos(heading), sin(heading));
	vec2 r = vec2(-f.y, f.x);
	vec2 a = PIVOT + vec2(dot(cell, r), -dot(cell, f)) * art_per_cell;
	// 体のしなり：頭は動かさず、首より後ろの体と手足だけが伸び縮みし、宙に浮く間は少し大きくなる。腰は左右へしなる
	if (a.y > NECK) {
		float w = smoothstep(NECK, NECK + 25.0, a.y);
		float grow = mix(1.0, lift, w);
		a.y = NECK + (a.y - NECK) / (stretch * grow);
		a.x = PIVOT.x + (a.x - PIVOT.x) / grow;
	}
	a.x -= bend * pow(clamp((a.y - PIVOT.y) / 90.0, 0.0, 1.0), 1.5);
	vec4 b = body_at(a);
	vec3 x = aux_at(a);
	float tail = tail_at(a);
	float inside = max(b.a, tail);
	// まわりの絵：ふちの近さ（内側）と、後ろへ流れるオーラ（外側）に使う
	float rim = 0.0;
	float near = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 dir = vec2(cos(float(i) * 0.785398), sin(float(i) * 0.785398));
		rim += 1.0 - covered(a + dir * 2.0) * 0.5 - covered(a + dir * 4.0) * 0.5;
		near = max(near, covered(a + dir * 3.0 + vec2(0.0, -3.0)) * 1.0);
		near = max(near, covered(a + dir * 6.0 + vec2(0.0, -8.0)) * 0.75);
		near = max(near, covered(a + dir * 9.0 + vec2(0.0, -15.0)) * 0.5);
	}
	rim /= 8.0;
	float flick = vnoise(vec3(a * 0.12 + vec2(0.0, -time * 3.0), 13.0));
	// 目：金に光り、まわりにも光がにじむ（ぶれの元の層では、目も本体の色で描く）
	if (x.g > 0.5 && layer != 3) return vec4(mix(aura_hot.rgb, shine.rgb, 0.6 + 0.4 * sin(time * 3.0)), strength);
	float eye_glow = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 dir = vec2(cos(float(i) * 1.5708), sin(float(i) * 1.5708));
		eye_glow = max(eye_glow, aux_at(a + dir * 1.6).g);
		eye_glow = max(eye_glow, aux_at(a + dir * 3.2).g * 0.5);
	}
	bool face = x.r > 0.5 && b.a > 0.5;
	float heat;
	float mane_side;
	float mane = face ? 0.0 : mane_at(a, heat, mane_side);
	vec3 col = vec3(0.0);
	if (inside > 0.5) {
		// 尾は脚より手前に重なる
		int part = tail > 0.5 ? 3 : part_of(b);
		col = part_color(part, a.y > HIND_FROM, cosmos(a, cell));
		// ぶれの元の層では、目の光とふちの金はのせない（オーラはオーラで別にぶれる）
		if (layer != 3) {
			if (eye_glow > 0.0) col = mix(col, aura_hot.rgb, eye_glow * 0.55);
			// ふちから内へ、金のオーラがにじむ
			float glow = clamp(rim * 1.5 - 0.2 + (flick - 0.5) * 0.8, 0.0, 1.0);
			col = mix(col, gold(glow), floor(glow * 4.0) / 4.0 * 0.7);
		}
	}
	// オーラだけを描く層では、体とたてがみは描かない
	if (layer == 2 && (mane > 0.0 || inside > 0.5)) return vec4(0.0, 0.0, 0.0, -1.0);
	if (mane > 0.0) {
		// たてがみは透明感のある金と白と紫：毛の流れの明るいところは白、中ほどは金、暗いところは紫で、下の宇宙を少し透かす
		float h = heat + (flick - 0.5) * 0.3;
		// 紫とクリームは混ぜると灰色に濁るので、明るさの段ごとに色を分けて塗る
		vec3 space = cosmos(a, cell);
		bool star = dot(space, vec3(0.333)) > 0.75;
		vec3 hair = h > 0.8 ? shine.rgb : h > 0.62 ? aura_hot.rgb : h > 0.45 ? aura.rgb : mix(purple.rgb, space, 0.35);
		if (star) hair = shine.rgb;
		if (mane_side > 0.82) hair = flick > 0.5 ? aura.rgb : aura_deep.rgb;
		float cover = floor(clamp(mane * (h > 0.45 ? 0.8 : 0.6), 0.0, 0.9) * 5.0) / 5.0;
		// 体の上では下の宇宙に光を足して重ね、紫の色味を残したまま光らせる（混ぜると灰色に濁る）
		if (inside > 0.5) return vec4(min(col + hair * cover * 0.75, vec3(1.0)), body_alpha * strength);
		return vec4(hair, cover * strength);
	}
	if (inside > 0.5) return vec4(col, body_alpha * strength);
	// 体だけを描く層では、体の外のオーラは描かない
	if (layer == 1 || layer == 3) return vec4(0.0, 0.0, 0.0, -1.0);
	// 体の外：半透明の金のオーラが炎のように立ちのぼり、後ろへ流れる
	if (eye_glow > 0.0) return vec4(aura_hot.rgb, 0.5 * eye_glow * strength);
	float tongue = vnoise(vec3(a.x * 0.3, a.y * 0.12 - time * 5.0, 17.0));
	float rise = near * (0.35 + 0.9 * tongue) + (flick - 0.5) * 0.3;
	if (rise > 0.42) {
		float alpha = rise > 0.75 ? 0.75 : rise > 0.58 ? 0.5 : 0.28;
		return vec4(gold(rise * 0.9), alpha * strength);
	}
	return vec4(0.0, 0.0, 0.0, -1.0);
}

void fragment() {
	vec4 painted = paint(v_cell);
	if (painted.a < 0.0) discard;
	painted.rgb = mix(painted.rgb, aura_hot.rgb, flash);
	painted.a = max(painted.a, flash * 0.9 * step(0.001, painted.a));
	COLOR = vec4(linear_output ? to_linear(painted.rgb) : painted.rgb, painted.a);
}
