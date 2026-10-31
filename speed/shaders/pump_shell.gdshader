// Adapted from https://github.com/patch-gg/pixelfx/blob/main/src/fx/projectiles/laser-bolt.js
// Original banded energy beam: https://www.spritefusion.com/pixel-art-vfx/energy
// MIT License
//
// Copyright (c) 2026 Patch
// Copyright (c) 2026 Hugo Duprez
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D enemy0 : source_color, filter_nearest;
uniform sampler2D enemy1 : source_color, filter_nearest;
uniform sampler2D enemy2 : source_color, filter_nearest;
uniform float clock = 0.0;
group_uniforms tuning;
uniform vec4 bolt_dark : source_color = vec4(0.0784, 0.4706, 0.2706, 1.0);
uniform vec4 bolt_edge : source_color = vec4(0.1255, 0.6784, 0.3529, 1.0);
uniform vec4 bolt_mid : source_color = vec4(0.2118, 0.9294, 0.4784, 1.0);
uniform vec4 bolt_pale : source_color = vec4(0.5412, 1.0, 0.6980, 1.0);
uniform vec4 bolt_light : source_color = vec4(0.8275, 1.0, 0.8980, 1.0);
uniform vec4 bolt_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float bolt_scale : hint_range(0.5, 4.0, 0.1) = 3.0;
uniform float bolt_length : hint_range(16.0, 64.0, 1.0) = 40.0;
uniform float bolt_width : hint_range(0.5, 2.0, 0.05) = 1.0;
uniform float bolt_period : hint_range(0.1, 2.0, 0.05) = 0.5;
uniform float bolt_brightness : hint_range(0.25, 4.0, 0.05) = 1.0;
uniform float pulse_speed : hint_range(0.0, 8.0, 0.1) = 3.0;
uniform float pulse_strength : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float spiral_opacity : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float tail_count : hint_range(0.0, 14.0, 1.0) = 14.0;
uniform float tail_opacity : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float glint_scale : hint_range(0.0, 2.0, 0.1) = 1.0;
uniform float glow_strength : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float contents_opacity : hint_range(0.0, 1.0, 0.05) = 0.0;
group_uniforms;
varying vec2 bolt_pixel;
const vec2 POS[7] = vec2[7](vec2(0,-13),vec2(-14,-4),vec2(13,-3),vec2(-10,12),vec2(12,12),vec2(1,9),vec2(0,-1));
const float SIZES[7] = float[7](0.78,0.72,0.70,0.70,0.76,0.78,0.86);
const float ANGLES[7] = float[7](-0.314159,0.174533,-0.20944,0.523599,-0.349066,0.139626,0.0);

// 固定seed=2の元のbeat/Rng値。固定乱数は制作時に計算し、実行時は経過時刻だけを使う。
const float DASH_LIFE[14] = float[14](0.216977138,0.206188485,0.184512723,0.231024276,0.297894948,0.270184234,0.196779335,0.279523689,0.205163588,0.229678093,0.215649000,0.240862708,0.189775562,0.279919387);
const float DASH_SPEED[14] = float[14](166.710021403,225.850652978,214.750811439,220.731766932,215.703779552,210.474469531,182.992129084,188.235764969,229.655174501,183.260197788,223.109547067,170.215984099,190.943939667,162.188824639);
const float DASH_LENGTH[14] = float[14](6.450921136,6.457275423,4.406623228,5.117607022,3.703897836,3.926424518,6.520277004,4.672039022,6.433415536,5.537434155,6.649287096,5.040151072,5.893924965,4.058034878);
const float DASH_JITTER[14] = float[14](0.581434672,0.317614623,0.261262306,0.351650613,-0.338971980,-0.497362556,0.289197627,-0.163674400,-0.036491740,0.129276842,0.055147833,-0.088160116,-0.573155767,0.104019346);
const float DASH_SALT[14] = float[14](84.000000000,791.000000000,477.000000000,675.000000000,703.000000000,491.000000000,229.000000000,334.000000000,106.000000000,912.000000000,79.000000000,38.000000000,789.000000000,353.000000000);

