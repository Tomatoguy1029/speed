shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform float strength = 0.0;
uniform sampler2D snapshot : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool linear_target = true;

vec3 to_srgb(vec3 c) {
	return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
vec3 to_linear(vec3 c) {
	return mix(c/12.92,pow(max((c+0.055)/1.055,vec3(0.0)),vec3(2.4)),step(vec3(0.04045),c));
}

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float mask = clamp((1.0 - radius) / 0.85, 0.0, 1.0);
	vec4 under = texture(snapshot,SCREEN_UV);
	vec3 base = linear_target ? to_srgb(under.rgb) : under.rgb;
	vec3 rgb = floor(clamp(mix(base,vec3(2.0,4.0,12.0)/255.0,strength*mask),0.0,1.0)*255.0+0.5)/255.0;
	COLOR = vec4(linear_target ? to_linear(rgb) : rgb,under.a);
}
