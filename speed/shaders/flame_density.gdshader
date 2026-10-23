// 小さな粒の密度だけを加算する。RGB は外炎・内炎・芯の独立した粒子群。
shader_type canvas_item;
render_mode unshaded, blend_add;

void vertex() {
	VERTEX.y *= mix(1.12, 1.62, COLOR.a);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float kernel = max(0.0, 1.0 - dot(p, p));
	kernel *= kernel;
	COLOR = vec4(COLOR.rgb * kernel, 1.0);
}
