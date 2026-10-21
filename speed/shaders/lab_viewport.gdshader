shader_type canvas_item;
render_mode unshaded;

uniform bool convert_hdr = false;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (convert_hdr) {
		vec3 low = pixel.rgb * 12.92;
		vec3 high = 1.055 * pow(max(pixel.rgb, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
		pixel.rgb = mix(high, low, lessThanEqual(pixel.rgb, vec3(0.0031308)));
	}
	COLOR = pixel;
}
