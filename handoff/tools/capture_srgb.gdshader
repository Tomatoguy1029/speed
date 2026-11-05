shader_type canvas_item;
// 検証用：HDR の画面（リニア・浮動小数点）を、表示と同じ sRGB へ直して写す
void fragment() {
	vec3 c = max(texture(TEXTURE, UV).rgb, vec3(0.0));
	COLOR = vec4(mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055), step(vec3(0.0031308), c)), 1.0);
}
