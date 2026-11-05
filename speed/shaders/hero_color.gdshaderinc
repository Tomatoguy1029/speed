// HDR の画面へ出すときは、sRGB で求めた色をリニアへ直す（pulser_laser と同じ）。
// 色の uniform は source_color を付けず sRGB の数値のまま受ける（付けると HDR で自動的にリニアになり、二重に直る）
vec3 to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
}
vec3 to_srgb(vec3 color) {
	color = max(color, vec3(0.0));
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - vec3(0.055), step(vec3(0.0031308), color));
}
