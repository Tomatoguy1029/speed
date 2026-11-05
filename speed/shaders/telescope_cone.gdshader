shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.0;
uniform float half_angle = 0.0;
uniform float facing = 0.0;
uniform bool ship_glow = false;

void fragment() {
	vec2 delta = (UV - vec2(0.5)) * 2.0;
	float radius = length(delta);
	float alpha = 0.0;
	if (ship_glow) {
		alpha = max(0.0, 1.0 - radius) * strength;
	} else if (radius < 1.0 && half_angle > 0.0) {
		float angle = abs(mod(atan(delta.y, delta.x) - facing + 3.14159265359, 6.28318530718) - 3.14159265359);
		float layers = 0.0;
		for (int n = 0; n < 6; n++) {
			if (angle <= half_angle * (1.0 - float(n) / 6.0)) layers += 1.0;
		}
		float radial = radius < 0.35 ? mix(1.6, 1.0, radius / 0.35) : (1.0 - radius) / 0.65;
		alpha = strength * radial * layers / 6.0;
	}
	COLOR = vec4(tint.rgb, alpha);
}
