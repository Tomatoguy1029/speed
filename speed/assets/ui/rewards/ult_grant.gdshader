shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// カットインもHUDと同じ画素幅・金/水色/白のパレットで描く。
	vec2 pixel = floor(UV * vec2(640.0, 360.0)) + vec2(0.5);
	vec2 p = pixel - vec2(320.0, 176.0);
	float t = floor(progress * 24.0) / 24.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float gather = smoothstep(0.0, 0.55, t);
	float release = smoothstep(0.48, 1.0, t);
	float radius = floor(mix(154.0, 48.0, gather) + release * 132.0);
	float shell = abs(r - radius);
	float ring = step(shell, 1.25);
	float rim = step(shell, 4.0) * 0.25;
	float rays = step(0.975, cos(a * 8.0 + t * 0.6)) * step(28.0, r) * step(r, radius + 24.0);
	float column = step(abs(p.x), floor(mix(26.0, 2.0, gather))) * step(abs(p.y), 112.0) * 0.5;
	float core = step(abs(p.x) + abs(p.y), mix(3.0, 13.0, release)) * gather;
	float ticks = step(abs(r - radius - 12.0), 1.0) * step(0.7, fract(a * 24.0 / 6.2831853));
	float flare = step(abs(p.y), 1.0) * step(abs(p.x), 132.0) * release;
	// 収束する角形の光粒。ぼかしを使わず、点滅と少数の階調で光の強さを出す。
	float sparks = 0.0;
	for (int i = 0; i < 24; i++) {
		float index = float(i);
		float angle = index * 2.39996;
		float reach = mix(72.0 + mod(index * 17.0, 126.0), 16.0, gather) + release * 90.0;
		vec2 at = floor(vec2(cos(angle), sin(angle)) * reach);
		vec2 d = abs(p - at);
		sparks += step(max(d.x, d.y), 1.5) * (0.5 + 0.5 * step(0.5, fract(index * 0.37 + t * 3.0)));
	}
	float fade = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.76, 1.0, t));
	float energy = ring + rim + rays * 0.8 + column + flare + sparks + core;
	float alpha = floor(clamp(energy * fade, 0.0, 1.0) * 4.0) / 4.0;
	vec3 gold = vec3(0.937, 0.796, 0.439);
	vec3 white = vec3(0.835, 0.859, 0.918);
	vec3 cyan = vec3(0.357, 0.784, 0.859);
	vec3 color = mix(gold, white, step(0.8, ring * release + sparks + core));
	if (alpha == 0.0 && ticks * fade > 0.2) {
		color = cyan;
		alpha = 0.25;
	}
	COLOR = vec4(color, alpha);
}
