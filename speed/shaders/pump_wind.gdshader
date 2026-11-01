shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
varying vec2 local_pixel;
void vertex() { local_pixel = VERTEX + vec2(75.0, 0.0); }
void fragment() {
	vec2 p = floor(local_pixel / 2.0 + 0.5);
	float alpha = 0.0;
	for (int j = 0; j < 18; j++) {
		float k = float(j);
		float phase = fract(clock / (0.48 + mod(k * 37.0, 11.0) * 0.035) + k * 0.6180339);
		float radius = 10.0 + (1.0 - phase) * (24.0 + mod(k * 13.0, 43.0));
		float angle = -1.3 + k / 17.0 * 2.6;
		vec2 u = vec2(cos(angle), sin(angle));
		float along = dot(p, u) - radius;
		float span = 4.0 + (5.0 + mod(k * 7.0, 13.0)) * 0.45;
		if (along >= 0.0 && along <= span && abs(dot(p, vec2(-u.y, u.x))) < 0.65) {
			float light = (0.25 + 0.45 * mod(k * 11.0, 17.0) / 16.0) * sin(phase * PI);
			alpha = max(alpha, light * (1.0 - 0.72 * along / span));
		}
	}
	COLOR = vec4(vec3(0.95, 0.98, 1.0), alpha);
}
