shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	// 元のピクセル境界を使う輪郭と、量子化した走査線で光の分身にする。
	float edge = max(max(texture(TEXTURE, UV + vec2(texel.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(texel.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, texel.y)).a,
		texture(TEXTURE, UV - vec2(0.0, texel.y)).a));
	float row = floor(UV.y / texel.y);
	float scan = step(1.0, mod(row + floor(clock * 18.0), 6.0));
	float detail = dot(source.rgb, vec3(0.3, 0.5, 0.2));
	vec3 cyan = mix(vec3(0.12, 0.6, 1.0), vec3(0.8, 0.98, 1.0), step(0.4, detail));
	vec3 light = mix(vec3(0.2, 0.85, 1.0), cyan, source.a);
	light *= mix(0.65, 1.35, scan);
	COLOR = vec4(light * tint.rgb, max(source.a * 0.9, edge * 0.6) * tint.a);
}
