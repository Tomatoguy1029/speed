shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D snapshot : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D sprite_pixels : filter_nearest, repeat_disable;
uniform bool linear_target = true;
uniform float opacity = 0.0;
uniform float white_add = 0.0;

vec3 to_srgb(vec3 c) {
	return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
vec3 to_linear(vec3 c) {
	return mix(c/12.92,pow(max((c+0.055)/1.055,vec3(0.0)),vec3(2.4)),step(vec3(0.04045),c));
}

void fragment() {
	vec4 under = texture(snapshot,SCREEN_UV);
	vec4 pixel = texture(sprite_pixels,UV);
	if (pixel.a<=0.0) {
		COLOR=under;
	} else {
		vec3 base=linear_target ? to_srgb(under.rgb) : under.rgb;
		vec3 rgb=floor(clamp(mix(base,pixel.rgb,pixel.a*opacity),0.0,1.0)*255.0+0.5)/255.0;
		rgb=floor(min(vec3(1.0),rgb+vec3(pixel.a*white_add))*255.0+0.5)/255.0;
		COLOR=vec4(linear_target ? to_linear(rgb) : rgb,under.a);
	}
}
