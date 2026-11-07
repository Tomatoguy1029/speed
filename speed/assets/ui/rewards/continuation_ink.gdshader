// Iris・Star Iris の墨。穴の外を塗り、走査線と格子を重ねる。穴の縁は1画素でなめらかにする。
shader_type canvas_item;
uniform vec2 center = vec2(320.0, 172.0);
uniform float radius = 0.0;
uniform float rotation = 0.0;
uniform bool star = false;
uniform vec2 canvas_size = vec2(720.0, 440.0);
// 塗る矩形の左上（試作の画面座標）
uniform vec2 origin = vec2(-40.0, -40.0);
float star_dist(vec2 p) {
	// 10頂点の星形の内側なら正。辺までの距離を返す。
	float a = atan(p.y, p.x) - (rotation - PI * 0.5);
	float sector = PI / 5.0;
	a = mod(a, 2.0 * PI);
	float i = floor(a / sector);
	float a0 = i * sector, a1 = (i + 1.0) * sector;
	float r0 = mod(i, 2.0) < 0.5 ? radius : radius * 0.44;
	float r1 = mod(i + 1.0, 2.0) < 0.5 ? radius : radius * 0.44;
	vec2 v0 = vec2(cos(a0), sin(a0)) * r0, v1 = vec2(cos(a1), sin(a1)) * r1;
	vec2 q = vec2(cos(a), sin(a)) * length(p);
	vec2 e = v1 - v0;
	// 中心と同じ側なら内側
	float c0 = e.x * (-v0.y) - e.y * (-v0.x);
	float cq = e.x * (q.y - v0.y) - e.y * (q.x - v0.x);
	return sign(c0) * cq / max(length(e), 0.0001);
}
void fragment() {
	vec2 px = origin + UV * canvas_size;
	vec2 p = px - center;
	float inside = radius < 0.5 ? -1.0 : star ? star_dist(p) : radius - length(p);
	float ink = clamp(0.5 - inside, 0.0, 1.0);
	vec3 c = vec3(4.0, 9.0, 19.0) / 255.0;
	vec3 cyan = vec3(91.0, 200.0, 219.0) / 255.0;
	vec2 cell = floor(px);
	if (mod(cell.y, 3.0) < 0.5) c = mix(c, cyan, 0.07);
	if (mod(cell.x, 32.0) < 0.5) c = mix(c, cyan, 0.12);
	if (mod(cell.y - 12.0, 32.0) < 0.5) c = mix(c, cyan, 0.12);
	COLOR = vec4(c, ink);
}