void vertex() {
	// 元の128x32とpivot(108,16)。55は既存の弾ノードの位置補正と相殺する。
	bolt_pixel = UV*vec2(128.0,32.0)-vec2(108.0,16.0);
	VERTEX = bolt_pixel*bolt_scale+vec2(55.0,0.0);
}
uint hash_step(uint h, uint n) {
	h = (h^n)*0x85ebca6bu;
	h ^= h>>13u;
	h *= 0xc2b2ae35u;
	return h^(h>>16u);
}
float random2(int a, int b) {
	return float(hash_step(hash_step(0x9e3779b9u,uint(a)),uint(b)))/4294967296.0;
}
vec4 ramp(int level) {
	if (level <= 2) return bolt_dark;
	if (level == 3) return bolt_edge;
	if (level == 4) return bolt_mid;
	if (level == 5) return bolt_pale;
	if (level == 6) return bolt_light;
	return bolt_core;
}
float glow_at(vec2 p, vec2 center, float radius) {
	float f = max(0.0,1.0-length(p-center)/max(radius,0.01));
	return f*f;
}
vec4 piece(int j, vec2 uv) {
	return j == 0 || j == 5 || j == 6 ? texture(enemy0,uv) : (j == 1 || j == 4 ? texture(enemy1,uv) : texture(enemy2,uv));
}
void fragment() {
	vec2 cell = floor(bolt_pixel);
	vec2 p = cell+0.5;
	float phase = clock/bolt_period;
	int frame = int(floor(clock*30.0+0.000001));
	vec4 col = vec4(0.0);
	vec3 light = vec3(0.0);
	// 元の等間隔beat。後ろへ揺れ、冷えながら離れる短いdash。
	for (int i=0; i<14; i++) {
		if (float(i) >= tail_count) break;
		float age = mod(clock-float(i)*bolt_period/max(tail_count,1.0)+0.0000001,bolt_period);
		float k = age/DASH_LIFE[i];
		if (k >= 1.0) continue;
		float x0 = -bolt_length*0.8-age*DASH_SPEED[i];
		float len = DASH_LENGTH[i]*(1.0-k*0.5);
		float y = 0.5+sin(x0*0.25+phase*TAU*2.0)*(0.5+k*1.5)+DASH_JITTER[i]*k;
		if (x0-len < -106.0 || random2(frame,int(DASH_SALT[i])) < k*0.5) continue;
		if (cell.x <= floor(x0) && cell.x >= floor(x0-len) && cell.y == floor(y)) {
			col = ramp(k < 0.3 ? 5 : k < 0.6 ? 4 : 3);
			col.a *= tail_opacity;
		}
		if (k < 0.4) light += bolt_mid.rgb*glow_at(p,vec2(x0-len*0.5,y),4.0)*0.3*(1.0-k)*tail_opacity;
	}
	// 丸い頭、白い芯と段階色、後方へ細くなる帯、帯を走るパルス。
	float d = -p.x+3.0;
	float u = d/(bolt_length+3.0);
	if (u >= 0.0 && u <= 1.0 && p.y >= -5.0*bolt_width && p.y <= 6.0*bolt_width) {
		float head = d < 3.0 ? sqrt(max(0.0,1.0-pow((3.0-d)/3.0,2.0))) : 1.0;
		float width = (3.4*pow(1.0-u,0.9)+0.5)*head*(1.0+0.08*sin(d*0.9-phase*TAU*4.0))*bolt_width;
		float v = abs(p.y-0.5)/max(width,0.001);
		if (v <= 1.2 && !(v > 1.0 && (u > 0.5 || random2(int(floor(p.x)),frame) > 0.6))) {
			int level = v < 0.22 ? (u < 0.6 ? 7 : 6) : v < 0.45 ? 6-(u > 0.5 ? 1 : 0) : v < 0.72 ? 4 : v <= 1.0 ? 3 : 2;
			bool pulse = mod(d*0.05-phase*pulse_speed,1.0) < 0.12 && v < 0.72;
			col = mix(ramp(level),ramp(min(7,level+1)),pulse ? pulse_strength : 0.0);
		}
	}
	// 元の二重らせん。各pixelのxから粒の距離を直接求め、全粒走査を避ける。
	float sd = -cell.x;
	if (sd >= 2.0 && sd < bolt_length*0.7) {
		for (int side=0; side<2; side++) {
			float a = sd*0.45-phase*TAU*3.0+float(side)*PI;
			float sy = 0.5+sin(a)*(2.2*(1.0-sd/bolt_length)+0.6)*bolt_width;
			if (cos(a) > 0.3 && cell.y == floor(sy)) col = mix(col,cos(a) > 0.8 ? bolt_core : bolt_light,spiral_opacity);
		}
	}
	float glint = 0.75+0.25*sin(phase*TAU*2.0);
	float arm = floor((3.0+floor(glint*2.0+0.5))*glint_scale+0.5);
	vec2 delta = cell-vec2(1.0,0.0);
	float distance = max(abs(delta.x),abs(delta.y));
	if (arm >= 1.0) {
		if ((delta.x == 0.0 || delta.y == 0.0) && distance > 0.0 && distance <= arm) col = distance > arm*0.6 ? bolt_mid : bolt_light;
		if (arm >= 3.0 && abs(delta.x) == 1.0 && abs(delta.y) == 1.0) col = bolt_light;
		if (arm >= 6.0 && abs(delta.x) == 2.0 && abs(delta.y) == 2.0) col = bolt_mid;
		if (distance == 0.0) col = bolt_core;
		light += bolt_light.rgb*glow_at(p,vec2(1.0,0.5),4.0+arm*2.0)*0.5;
	}
	// 圧縮した実雑魚は任意表示。元絵は維持し、芯の中へ縮尺表示する。
	if (contents_opacity > 0.001 && abs(p.x) < 10.0 && abs(p.y) < 10.0) {
		for (int j=0; j<7; j++) {
			float a = ANGLES[j];
			vec2 size = j == 0 || j == 5 || j == 6 ? vec2(23) : (j == 1 || j == 4 ? vec2(32) : vec2(13,26));
			vec2 uv = mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*(p*4.0-POS[j])/(size*SIZES[j])+0.5;
			if (all(greaterThanEqual(uv,vec2(0))) && all(lessThan(uv,vec2(1)))) {
				vec4 art = piece(j,uv);
				col.rgb = mix(col.rgb,art.rgb,art.a*contents_opacity);
				col.a = max(col.a,art.a*contents_opacity);
			}
		}
	}
	vec2 closest = vec2(clamp(p.x,-bolt_length,1.0),0.5);
	light += bolt_edge.rgb*glow_at(p,closest,9.0)*0.4;
	light += bolt_edge.rgb*glow_at(p,vec2(-2.0,0.5),20.0)*0.5*glint;
	light += bolt_core.rgb*glow_at(p,vec2(1.0,0.5),6.0)*0.25;
	COLOR = vec4((col.rgb*col.a+light*glow_strength)*bolt_brightness,col.a);
}
