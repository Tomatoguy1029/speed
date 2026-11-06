shader_type canvas_item;
render_mode unshaded;
// pixelFX fireball の連番を明るさごとに紫へ塗り替える。rear_only は隕石の上へ重ねる後ろ半分だけを残す。
uniform bool rear_only = false;
varying float local_x;
const vec3 RAMP[8] = vec3[8](vec3(0.141,0.102,0.361),vec3(0.255,0.165,0.580),vec3(0.373,0.235,0.784),vec3(0.510,0.349,0.933),vec3(0.659,0.518,1.0),vec3(0.788,0.690,1.0),vec3(0.902,0.847,1.0),vec3(1.0));
void vertex() {
	local_x = VERTEX.x;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float v = clamp(dot(source.rgb, vec3(0.3, 0.59, 0.11)), 0.0, 1.0) * 6.0;
	int i = min(6, int(floor(v)));
	COLOR.rgb = mix(RAMP[i], RAMP[i + 1], v - float(i));
	COLOR.a = source.a * COLOR.a * (rear_only ? clamp((1.0 - local_x) / 12.0, 0.0, 1.0) : 1.0);
}
