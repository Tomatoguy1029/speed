// 制作時に並べた64^3の格子点。周期とsmoothstep補間を保ち、8点の取得・mixを1回の3D samplingへ渡す。
uniform sampler3D value_noise : repeat_enable, filter_linear;

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return texture(value_noise, (mod(i, 64.0) + u + 0.5) / 64.0).r;
}
