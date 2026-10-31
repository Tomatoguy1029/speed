shader_type canvas_item;
render_mode unshaded;
uniform sampler2D enemy0 : source_color, filter_nearest;
uniform sampler2D enemy1 : source_color, filter_nearest;
uniform sampler2D enemy2 : source_color, filter_nearest;
uniform float clock = 0.0;
varying vec2 local_pixel;
const vec2 POS[7] = vec2[7](vec2(0,-13),vec2(-14,-4),vec2(13,-3),vec2(-10,12),vec2(12,12),vec2(1,9),vec2(0,-1));
const float SIZES[7] = float[7](0.78,0.72,0.70,0.70,0.76,0.78,0.86);
const float ANGLES[7] = float[7](-0.314159,0.174533,-0.20944,0.523599,-0.349066,0.139626,0.0);
void vertex() { local_pixel = VERTEX - vec2(55.0,0); }
vec4 piece(int j, vec2 uv) {
	return j == 0 || j == 5 || j == 6 ? texture(enemy0, uv) : (j == 1 || j == 4 ? texture(enemy1, uv) : texture(enemy2, uv));
}
void fragment() {
	vec2 p = floor(local_pixel + 0.5);
	vec4 pack = vec4(0);
	float halo = 0.0;
	for (int j=0; j<7; j++) {
		float a = ANGLES[j];
		vec2 v = p-POS[j];
		vec2 source_size = j == 0 || j == 5 || j == 6 ? vec2(23) : (j == 1 || j == 4 ? vec2(32) : vec2(13,26));
		vec2 uv = mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a))) * v / (source_size*SIZES[j]) + 0.5;
		if (all(greaterThanEqual(uv,vec2(0))) && all(lessThan(uv,vec2(1)))) {
			vec4 art = piece(j,uv);
			pack.rgb = mix(pack.rgb,art.rgb,art.a);
			pack.a = max(pack.a,art.a);
			halo = max(halo, piece(j,uv+vec2(0.04,0)).a * 0.10);
		}
	}
	float tail = clamp((-p.x-20.0)/46.0,0.0,1.0);
	float tail_a = p.x < -20.0 && p.x > -66.0 && abs(p.y) < (1.0-tail)*2.5 ? 0.47*pow(1.0-tail,1.2) : 0.0;
	if (mod(p.x+p.y+floor(clock*30.0),6.0)<1.0) tail_a *= 0.2;
	vec4 light = vec4(0.65,1.0,0.80,max(tail_a,halo));
	COLOR = pack.a > 0.01 ? pack : light;
}
