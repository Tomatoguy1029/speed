// core.js blitFrame: RGBA8の通常色を重ね、その後sRGB上で光を加算する。
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D snapshot : hint_screen_texture, filter_nearest, repeat_disable;
// source_colorを付けず、Painterが作ったsRGBのバイト値をそのまま読む。
uniform sampler2D color_pixels : filter_nearest, repeat_disable;
uniform sampler2D light_pixels : filter_nearest, repeat_disable;
uniform bool linear_target = true;
uniform bool has_light = false;
vec3 to_srgb(vec3 c) {
	return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
vec3 to_linear(vec3 c) {
	return mix(c/12.92,pow(max((c+0.055)/1.055,vec3(0.0)),vec3(2.4)),step(vec3(0.04045),c));
}
void fragment() {
	vec4 under=texture(snapshot,SCREEN_UV);
	vec4 color=texture(color_pixels,UV);
	vec3 light=texture(light_pixels,UV).rgb;
	if (color.a<=0.0 && all(equal(light,vec3(0.0)))) {
		// FXがない画素のHDR輝度を保つ。lighterの黒面はalphaだけを満たす。
		COLOR=vec4(under.rgb,has_light?1.0:under.a);
	} else {
		vec3 base=linear_target?to_srgb(under.rgb):under.rgb;
		float alpha=color.a+under.a*(1.0-color.a);
		vec3 premult=color.rgb*color.a+base*under.a*(1.0-color.a);
		// Canvas2Dのsource-overの結果を8bitへ戻してからlighterを適用する。
		vec3 rgb=alpha>0.0?floor(clamp(premult/alpha,0.0,1.0)*255.0+0.5)/255.0:vec3(0.0);
		if (has_light) {rgb=min(vec3(1.0),rgb*alpha+light);alpha=1.0;}
		COLOR=vec4(linear_target?to_linear(rgb):rgb,alpha);
	}
}
