shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float chain_step = 2.0;

void fragment() {
	// HUD と同じ640×360の画素に固定し、光の濃さも少数の階調に揃える。
	vec2 pixel = floor(UV * vec2(640.0, 360.0)) + vec2(0.5);
	vec2 p = pixel - vec2(320.0, 134.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float tier3 = step(3.0, chain_step);
	float tier4 = step(4.0, chain_step);
	float only3 = tier3 * (1.0 - tier4);
	float gather = smoothstep(0.0, 0.35, progress);
	float release = smoothstep(0.24, 0.85, progress);
	float radius = mix(145.0, 44.0, gather) + release * 104.0;
	float shell = abs(r - radius);
	float ring = step(shell, 1.25);
	ring += tier3 * step(abs(r - radius + 9.0), 0.75) * 0.75;
	ring += tier4 * step(abs(r - radius - 9.0), 1.25);
	float halo = exp(-shell * 0.16);
	float burst = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(0.48, 1.0, progress));
	float rays = pow(max(0.0, cos(angle * 8.0)), 18.0) * exp(-r * 0.012) * burst;
	float flare = exp(-abs(p.y) * 0.45) * exp(-abs(p.x) * 0.009) * release * burst;
	float rail = (step(abs(pixel.y - 48.0), 0.5) + step(abs(pixel.y - 264.0), 0.5)) * step(abs(p.x), 232.0);
	float ticks = step(abs(r - 112.0), 1.0) * step(0.65, fract(angle * 24.0 / 6.2831853));
	// 継続段階が増えると光の層と星片が残る。中央の実アイコンと名称には重ねない。
	float clear_text = 1.0 - step(176.0, pixel.y);
	float arcs = tier3 * step(abs(r - 100.0), 0.75) * step(0.25, abs(cos(angle * 3.0)));
	arcs += only3 * step(abs(r - 125.0), 0.75) * step(0.55, abs(cos(angle * 4.0))) * 0.8;
	arcs += tier4 * step(abs(r - 151.0), 1.0) * step(0.4, abs(cos(angle * 4.0)));
	float particles = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float a = -0.5 + floor(fi / 2.0) * 0.14;
		float spark_radius = 90.0 + mod(fi, 4.0) * 13.0 + release * 12.0;
		float side = mod(fi, 2.0) < 1.0 ? -1.0 : 1.0;
		vec2 center = floor(vec2(320.0, 125.0) + vec2(cos(a) * side, sin(a) * 0.65) * spark_radius);
		vec2 d = abs(pixel - center);
		float spark = max(step(max(d.x, d.y), 1.0), max(step(d.x, 0.5) * step(d.y, 3.0), step(d.y, 0.5) * step(d.x, 3.0)));
		particles += spark * (1.0 - step(tier3 * 8.0 + only3 * 4.0 + tier4 * 8.0, fi));
	}
	particles *= smoothstep(0.0, 0.28, progress) * (0.75 + only3 * 0.15 + tier4 * 0.25);
	vec3 cyan = vec3(0.357, 0.784, 0.859);
	vec3 gold = vec3(0.937, 0.796, 0.439);
	vec3 tone = mix(cyan, gold, tier4);
	float energy = (ring + halo * 0.65 + rays * (0.5 + tier3 * 0.4 + tier4 * 0.5) + flare) * burst * (0.55 + tier3 * 0.3 + only3 * 0.15 + tier4 * 0.3);
	float idle = ticks * (0.25 + tier3 * 0.15 + tier4 * 0.15) + rail * (0.5 + tier3 * 0.15 + tier4 * 0.15);
	idle += (arcs * (0.42 + tier4 * 0.23) + particles) * clear_text;
	float light = floor(clamp(energy + idle, 0.0, 1.0) * 6.0) / 6.0;
	vec3 color = mix(tone, vec3(0.835, 0.859, 0.918), clamp(energy - 0.5 + particles * 0.7, 0.0, 0.65));
	COLOR = vec4(color, light * 0.85);
}
