// 既存の仮部品図用の局所金属表現。専用 preview_texture の色は保持する。
shader_type canvas_item;
render_mode unshaded;
uniform vec4 metal_color : source_color = vec4(0.88, 0.77, 0.52, 1.0);
uniform vec4 rust_color : source_color = vec4(0.46, 0.33, 0.16, 1.0);
uniform float motion_time = 0.0;
uniform float flow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 tint = item_tint;
	vec4 source = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 pixel = floor(UV / px);
	float wear = grain(pixel / 11.0) * 0.7 + grain(pixel / 4.0) * 0.3;
	float rust = smoothstep(0.67, 0.84, wear) * 0.42;
	float face = 0.70 + 0.24 * (1.0 - UV.y) + 0.04 * grain(pixel / 40.0);
	vec3 metal = mix(metal_color.rgb * face, rust_color.rgb, rust);
	float broad_sheen = exp(-pow((UV.x + UV.y * 0.45 - 0.62) * 3.8, 2.0));
	metal += vec3(0.16, 0.14, 0.09) * broad_sheen * (1.0 - rust);
	// 上左の縁を拾い、反対の縁を落として、平面の仮部品にも厚みを持たせる。
	float top = source.a - texture(TEXTURE, UV - px * vec2(1.0, 1.0)).a;
	float bottom = source.a - texture(TEXTURE, UV + px * vec2(1.0, 1.0)).a;
	metal += max(0.0, top) * vec3(0.40, 0.33, 0.18);
	metal *= 1.0 - max(0.0, bottom) * 0.52;
	// 低い光沢が出現に合わせて一度だけ面を渡る。
	float sweep = 1.0 - smoothstep(0.0, 0.11, abs(UV.x * 0.7 + UV.y * 0.3 - mix(-0.1, 1.1, reveal)));
	metal += vec3(0.23, 0.19, 0.10) * sweep * (1.0 - rust);
	// 面の上をゆっくり渡る細い反射。模様や固有の紋章を追加しない。
	float flow_path = UV.y + UV.x * 0.38 + sin(UV.x * 8.0 + motion_time * 0.25) * 0.025;
	float flow_center = 0.58 + sin(motion_time * 0.4) * 0.1;
	float flow = exp(-pow((flow_path - flow_center) / 0.006, 2.0));
	metal += vec3(0.45, 0.36, 0.18) * flow * flow_strength * (1.0 - rust * 0.5);
	metal += (hash(pixel) - 0.5) * 0.018;
	float depth = texture(TEXTURE, UV - px * vec2(1.0, 3.0)).a;
	vec3 surface = mix(metal_color.rgb * 0.24, metal, source.a);
	COLOR = vec4(surface, max(source.a, depth)) * tint;
}
