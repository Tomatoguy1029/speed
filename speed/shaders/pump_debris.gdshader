shader_type canvas_item;
render_mode unshaded;
uniform sampler2D pump_art : source_color, filter_nearest;
uniform sampler2D enemy0 : source_color, filter_nearest;
uniform sampler2D enemy1 : source_color, filter_nearest;
uniform sampler2D enemy2 : source_color, filter_nearest;
uniform float age = 0.0;
uniform float life = 1.0;
uniform float speed = 900.0;
uniform float clock = 0.0;
uniform float seed = 0.0;
uniform float pixel = 2.0;
uniform float spin = 0.0;
uniform int kind = -1;
uniform bool linear_output = false;
varying vec2 local_pixel;
const vec2 PATCH[8] = vec2[8](vec2(8,22),vec2(17,22),vec2(6,24),vec2(18,24),vec2(8,33),vec2(15,33),vec2(10,13),vec2(14,13));
void vertex() { local_pixel = VERTEX - vec2(128.0,0); }
vec3 to_linear(vec3 c) { return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c)); }
void fragment() {
	vec2 p = floor(local_pixel / pixel + 0.5) * pixel;
	float fade = clamp(life / 0.18,0.0,1.0);
	float tail_length = min(178.0 + mod(seed * 11.0,70.0), speed * age) * fade;
	float k = clamp(-p.x / max(tail_length,0.001),0.0,1.0);
	float width = pow(1.0-k,0.8)*(6.7+mod(seed,3.0)*1.18)*(0.94+0.06*sin(clock*44.0+seed+k*6.0));
	float edge = abs(p.y)/max(width,0.001);
	vec4 light = vec4(0);
	if (p.x <= 0.0 && p.x > -tail_length && edge < 1.0) {
		vec3 color = mix(vec3(0.1569,0.3725,0.3412),vec3(0.4039,0.7294,0.6314),1.0-edge);
		if (abs(p.y)<pixel && k<0.6) color = mix(vec3(0.5490,0.7647,0.6588),vec3(0.8471,1.0,0.9412),0.8+0.2*sin(clock*30.0+seed));
		if (linear_output) color = to_linear(color);
		light = vec4(color,pow(1.0-k,0.72)*fade*(1.0-0.35*edge));
		if (edge>0.7 && mod(floor(-p.x/pixel)*3.0+floor(p.y/pixel)+seed+floor(clock*30.0),4.0)<1.0) light.a = 0.0;
	}
	vec2 q = kind < 0 ? mat2(vec2(cos(spin),-sin(spin)),vec2(sin(spin),cos(spin))) * p : vec2(p.y,-p.x);
	vec4 art = vec4(0);
	if (kind < 0 && all(lessThan(abs(q),vec2(5.0)))) {
		vec2 uv = (PATCH[int(mod(seed,8.0))] + floor(q/2.0) + 0.5) / vec2(24,37);
		art = texture(pump_art,uv);
	} else if (kind >= 0) {
		vec2 uv = q/(kind == 2 ? vec2(9,18) : vec2(18))+0.5;
		if (all(greaterThanEqual(uv,vec2(0))) && all(lessThan(uv,vec2(1)))) art = kind == 0 ? texture(enemy0,uv) : (kind == 1 ? texture(enemy1,uv) : texture(enemy2,uv));
	}
	art.a *= fade;
	COLOR = art.a > 0.01 ? art : light;
}
