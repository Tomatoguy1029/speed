// 密度結合 → 局所変形 → ピクセル化 → alpha輪郭補正 → 独立色層 → 弱い多層発光。
shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float density_threshold = 0.43;
uniform float edge_softness = 0.055;
uniform float distortion = 2.3;
uniform float pixel_size = 2.0;
uniform vec4 outline_color : source_color = vec4(0.79, 0.2, 0.12, 1.0);
uniform vec4 outer_color : source_color = vec4(0.98, 0.41, 0.14, 1.0);
uniform vec4 inner_color : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.69, 1.0);
uniform float glow_strength = 0.18;
uniform float opacity = 0.98;
// 0=合成、1=外炎、2=内炎、3=芯、4=輪郭補正前の密度。
uniform int view_mode = 0;

vec3 density(sampler2D field, vec2 uv, vec2 texel) {
	// 粒子が作った形を数pxだけ曲げる。ここでは新しい輪郭を発生させない。
	vec2 p = uv / texel;
	vec2 curl = vec2(sin(p.y * 0.095 + clock * 3.7) + sin(p.y * 0.19 - p.x * 0.07 + clock * 2.1) * 0.4,
		cos(p.x * 0.12 + clock * 2.9) * 0.35);
	vec2 at = uv + curl * distortion * texel;
	return texture(field, clamp(at, texel, vec2(1.0) - texel)).rgb;
}

float contour(float value) {
	float alpha = smoothstep(density_threshold, density_threshold + edge_softness, value);
	// ぼけた密度を、細い1段の縁を持つドットの面へ戻す。
	return floor(alpha * 3.0 + 0.5) / 3.0;
}

void fragment() {
	vec2 cell = TEXTURE_PIXEL_SIZE * pixel_size;
	vec2 p = (floor(UV / cell) + 0.5) * cell;
	vec3 d = density(TEXTURE, p, TEXTURE_PIXEL_SIZE);
	float outer = contour(d.r);
	float inner = min(outer, contour(d.g));
	float core = min(inner, contour(d.b));
	float fill = smoothstep(density_threshold + 0.12, density_threshold + 0.3, d.r);
	vec3 color = mix(outline_color.rgb, outer_color.rgb, fill);
	color = mix(color, inner_color.rgb, inner);
	color = mix(color, core_color.rgb, core);
	float alpha = outer * opacity;
	if (view_mode > 0 && view_mode < 4) {
		alpha = (view_mode == 1 ? outer : (view_mode == 2 ? contour(d.g) : contour(d.b))) * opacity;
		color = view_mode == 1 ? outer_color.rgb : (view_mode == 2 ? inner_color.rgb : core_color.rgb);
	}
	// 各半径は独立した弱い光。大きな円形マスクや画面全体のbloomを使わない。
	vec3 halo = vec3(0.0);
	for (int ring = 0; ring < 3; ring++) {
		float radius = ring == 0 ? 2.0 : (ring == 1 ? 5.5 : 11.0);
		float weight = ring == 0 ? 0.5 : (ring == 1 ? 0.3 : 0.2);
		vec3 sum = vec3(0.0);
		for (int tap = 0; tap < 8; tap++) {
			float angle = float(tap) * 0.785398;
			sum += density(TEXTURE, p + vec2(cos(angle), sin(angle)) * radius * TEXTURE_PIXEL_SIZE, TEXTURE_PIXEL_SIZE);
		}
		halo += sum * (weight / 8.0);
	}
	vec3 light = (outline_color.rgb * halo.r * 0.7 + inner_color.rgb * halo.g * 0.2 + core_color.rgb * halo.b * 0.1) * glow_strength;
	float light_alpha = max(light.r, max(light.g, light.b)) * opacity;
	if (view_mode != 0) { light_alpha = 0.0; }
	float combined = alpha + light_alpha * (1.0 - alpha);
	color = (color * alpha + light * opacity * (1.0 - alpha)) / max(0.0001, combined);
	if (view_mode == 4) {
		color = d;
		combined = max(d.r, max(d.g, d.b));
	}
	COLOR = vec4(color, combined);
}
