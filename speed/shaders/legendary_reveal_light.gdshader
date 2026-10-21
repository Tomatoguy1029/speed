// モジュールの局所光。広い薄光と細い集束光を、固定ピクセル座標で重ねる。
shader_type canvas_item;
render_mode unshaded;
uniform vec2 center = vec2(0.5, 0.47);
uniform vec4 light_color : source_color = vec4(0.89, 0.73, 0.42, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.7;
uniform float arrival : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(0.0, 1.0) = 0.0;
float cloud(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(vec4(dot(cell, vec2(12.9, 78.2)), dot(cell + vec2(1.0, 0.0), vec2(12.9, 78.2)),
		dot(cell + vec2(0.0, 1.0), vec2(12.9, 78.2)), dot(cell + vec2(1.0), vec2(12.9, 78.2)))) * 43758.5);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}
void fragment() {
	vec2 pixel = floor(UV * vec2(640.0, 360.0));
	vec2 p = (pixel / vec2(640.0, 360.0) - center) * vec2(1.77778, 1.0);
	float radius = length(p);
	float halo = exp(-radius * radius * 30.0) * 0.36;
	float core = exp(-radius * radius * 150.0) * 0.26;
	float shaft = exp(-abs(p.x + p.y * 0.17) * mix(50.0, 95.0, arrival));
	shaft *= exp(-abs(p.y) * 5.0) * mix(0.28, 0.07, arrival);
	float horizon = exp(-abs(p.y) * 180.0 - abs(p.x) * 9.0) * 0.13 * arrival;
	float noise = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	// 雲状の黒い遮蔽の隙間から、幅の異なる後光がゆっくり広がる。
	float angle = atan(p.y, p.x);
	float direction = cloud(vec2(cos(angle), sin(angle)) * 4.5 + arrival * 0.13);
	float rays = pow(direction, 3.0) * exp(-radius * 4.0) * smoothstep(0.05, 0.1, radius);
	float shroud = cloud(p * 13.0 + vec2(arrival * 0.08, 0.0));
	float alpha = (halo + core + shaft + horizon + rays * 0.9) * intensity;
	alpha *= mix(0.35 + shroud * 0.65, 1.0, exposure);
	// 微量のディザだけを加え、目立つ市松模様や連続点滅を避ける。
	alpha = floor(max(0.0, alpha + (noise - 0.5) / 96.0) * 96.0) / 96.0;
	COLOR = vec4(light_color.rgb, alpha);
}
