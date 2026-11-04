shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D snapshot : hint_screen_texture, filter_nearest, repeat_disable;

uniform vec4 base_color;
uniform vec2 origin_logical;
uniform vec2 direction;
uniform vec2 logical_size;
uniform float logical_pixel;
uniform float world_scale;
uniform float beam_length;
uniform float half0;
uniform float slope;
uniform int seed;
uniform float clock;
uniform float opacity;
uniform bool linear_target = true;

uint hash3(int x, int y, int s) {
	uint h = 0x9e3779b9u;
	h = (h ^ uint(x)) * 0x85ebca6bu; h ^= h >> 13u; h *= 0xc2b2ae35u; h ^= h >> 16u;
	h = (h ^ uint(y)) * 0x85ebca6bu; h ^= h >> 13u; h *= 0xc2b2ae35u; h ^= h >> 16u;
	h = (h ^ uint(s)) * 0x85ebca6bu; h ^= h >> 13u; h *= 0xc2b2ae35u; h ^= h >> 16u;
	return h;
}
float random_at(ivec2 p, int s) { return float(hash3(p.x,p.y,s)) / 4294967296.0; }
float water_noise(vec2 p, int s) {
	ivec2 i = ivec2(floor(p)); vec2 f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(random_at(i,s),random_at(i+ivec2(1,0),s),u.x),mix(random_at(i+ivec2(0,1),s),random_at(i+ivec2(1,1),s),u.x),u.y)*2.0-1.0;
}
vec3 to_srgb(vec3 c) {
 vec3 low = c * 12.92; vec3 high = 1.055 * pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055;
 return mix(high,low,lessThanEqual(c,vec3(0.0031308)));
}
vec3 to_linear(vec3 c) {
 vec3 low = c / 12.92; vec3 high = pow((c+0.055)/1.055,vec3(2.4));
 return mix(high,low,lessThanEqual(c,vec3(0.04045)));
}
vec3 mix8(vec3 a,vec3 b,float k) { return floor(mix(a,b,k)*255.0)/255.0; }
vec3 palette(int level) {
 vec3 dark = vec3(4.0,16.0,30.0)/255.0;
 vec3 base = round(clamp(base_color.rgb,0.0,1.0)*255.0)/255.0;
 if(level==0) return mix8(dark,base,0.12);
 if(level==1) return mix8(dark,base,0.25);
 if(level==2) return mix8(dark,base,0.45);
 if(level==3) return mix8(dark,base,0.7);
 if(level==4) return base;
 if(level==5) return mix8(base,vec3(1.0),0.35);
 if(level==6) return mix8(base,vec3(1.0),0.7);
 return vec3(1.0);
}
float width_at(float d,float full_length,float side_y) {
	float u=d/full_length; float rough=smoothstep(0.1,1.0,u);
	float sd=mod(d-clock*520.0,150.0)-75.0;
	float h=max(1.2,(half0+d/world_scale*slope)*world_scale)*(1.0+exp(-sd*sd/160.0)*0.12*(1.0-u*0.5));
	return h*(1.0+water_noise(vec2(d*0.09-clock*30.0,side_y),seed+1)*0.16*rough);
}
void fragment() {
 vec2 cell=floor(FRAGCOORD.xy/logical_pixel)+vec2(0.5); vec2 relative=cell-origin_logical;
 float d=dot(relative,direction); float q=dot(relative,vec2(-direction.y,direction.x));
 float full_length=beam_length*world_scale; float view=length(logical_size); float maximum=min(full_length,view*1.2);
 vec3 added=vec3(0.0); float max_radius=10.0+view*0.06;
 int first=max(0,int(floor((d-max_radius)/12.0))); int last=int(ceil((d+max_radius)/12.0));
 for(int i=first;i<=last;i++) {
  float along=float(i)*12.0; if(along>=min(full_length,view)) break;
  float radius=10.0+along*0.06; float distance=length(relative-direction*along)/radius;
  if(distance<1.0) { float strength=(1.0-distance)*(1.0-distance)*0.18*opacity*(1.0-along/full_length*0.6);
   if(strength>0.004) added=min(vec3(255.0),added+floor(floor(palette(4)*255.0)*strength)); }
 }
 if(d>=1.0 && d<maximum) {
  float last_distance=float(int(ceil(maximum))); vec2 far=origin_logical+direction*maximum; vec2 normal=vec2(-direction.y,direction.x);
  vec2 a=far+normal*width_at(last_distance,full_length,9.0); vec2 b=far-normal*width_at(last_distance,full_length,3.0);
  vec2 lo=min(origin_logical,min(a,b)); vec2 hi=max(origin_logical,max(a,b));
  bool bounds=all(greaterThanEqual(floor(cell),floor(lo-vec2(2.0)))) && all(lessThan(floor(cell),ceil(hi+vec2(2.0))));
  float aq=abs(q)/max(0.8,width_at(floor(d),full_length,q<0.0?3.0:9.0)); float u=d/full_length;
  bool hole=u>0.5 && water_noise(vec2(d*0.1-clock*25.0,q*0.18),seed+2)<-0.95+1.7*smoothstep(0.5,1.0,u);
  ivec2 xy=ivec2(floor(cell));
  if(bounds && aq<=1.0 && !hole && aq<0.07+0.05*(1.0-u) && (xy.x & 3)==0 && (xy.y & 3)==0 && 0.12*opacity>0.004)
   added=min(vec3(255.0),added+floor(floor(palette(5)*255.0)*0.12*opacity));
 }
 vec4 under=texture(snapshot,SCREEN_UV);
 if(all(equal(added,vec3(0.0)))) COLOR=vec4(under.rgb,1.0);
 else {
  vec3 base=linear_target?to_srgb(under.rgb):under.rgb;
  vec3 result=min(vec3(1.0),base*under.a+added/255.0);
  COLOR=vec4(linear_target?to_linear(result):result,1.0);
 }
}
