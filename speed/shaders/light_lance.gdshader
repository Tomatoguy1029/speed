shader_type canvas_item;
render_mode unshaded;

uniform vec2 extent = vec2(230.0, 64.0);
uniform float left_edge = -42.0;
uniform float tip = 178.0;
uniform float level = 5.0;
uniform float clock = 0.0;
uniform float pixel = 1.5;
uniform bool silhouette = false;
uniform float mode = 0.0; // 0: 槍本体、1: 実経路上の光跡、2: 命中閃光

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 雷撃と同様、白い芯 → 色の縁 → 薄い外光を整数セルで重ねる。
	vec2 p = (floor((UV * extent + vec2(left_edge, -extent.y * 0.5)) / pixel) + 0.5) * pixel;
	float y = abs(p.y);
	float core = 0.0;
	float rim = 0.0;
	float halo = 0.0;
	float dust = 0.0;
	float edge = 0.0;
	float energy = 1.0;
	vec4 vertex_color = COLOR;
	if (mode < 0.5) {
		float root = level < 3.0 ? 16.0 : (level < 4.0 ? 8.0 : (level < 5.0 ? -18.0 : -38.0));
		float shoulder = level < 3.0 ? 22.0 : (level < 4.0 ? 24.0 : (level < 5.0 ? 12.0 : 2.0));
		float width = level < 3.0 ? 3.0 : (level < 4.0 ? 5.5 : (level < 5.0 ? 11.0 : 19.5));
		float front = clamp((tip - p.x) / max(tip - shoulder, 1.0), 0.0, 1.0);
		float back = clamp((p.x - root) / max(shoulder - root, 1.0), 0.0, 1.0);
		float shape = width * min(front, back);
		float on = step(root, p.x) * step(p.x, tip);
		float spine = max(pixel * 0.5, min(3.0, shape * 0.24));
		core = step(y, spine) * on;
		rim = step(y, shape) * on;
		halo = (step(y, shape + pixel * 1.0) * 0.20 + step(y, shape + pixel * 3.0) * 0.07) * on;
		edge = step(abs(y - shape), pixel * 0.55) * on * 0.75;
		// 穂先の内側を流れる短い発光片。輪郭内へ収め、一本の槍として見せる。
		vec2 cell = floor(p / pixel);
		float streak = step(0.79, hash(vec2(floor((cell.x - floor(clock * 48.0)) / 4.0), cell.y)));
		float channel = step(shape * 0.25, y) * step(y, shape * 0.82) * on;
		edge = max(edge, streak * channel * 0.60);
		// Lv5 は機体の両縁から同じ穂先へ収束する輪郭。浮遊する光層を作らない。
		if (level >= 5.0) {
			float facet = step(abs(y - shape * (0.66 + 0.07 * hash(vec2(floor(cell.x / 6.0), 7.0)))), pixel * 0.50) * on;
			edge = max(edge, facet * 0.55);
			// 機体を包む部分は輪郭を残し、前方で白い芯へ収束する。
			core *= p.x < 18.0 ? 0.32 : 1.0;
		}
		float tail_end = level < 3.0 ? -20.0 : -38.0;
		float aft = step(p.x, tail_end) * clamp((p.x - left_edge) / max(tail_end - left_edge, 1.0), 0.0, 1.0);
		float noise = hash(vec2(cell.x + floor(clock * 18.0), cell.y));
		dust = step(0.72, noise) * step(y, 2.0 + aft * 8.0) * aft;
		core = max(core, step(y, pixel * 0.5) * aft * 0.70);
		rim = max(rim, dust * 0.75);
		energy = 0.94 + 0.06 * step(0.35, hash(vec2(floor(clock * 14.0), 2.0)));
	} else if (mode < 1.5) {
		float fade = 1.0 - UV.x;
		vec2 cell = floor(UV * extent / pixel);
		float noise = hash(vec2(cell.x + floor(clock * 16.0), cell.y));
		core = step(y, pixel * 0.6) * step(0.27, noise) * fade;
		rim = step(y, 2.0 + fade * 5.0) * step(0.70, noise) * fade;
		halo = step(y, 3.0 + fade * 7.0) * step(0.85, noise) * fade * 0.35;
	} else {
		float along = clamp((p.x - left_edge) / extent.x, 0.0, 1.0);
		float width = 11.0 * (1.0 - along);
		core = step(y, max(pixel * 0.5, width * 0.28));
		rim = step(y, width);
		halo = step(y, width + pixel * 2.0) * 0.35;
		core *= step(p.x, tip);
		rim *= step(p.x, tip);
		halo *= step(p.x, tip);
	}
	float fill = mode < 0.5 ? 0.28 : 0.65;
	float alpha = max(max(max(core, rim * fill), edge), halo) * vertex_color.a * energy;
	vec3 gold = vec3(1.0, 0.70, 0.25);
	vec3 platinum = vec3(1.0, 0.92, 0.67);
	vec3 color = mix(gold, platinum, rim * 0.30 + edge * 0.55);
	color = mix(color, vec3(1.0, 0.99, 0.94), max(core, edge * 0.65));
	COLOR = vec4((silhouette ? vec3(0.22, 0.25, 0.32) : color * (1.0 + core * 0.80 + edge * 1.20)) * vertex_color.rgb, alpha);
}
