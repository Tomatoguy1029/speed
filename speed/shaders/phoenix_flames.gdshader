// 頂点色はr=段階の進行、g=個体のずらし、b=半径/1000、a=予告0・攻撃1。
// 全ほうおう座を同じmaterialで描き、炎1つにつき局所的な四角形1枚だけを使う。
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform bool linear_colors = false;
uniform float clock = 0.0;
uniform vec4 ember_color : source_color;
uniform vec4 flame_color : source_color;
uniform vec4 hot_color : source_color;
uniform vec4 smoke_color : source_color;
uniform float amount = 0.85;
uniform float speed = 1.0;
uniform float pixel_size = 3.0;
uniform float turbulence = 1.0;
uniform float sparks = 0.45;
uniform float opacity = 0.85;
uniform float emission = 0.65;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 to_srgb(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), color));
}

void fragment() {
	vec3 data = linear_colors ? to_srgb(COLOR.rgb) : COLOR.rgb;
	float age = clamp(data.r, 0.0, 1.0);
	float seed = data.g * 17.0;
	float radius = max(1.0, data.b * 1000.0);
	float attack = step(0.5, COLOR.a);
	float cell = pixel_size / radius;
	vec2 p = (floor(UV / cell) + 0.5) * cell;
	float r = length(p);
	float t = clock * speed + seed;
	float angle = atan(p.y, p.x);
	vec3 n = texture(noise_tex, p * 0.48 + vec2(t * 0.07, -t * 0.13)).rgb;
	float curl = texture(noise_tex, vec2(angle * 0.28 + seed, r * 0.7 - t * 0.16) + (n.rg - 0.5) * 0.17 * turbulence).g;
	float fine = texture(noise_tex, p * 1.6 + vec2(t * 0.11, -t * 0.3)).b;
	float flow = curl * 0.58 + n.r * 0.28 + fine * 0.14;
	// 外へ広がる熱の前縁と、ちぎれながら巻き上がる炎。円全体は塗りつぶさない。
	float front = mix(0.32, 1.0, smoothstep(0.0, 0.35, age));
	float rim = 1.0 - smoothstep(front - 0.12, front + 0.02, r + (curl - 0.5) * 0.14 * turbulence);
	float hollow = smoothstep(age * 0.55 - 0.15, age * 0.55 + 0.23, r);
	float tongues = smoothstep(0.73 - amount * 0.32, 0.94 - amount * 0.32, flow + (1.0 - r) * 0.13);
	float life = 1.0 - smoothstep(0.48, 1.0, age);
	float heat = clamp((flow - 0.3) * 2.2 + (1.0 - r) * 0.16, 0.0, 1.0);
	heat = floor(heat * 5.0) / 4.0;
	vec3 fire = mix(ember_color.rgb, flame_color.rgb, smoothstep(0.05, 0.55, heat));
	fire = mix(fire, hot_color.rgb, smoothstep(0.58, 1.0, heat));
	fire *= 1.0 + emission * smoothstep(0.65, 1.0, heat);
	float fire_alpha = rim * hollow * tongues * life * opacity;
	float smoke = rim * smoothstep(0.4, 0.75, n.b) * (1.0 - tongues) * life * 0.2;
	// セルごとに形・速さ・明滅を変えた火の粉。予告は降り、着地では外へ散る。
	vec2 dust_p = p * vec2(11.0, 8.0) + vec2(sin(t + seed) * 0.25, t * mix(-1.7, 2.8, attack));
	vec2 grid = floor(dust_p);
	float h = hash(grid + seed);
	vec2 local = fract(dust_p) - vec2(0.2 + h * 0.6, 0.2 + fract(h * 7.0) * 0.6);
	float shape = 1.0 - smoothstep(0.07, 0.16, max(abs(local.x) * (1.5 + h), abs(local.y) * 0.6));
	float dust = shape * step(1.0 - sparks * 0.48, h) * (0.45 + 0.55 * sin(t * (3.0 + h * 5.0) + h * 19.0));
	dust *= (1.0 - smoothstep(1.0, 1.18, r)) * mix(0.35 + age * 0.65, life, attack);
	vec3 color = mix(smoke_color.rgb, fire, fire_alpha / max(0.001, fire_alpha + smoke));
	color = mix(color, hot_color.rgb * (1.0 + emission), clamp(dust, 0.0, 1.0));
	float alpha = (fire_alpha + smoke) * attack + dust;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.92));
}
