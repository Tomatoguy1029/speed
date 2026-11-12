// 裂け目の輪郭。引っ掻きの本体と、登場で奥の部位を切り抜く側が同じ形を使う。論理画素の格子で計算する。
float hash1(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }
float tear_edge(float s, float seed) { return (hash1(floor(s / 5.0) * 1.7 + seed) * 2.0 - 1.0) * 0.3 + mod(s, 5.0) / 5.0 * 0.16; }
float width_at(float s, float side, float L, float tip_s, float wide, float seed) {
	float lens = pow(sin(3.14159265 * clamp(s / L, 0.0, 1.0)), 0.55);
	float mouth = smoothstep(0.0, max(8.0, tip_s * 0.35), tip_s - s);
	return wide * lens * mouth * (1.0 + tear_edge(s + side * 13.0, seed));
}
vec2 rift_cell(vec2 screen_uv, vec2 viewport) { return floor(screen_uv * viewport / (viewport.y / 225.0)) + 0.5; }
// 縁の2本の線より内側（深淵が見える所）だけを真にする。ends は A.xy, B.xy、shape は wide, tip, open2, seed。
bool rift_interior(vec2 cell, vec4 ends, vec4 shape) {
	vec2 A = ends.xy, B = ends.zw;
	float L = distance(A, B);
	if (L < 1.0 || shape.y <= 0.001) return false;
	vec2 u = (B - A) / L, n = vec2(-u.y, u.x), d = cell - A;
	float tip_s = L * shape.y, al = dot(d, u), lat = dot(d, n);
	if (al < 0.0 || al > tip_s) return false;
	float s = min(al, L);
	float up = width_at(s, 1.0, L, tip_s, shape.x, shape.w), dn = width_at(s, -1.0, L, tip_s, shape.x, shape.w);
	return lat < up && lat > -dn && min(up - lat, lat + dn) >= 2.2;
}
