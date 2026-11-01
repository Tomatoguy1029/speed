// 固定面マスクの R=明面、G=陰面、B=反射、A=外形。内部は不透明。
shader_type canvas_item;
render_mode unshaded;

// fragment の COLOR はテクスチャ色と乗算されるため、インスタンス色を先に保持する。
varying vec4 crystal_color;

void vertex() {
	crystal_color = COLOR;
}

void fragment() {
	vec4 facets = texture(TEXTURE, UV);
	vec3 col = mix(crystal_color.rgb, vec3(1.0), 0.14 * facets.r);
	col *= mix(1.0, 0.82, facets.g);
	col = mix(col, vec3(1.0), 0.95 * facets.b);
	COLOR = vec4(col, crystal_color.a * facets.a);
}
