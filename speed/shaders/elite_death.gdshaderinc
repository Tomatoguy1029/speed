// 4×4コマの制作済み座標アトラス。RG=元の画素座標、B=破片の被覆。
// 破片の中心は個体の死亡時速度で移動し、破片内の画素は中心へ縮む。
uniform bool death_enabled = false;
uniform sampler2D death_map : filter_nearest, repeat_disable;
vec3 death_sample(vec2 uv, float age) {
	if (!death_enabled) return vec3(uv, 1.0);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) return vec3(0.0);
	vec2 size = vec2(textureSize(death_map, 0)) / 4.0;
	float frame = floor(clamp(age, 0.0, 1.0) * 15.0);
	vec2 tile = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec2 pixel = floor(uv * size) + 0.5;
	vec3 data = texture(death_map, (tile + pixel / size) / 4.0).rgb;
	return vec3((floor(data.rg * 255.0 + 0.5) + 0.5) / size, data.b);
}
