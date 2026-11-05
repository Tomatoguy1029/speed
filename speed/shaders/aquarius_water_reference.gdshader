shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform vec4 base_color = vec4(0.498, 0.847, 1.0, 1.0);
uniform vec2 origin_logical;
uniform vec2 direction;
uniform float logical_pixel = 1.0;
uniform float world_scale = 1.0;
uniform float beam_length = 1.0;
uniform float half0 = 0.0;
uniform float slope = 0.0;
uniform float seed = 0.0;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float opacity = 1.0;
uniform float collapse = 0.0;
uniform float mist_life = 0.0;
uniform bool tail = false;

float noise_at(vec2 p, int channel) {
	ivec2 pixel = ivec2(mod(floor(p * 64.0), 512.0));
	vec4 value = texelFetch(noise_tex, pixel, 0);
	return channel == 0 ? value.r : (channel == 1 ? value.g : value.b);
}

float dots(vec2 p, float density, float radius) {
	vec2 cell = floor(p);
	ivec2 index = ivec2(mod(cell * vec2(37.0,61.0) + cell.yx * vec2(13.0,7.0),512.0));
	vec3 data = texelFetch(noise_tex,index,0).rgb;
	if (data.b > density) return 0.0;
	vec2 center = data.rg * 0.5 + 0.25;
	return smoothstep(radius, radius * 0.35, length(fract(p) - center));
}

vec4 ripples(float along, float cw, float side) {
	float inside = 1.0 - smoothstep(0.97,1.0,side);
	float sheet = noise_at(vec2(along*0.003-clock*(0.4+1.4*strength),cw*0.004+seed),0);
	float speed = mix(1.4,5.5,strength*strength);
	float warp = noise_at(vec2(along*0.003,cw*0.006+seed),1)*5.0;
	float wave = 0.5+0.5*sin(along*mix(0.018,0.03,strength)-clock*speed*3.0+warp);
	float crest = smoothstep(0.9,1.0,wave)*smoothstep(0.3,0.6,noise_at(vec2(along*0.005-clock*speed*0.3,cw*0.01+seed),2));
	float line = smoothstep(0.94,0.985,side)*(1.0-smoothstep(0.995,1.025,side));
	float half = max(half0+along*slope,1.0);
	float drops = dots(vec2(along/18.0-clock*mix(14.0,45.0,strength),(side-1.0)*half/10.0+seed),0.55,0.38)*smoothstep(0.9,0.98,side)*smoothstep(1.1,1.0,side);
	float a = inside*((0.025+0.035*strength)*(0.6+sheet)+crest*(0.14+0.3*strength))+line*(0.22+0.33*strength)+drops*(0.45+0.4*strength)+line*0.25*strength+crest*0.15;
	vec3 c = mix(mix(vec3(0.2,0.55,0.95),vec3(0.55,0.88,1.05),crest),vec3(0.7,0.95,1.15),clamp(line+drops,0.0,1.0));
	return vec4(c,clamp(a,0.0,1.0));
}

vec4 rushing(float along, float cw, float side) {
	float ls = noise_at(vec2(along*0.0012-clock*11.0,cw*0.01+seed),0);
	float fs = noise_at(vec2(along*0.0035-clock*26.0,cw*0.045+seed*1.7),1);
	float flow = ls*0.55+fs*0.45;
	float wobble = (noise_at(vec2(along*0.02-clock*40.0,seed),2)-0.5)*0.05;
	float body = 1.0-smoothstep(collapse*0.92,collapse*0.99,side+wobble);
	float brightness = smoothstep(0.75-0.62*collapse,0.85-0.62*collapse,flow);
	float half = max(half0+along*slope,1.0);
	float spray = dots(vec2(along/22.0-clock*120.0,(side-0.9)*half/12.0+seed),0.45,0.3)*smoothstep(0.88*collapse,0.97*collapse,side)*smoothstep(1.12,1.0,side);
	float light = 2.0+1.6*smoothstep(0.35,0.8,flow)+1.5*pow(fs,3.0);
	vec3 c = mix(vec3(light),vec3(0.75,1.0,1.25)*1.8,smoothstep(0.7,0.99,side)*0.6);
	c = mix(c,vec3(0.9,1.05,1.25)*2.2,clamp(spray,0.0,1.0)*(1.0-body));
	return vec4(c,clamp(body*brightness+spray,0.0,1.0));
}

vec4 mist(float along, float cw, float side) {
	float n = noise_at(vec2(along*0.003-clock*0.35,cw*0.004+seed),0);
	float cloud = smoothstep(0.42,0.78,n)*(1.0-smoothstep(0.7,1.1,side));
	float drops = dots(vec2(along/26.0-clock*2.0,cw/26.0+seed),0.3,0.22);
	return vec4(mix(vec3(0.3,0.6,0.9),vec3(0.8,0.98,1.1),drops),clamp((cloud*0.24+drops*0.65)*mist_life,0.0,1.0));
}

vec3 ramp(vec3 c) {
	float lum = (c.r+c.g+c.b)/3.0;
	if (lum > 3.1) return vec3(1.0);
	if (lum > 2.3) return mix(base_color.rgb,vec3(1.0),0.55);
	if (lum > 1.2) return base_color.rgb*vec3(0.85,0.95,1.0);
	if (lum > 0.6) return base_color.rgb*vec3(0.5,0.65,0.85);
	return base_color.rgb*vec3(0.25,0.35,0.55);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy/logical_pixel)+vec2(0.5);
	vec2 relative = (cell-origin_logical)/world_scale;
	float along = dot(relative,direction);
	float q = dot(relative,vec2(-direction.y,direction.x));
	float half = max(half0+along*slope,1.0);
	float side = abs(q/half);
	if (along < 0.0 || along > beam_length || side > 1.12) {
		COLOR = vec4(0.0);
	} else {
		float fade = opacity*(1.0-smoothstep(0.7,1.0,along/beam_length));
		vec4 a = tail ? (collapse > 0.0 ? rushing(along,q,side) : vec4(0.0)) : ripples(along,q,side);
		float alpha_a = a.a*fade;
		vec3 premul = ramp(a.rgb)*alpha_a;
		float alpha = alpha_a;
		if (tail) {
			vec4 b = mist(along,q,side);
			float alpha_b = b.a*fade;
			premul = premul*(1.0-alpha_b)+ramp(b.rgb)*alpha_b;
			alpha += alpha_b*(1.0-alpha);
		}
		COLOR = alpha > 0.003 ? vec4(premul/max(alpha,0.001)*0.85,alpha) : vec4(0.0);
	}
}
