// ふたご座の光と影の粉。MultiMesh の1つずつが粉の1粒で、粒の位置・大きさ・色は線ができたときに決める。
// INSTANCE_CUSTOM：xy は1秒あたりに漂う距離（世界）、z は消える順番（0〜1。負なら2ドットの粒）、w は線の始まりからの長さ。
// 漂い（age）・一粒ずつ消える（fade）・機体が通った所まで出す（reveal）・光の粒のまたたきをここで計算する。
shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float fade = 1.0;
uniform float reveal = 1e9;
uniform bool light = false;
uniform float time = 0.0;
// 1ドットの世界での幅
uniform float px = 1.82;

varying flat vec4 v_custom;
varying flat float v_spark;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float size = INSTANCE_CUSTOM.z < 0.0 ? 2.0 : 1.0;
	// 光の粒は、粒ごとにずらした周期でときどき白く大きくまたたく
	v_spark = light && sin(time * 11.0 + INSTANCE_CUSTOM.w * 0.37 + abs(INSTANCE_CUSTOM.z) * 91.0) > 0.86 ? 1.0 : 0.0;
	float grow = v_spark > 0.5 ? 2.0 / size : 1.0;
	VERTEX = VERTEX * grow + INSTANCE_CUSTOM.xy * age / (px * size);
}

void fragment() {
	if (abs(v_custom.z) > fade || v_custom.w > reveal) discard;
	vec3 c = v_spark > 0.5 ? vec3(1.0, 1.0, 0.95) : COLOR.rgb;
	COLOR = vec4(c, 0.6 + 0.4 * fade);
}
