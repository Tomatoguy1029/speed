shader_type canvas_item;
render_mode unshaded;

uniform sampler2D sweep_texture : filter_nearest, repeat_disable;
uniform sampler2D stars_texture : filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform bool panel_open = false;

void fragment() {
	vec2 canvas = vec2(640.0, 360.0);
	vec2 center = vec2(462.0, 176.0);
	vec2 offset = UV * canvas - center;
	float rotation = elapsed * TAU / 16.0;
	float c = cos(rotation);
	float s = sin(rotation);
	vec2 source = vec2(c * offset.x + s * offset.y, -s * offset.x + c * offset.y);
	vec2 sweep_uv = (source + center) / canvas;
	vec4 sweep = texture(sweep_texture, clamp(sweep_uv, vec2(0.0), vec2(1.0)));
	float inside = step(length(offset), 150.0);
	float age = mod(rotation - (atan(offset.y, offset.x) + PI * 0.5) + TAU, TAU);
	float fade = exp(-age * 0.625) * step(age, rotation);
	vec4 stars = texture(stars_texture, UV);
	vec4 base = texture(TEXTURE, UV);
	if (panel_open && UV.x * canvas.x < 280.0 && UV.y * canvas.y > 65.0 && UV.y * canvas.y < 140.0) {
		base.rgb = vec3(0.0);
	}
	vec3 radar = sweep.rgb * sweep.a * 0.45 + stars.rgb * stars.a * fade;
	COLOR = vec4(max(base.rgb, radar * inside), 1.0);
}
