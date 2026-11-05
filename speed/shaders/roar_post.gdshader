shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D snapshot : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D streaks : filter_linear, repeat_disable;
uniform sampler2D lumps : filter_linear, repeat_disable;
uniform vec2 viewport_size;
uniform vec2 center;
uniform vec2 shake;
uniform float clear_radius;
uniform float outer_radius;
uniform float zoom_amount;
uniform float strength;
uniform float envelope;
uniform float band_radius;
uniform float band_width;
uniform float displacement;
uniform float seed;
uniform float age;
uniform float level;
uniform vec4 tint : source_color;
uniform bool first_band;
uniform bool linear_target = true;
vec3 to_srgb(vec3 c) {
	return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
vec3 to_linear(vec3 c) {
	return mix(c/12.92,pow(max((c+0.055)/1.055,vec3(0.0)),vec3(2.4)),step(vec3(0.04045),c));
}

vec4 snapshot_pixel(vec2 pixel,vec2 dimensions) {
	vec2 at=clamp(pixel,vec2(0.0),dimensions-vec2(1.0));
	vec4 value=texture(snapshot,(at+vec2(0.5))/dimensions);
	return vec4(linear_target?to_srgb(value.rgb):value.rgb,value.a);
}
vec4 sample_snapshot(vec2 point) {
	if (point.x<0.0 || point.y<0.0 || point.x>=viewport_size.x || point.y>=viewport_size.y) return vec4(0.0);
	vec2 dimensions=vec2(textureSize(snapshot,0));
	vec2 pixel=point/viewport_size*dimensions-vec2(0.5);
	vec2 base=floor(pixel), f=fract(pixel);
	vec4 top=mix(snapshot_pixel(base,dimensions),snapshot_pixel(base+vec2(1.0,0.0),dimensions),f.x);
	vec4 bottom=mix(snapshot_pixel(base+vec2(0.0,1.0),dimensions),snapshot_pixel(base+vec2(1.0,1.0),dimensions),f.x);
	return mix(top,bottom,f.y);
}
vec4 over(vec4 under, vec4 top, float opacity) {
	float alpha=top.a*opacity;
	return vec4(top.rgb*alpha+under.rgb*(1.0-alpha),alpha+under.a*(1.0-alpha));
}
float ramp(float value,float lo,float hi) {return clamp((value-lo)/max(0.0001,hi-lo),0.0,1.0);}
vec2 turn(vec2 point,float angle) {
	float c=cos(angle),s=sin(angle);
	return vec2(c*point.x-s*point.y,s*point.x+c*point.y);
}
float texture_mask(sampler2D image,vec2 point,float angle,float size) {
	vec2 uv=turn(point,-angle)/size+vec2(0.5);
	if (uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0) return 0.0;
	return texture(image,uv).a;
}
void fragment() {
	vec2 point=SCREEN_UV*viewport_size;
	vec2 delta=point-center;
	float radius=length(delta);
	vec4 original=sample_snapshot(point);
	vec4 result=over(original,sample_snapshot(point-shake),1.0);
	if (zoom_amount>0.002) {
		vec4 blur=original;
		for (int i=1;i<=6;i++) {
			float k=1.0+zoom_amount*float(i)/6.0;
			blur=over(blur,sample_snapshot(center+delta/k),0.55/float(i)+0.1);
		}
		float mask=ramp(radius,clear_radius,clear_radius*1.6)*(1.0-ramp(radius,outer_radius*0.8,outer_radius*1.25));
		result=over(result,blur,mask*min(1.0,strength*envelope*1.2));
	}
	if (displacement>0.0 && band_radius>1.0) {
		vec4 band=sample_snapshot(center+delta/(1.0+displacement));
		float alpha=0.1*(0.5+0.5*level/3.0);
		vec3 hue=linear_target?to_srgb(tint.rgb):tint.rgb;
		if (first_band) band=vec4(min(vec3(1.0),band.rgb+hue*alpha),band.a);
		else band=vec4(hue,alpha);
		float mask=ramp(radius,max(0.0,band_radius-band_width),band_radius-band_width*0.3)*(1.0-ramp(radius,band_radius,band_radius+band_width*0.35));
		float size=(band_radius+band_width)*2.4;
		mask*=texture_mask(streaks,delta,seed*1.7,size);
		mask*=texture_mask(lumps,delta,seed*4.0+age*0.8,size);
		result=over(result,band,mask*min(1.0,strength*envelope*1.4));
	}
	COLOR=vec4(linear_target?to_linear(result.rgb):result.rgb,result.a);
}
