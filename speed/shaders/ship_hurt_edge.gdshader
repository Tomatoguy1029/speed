// 被弾とHPが少ない間に、画面の縁を赤く染める。中心から縁へ向かってなめらかに濃くする。
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.2, 1.0);
uniform float strength = 0.0;
// 中心から角までを1としたとき、色が付き始める位置。
uniform float inner = 0.4;
// 中心から角までを1としたとき、いちばん濃くなる位置。そこから外は同じ濃さ。
uniform float outer = 0.78;
uniform float aspect = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p) / length(vec2(aspect, 1.0) * 0.5);
	float edge = smoothstep(inner, outer, r);
	COLOR = vec4(tint.rgb, tint.a * strength * edge);
}
