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
uniform float stretch = 2.6;
uniform float lift = 0.24;

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
	// 縦に伸ばした流れを上へ送り、太い根元から細い先端へつながる炎の舌を作る。
	// 消える間は形を上へ持ち上げ、ノイズの薄い部分からちぎる。
	vec2 plume = p + vec2(0.0, smoothstep(0.18, 1.0, age) * lift);
	float plume_r = length(plume);
	vec2 flow_uv = vec2(plume.x * 0.65, plume.y * 0.65 / max(1.0, stretch));
	vec3 n = texture(noise_tex, flow_uv * 0.6 + vec2(seed, t * 0.22)).rgb;
	flow_uv.x += (n.g - 0.5) * 0.34 * turbulence;
	float curl = texture(noise_tex, flow_uv + vec2(seed, t * 0.36)).g;
	float fine = texture(noise_tex, flow_uv * 2.2 + vec2(seed, t * 0.53)).b;
	float flow = curl * 0.68 + n.r * 0.24 + fine * 0.08;
	float front = mix(0.28, 1.0, smoothstep(0.0, 0.24, age));
	float rim = 1.0 - smoothstep(front - 0.08, front + 0.02, plume_r + (curl - 0.5) * 0.14 * turbulence);
	float hollow = smoothstep(age * 0.32 - 0.18, age * 0.32 + 0.12, plume_r);
	float breakup = smoothstep(0.42, 1.0, age);
	float threshold = 0.70 - amount * 0.32 + breakup * 0.27;
	float tongues = smoothstep(threshold, threshold + 0.13, flow + (1.0 - plume_r) * 0.08);
	float life = 1.0 - smoothstep(0.68, 1.0, age);
	float heat = clamp((flow - threshold) * 3.1 + 0.18 - breakup * 0.5, 0.0, 1.0);
	// 少ない色の面を重ね、細かなノイズを全面の黄色い斑点にしない。
	vec3 fire = mix(ember_color.rgb, flame_color.rgb, step(0.26, heat));
	fire = mix(fire, hot_color.rgb, step(0.64, heat));
	fire *= 1.0 + emission * step(0.76, heat);
	float fire_alpha = rim * hollow * tongues * life * opacity;
	float smoke = rim * smoothstep(0.43, 0.75, n.b) * (1.0 - tongues) * life * 0.14;
	// セルごとに形・速さ・明滅を変えた火の粉。予告は降り、着地では外へ散る。
	vec2 dust_p = p * vec2(11.0, 8.0) + vec2(sin(p.y * 3.0 + t + seed) * 0.3, t * mix(-1.7, 2.8, attack));
	vec2 grid = floor(dust_p);
	float h = hash(grid + seed);
	vec2 local = fract(dust_p) - vec2(0.2 + h * 0.6, 0.2 + fract(h * 7.0) * 0.6);
	float shape = 1.0 - smoothstep(0.06, 0.12, max(abs(local.x) * (1.0 + h), abs(local.y) * (0.75 + h * 0.5)));
	float dust = shape * step(1.0 - sparks * 0.48, h) * (0.6 + 0.4 * sin(t * (3.0 + h * 5.0) + h * 19.0));
	dust *= (1.0 - smoothstep(1.0, 1.18, r)) * mix(0.35 + age * 0.65, life, attack);
	vec3 color = mix(smoke_color.rgb, fire, fire_alpha / max(0.001, fire_alpha + smoke));
	vec3 spark_color = mix(ember_color.rgb, hot_color.rgb * (1.0 + emission), dust);
	color = mix(color, spark_color, clamp(dust, 0.0, 1.0));
	float alpha = (fire_alpha + smoke) * attack + dust;
	COLOR = vec4(color, clamp(alpha, 0.0, 0.92));
}
