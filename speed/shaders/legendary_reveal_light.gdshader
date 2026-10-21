// モジュールの局所光。広い薄光と細い集束光を、固定ピクセル座標で重ねる。
shader_type canvas_item;
render_mode unshaded;
uniform vec2 center = vec2(0.5, 0.47);
uniform vec4 light_color : source_color = vec4(0.89, 0.73, 0.42, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.7;
uniform float arrival : hint_range(0.0, 1.0) = 1.0;
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
	float alpha = (halo + core + shaft + horizon) * intensity;
	// 微量のディザだけを加え、目立つ市松模様や連続点滅を避ける。
	alpha = floor(max(0.0, alpha + (noise - 0.5) / 96.0) * 96.0) / 96.0;
	COLOR = vec4(light_color.rgb, alpha);
}
