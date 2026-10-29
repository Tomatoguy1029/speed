shader_type canvas_item;
render_mode unshaded;
uniform int mode = 0;
uniform int streak_count = 16;
uniform vec2 extent = vec2(100.0);
uniform float pixel = 2.36;
uniform float age = 0.0;
uniform float duration = 0.4;
uniform float angle = 0.0;
uniform float width = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 c0 : source_color = vec4(1.0);
uniform vec4 c1 : source_color = vec4(0.85,0.96,1.0,1.0);
uniform vec4 c2 : source_color = vec4(0.5,0.85,1.0,1.0);
uniform vec4 c3 : source_color = vec4(0.23,0.61,0.94,1.0);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform bool broken = false;
uniform sampler2D value_noise : repeat_disable, filter_nearest;
uniform vec2 noise_origin=vec2(0.0);
uniform float noise_seed=0.0;
float lattice(vec3 p){vec3 i=mod(p,64.0);vec2 tile=vec2(mod(i.z,8.0),floor(i.z/8.0));return texture(value_noise,(tile*64.0+i.xy+0.5)/512.0).r;}
float vnoise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);vec3 u=f*f*(3.0-2.0*f);
 float a=mix(mix(lattice(i),lattice(i+vec3(1,0,0)),u.x),mix(lattice(i+vec3(0,1,0)),lattice(i+vec3(1,1,0)),u.x),u.y);
 float b=mix(mix(lattice(i+vec3(0,0,1)),lattice(i+vec3(1,0,1)),u.x),mix(lattice(i+vec3(0,1,1)),lattice(i+vec3(1,1,1)),u.x),u.y);
 return mix(a,b,u.z);
}
mat2 rotate(float a) { return mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a))); }
float ring(vec2 p, float r) { return step(abs(length(p)-r),0.62); }
float bayer(vec2 p) { ivec2 c=ivec2(mod(p,4.0)); int b[16]=int[](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5); return (float(b[c.x+c.y*4])+0.5)/16.0; }
void fragment() {
 vec2 cell=floor((UV-0.5)*extent/pixel); vec2 p=cell+0.5;
 vec2 v=rotate(-angle)*p;
 float q=clamp(age/max(duration,0.001),0.0,1.0);
 float radius=min(extent.x,extent.y)*0.5/pixel-2.0;
 vec4 outc=vec4(0.0);
 if(mode==0) { // 途切れないドットの衝撃波
  float r=radius*(1.0-pow(1.0-q,3.0));
  float edge=ring(p,r); float band=step(abs(length(p)-r),2.0)*(1.0-q);
  outc=mix(c2,c0,edge)*max(edge,band*0.45); outc.a*=1.0-q;
 } else if(mode==1) { // 試作のpfire：焼いたノイズと段階色、市松
  float rt=radius*(0.35+0.65*(1.0-pow(1.0-min(1.0,q*3.0),3.0)));
  float n=vnoise(vec3((p+noise_origin)*0.16+vec2(noise_seed,-q*3.0),q*5.0+noise_seed));
  float den=(1.0-length(p)/max(rt,0.1))*1.35+(n-0.5)*0.95-q*1.15+(q<0.07?0.7:0.0);
  if(den>0.8) outc=c0; else if(den>0.55) outc=c1; else if(den>0.33) outc=c2;
  else if(den>0.16&&mod(cell.x+cell.y,2.0)<1.0) outc=c3;
 } else if(mode==2) { // ブラスター砲口：白い菱形、長い光線、横火花
  float rr=width>1.5?4.0:3.0; float rl=width>1.5?13.0:8.0;
  if(q<0.4) {
   if(abs(p.x)+abs(p.y)<=rr) outc=c0;
   if(v.x>=2.0&&v.x<=rl&&abs(v.y)<(v.x<rl*0.5&&width>1.5?1.5:0.5)) outc=v.x<rl*0.6?c0:c2;
   if(v.x>=1.0&&v.x<=rr&&abs(abs(v.y)-v.x-1.0)<0.7) outc=c2;
  } else if(q<0.75) {
   if(max(abs(p.x),abs(p.y))<=1.5) outc=c2;
   if(length(p)<0.8) outc=c0;
   if(v.x>=2.0&&v.x<=rl*0.6&&abs(v.y)<0.6) outc=c2;
  } else if(length(p)<0.8||(abs(v.x-3.0)<0.6&&abs(v.y)<0.6)) outc=c3;
 } else if(mode==3) { // 十字と二重の命中輪
  float arm=width>1.5?7.0:3.0;
  if(q<0.45&&((abs(p.x)<0.6&&abs(p.y)<=arm)||(abs(p.y)<0.6&&abs(p.x)<=arm)||max(abs(p.x),abs(p.y))<1.5)) outc=c0;
  if(ring(p,2.0+(width>1.5?12.0:5.0)*q)>0.5) outc=q<0.4?c1:c2;
  if(width>1.5&&q>0.2&&ring(p,1.0+6.0*q)>0.5) outc=c1;
 } else if(mode==4) { // 両端の尖った斬撃。4分の1保ってから細く消える
  float envelope=q<0.25?1.0:1.0-(q-0.25)/0.75;
  float shape=max(0.0,1.0-abs(v.x)/max(radius,1.0))*width*(1.0-q*0.5)*envelope;
  if(abs(v.y)<shape+1.0) outc=c3;
  if(abs(v.y)<shape) outc=c2;
  if(abs(v.y)<shape*0.3) outc=c0;
 } else if(mode==5) { // 六角形の殻と外へ広がる段
  float step_r=sqrt(3.0)*4.0;
  float row=floor((p.y+3.0)/6.0); float cx=floor((p.x+step_r*0.5-mod(row,2.0)*step_r*0.5)/step_r)*step_r+mod(row,2.0)*step_r*0.5;
  vec2 center=vec2(cx,row*6.0); vec2 h=abs(p-center);
  float hex=max(h.x*0.8660254+h.y*0.5,h.y); float line=step(abs(hex-3.1),0.55);
  float d=length(center); float a=abs(atan(center.y,center.x)-angle); a=min(a,6.2831853-a);
  if(width<0.0) {
   float at=age-a/3.14159265*0.3;
   if(d>=13.0&&d<=24.0&&at>=0.0&&age<0.5) outc=(at<0.06?c0:c2)*line*(age<0.3?1.0:1.0-(age-0.3)/0.2);
  } else {
   if(d>=13.0&&d<=24.0&&age<0.21&&age-a/3.14159265*0.16>=0.0) outc=(age-a/3.14159265*0.16<0.04?c0:c1)*line;
   float k=4.0+floor((age-0.21)/0.05); float ck=floor(d/step_r+0.5);
   if(age>=0.21&&d<=radius) {
    if(ck==k) outc=c1*line;
    else if(ck==k-1.0&&k-1.0>=4.0) outc=c2*line*0.45;
   }
  }
 } else if(mode==6) { // 両端を丸めた双極ビーム
  float halfw=width*(age<0.3?1.0:max(0.0,1.0-(age-0.3)/0.4))*0.5;
  float along=max(abs(v.x)-max(0.0,radius-halfw),0.0);
  float d=length(vec2(along,v.y));
  float edge=texture(noise_tex,vec2(v.x*0.03,age*0.8)).r;
  halfw+=floor(edge*2.0);
  if(d<halfw*0.35) outc=c0;
  else if(d<halfw*0.7) outc=c2;
  else if(d<halfw&&mod(cell.x+cell.y,2.0)<1.0) outc=c3;
  if(abs(v.y-sin(v.x*0.13-age*12.0)*halfw*0.45)<0.7&&d<halfw) outc=c1;
 } else if(mode==14) {
  float ke=width;
  for(int i=0;i<64;i++){
   if(i>=streak_count) break;
   float h1=mod(float(i*73),100.0)/100.0;float h2=mod(float(i*37),100.0)/100.0;
   float ph=fract(h1+age*(1.8+2.6*ke)*(0.7+0.6*h2));
   float spread=(h2-0.5)*(5.0+14.0*ke)*(0.4+0.6*abs(h1-0.5)*2.0);
   float yy=spread+sin(age*14.0+float(i)*2.3)*1.2*ke;
   float len=(8.0+50.0*ke)*(0.35+h1*0.9)*(1.0-0.6*abs(spread)/(3.0+12.0*ke));
   float xx=-5.0-ph*(14.0+40.0*ke);float w=0.7+1.6*ke*(1.0-abs(spread)/(3.0+12.0*ke))*(0.5+h2*0.5);
   if(v.x<=xx&&v.x>=xx-len&&abs(v.y-yy)<=w*0.5){vec3 col=h2<0.35?vec3(255,245,200)/255.0:vec3(255.0,185.0+round(h1*40.0),70.0+round(h2*60.0))/255.0;outc=vec4(col,(0.25+0.6*ke)*(1.0-ph)*(1.0-0.5*abs(spread)/(3.0+12.0*ke)));}
  }
 } else if(mode==8) {
  if(abs(v.y)<=width*0.5&&abs(v.x)<=radius) outc=c1;
 } else if(mode==9) {
  if(length(p)<=radius) outc=c1;
 } else if(mode==10) {
  if(abs(length(p)-radius)<=width*0.5) outc=c1;
 } else if(mode==7) { // その場に残る音の輪
  float r=radius*q;
  outc=c1*(ring(p,r)*0.24+ring(p,r-1.0)*0.168)*(1.0-q)*(1.0+width*2.0);
 }
 COLOR=outc*tint;
}
