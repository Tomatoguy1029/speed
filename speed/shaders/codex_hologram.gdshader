shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source_tex : filter_nearest, repeat_disable;
uniform sampler2D warp : filter_nearest, repeat_disable;
uniform bool rare=false;
uniform bool locked=false;
uniform float clock=0.0;
uniform float reveal=1.0;
uniform float scan_y=-99.0;
uniform vec4 glitch0=vec4(-99.0);
uniform vec4 glitch1=vec4(-99.0);
uniform vec4 glitch2=vec4(-99.0);
const vec2 SIZE=vec2(300.0,170.0);
float threshold(vec2 p){ivec2 c=ivec2(mod(p,4.0));int b[16]=int[](0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5);return float(b[c.x+c.y*4]);}
vec2 row(float y){float rd=scan_y-y;float gain=1.0;float shift=0.0;
 if(rd>-2.0&&rd<7.0){gain+=rd<1.0?0.45:0.45*(1.0-rd/7.0);if(rd<2.0)shift=round(sin(y*0.9+clock*7.0)*1.5);}
 vec4 gs[3]=vec4[](glitch0,glitch1,glitch2);for(int j=0;j<3;j++){if(y>=gs[j].x&&y<gs[j].x+gs[j].y){shift=gs[j].z;gain=max(gain,1.25);}}
 return vec2(shift,gain);
}
vec4 representative(vec2 g){vec3 best=vec3(0.0);float brightness=-1.0;
 if(g.x<0.0||g.y<0.0||g.x>=150.0||g.y>=85.0)return vec4(0.0);
 if(g.y*2.0>=160.0)return vec4(0.0);
 for(int y=0;y<2;y++)for(int x=0;x<2;x++){
  vec2 p=g*2.0+vec2(float(x),float(y));vec4 map=round(texture(warp,(p+0.5)/SIZE)*255.0);
  vec2 source=vec2(map.r+mod(map.b,2.0)*256.0,map.g+floor(map.b/2.0)*256.0)-64.0;source.x+=row(p.y).x;
  if(source.x<0.0||source.y<0.0||source.x>=300.0||source.y>=170.0)continue;
  vec3 c=texture(source_tex,(source+0.5)/SIZE).rgb;float m=max(c.r,max(c.g,c.b));if(m>brightness){brightness=m;best=c;}
 }
 if(brightness<0.07)return vec4(0.0);
 vec3 tone=rare?vec3(1.1,1.0,0.8):vec3(0.88,1.0,1.12);
 vec3 lift=(rare?vec3(20.0,12.0,0.0):vec3(0.0,12.0,18.0))/255.0;
 vec3 color=round(min(vec3(1.0),(best*tone+lift*brightness)*(1.15+0.25*brightness))*5.0)/5.0;
 return vec4(color,brightness);
}
void fragment(){
 vec2 p=floor(UV*SIZE);vec2 g=floor(p/2.0);vec3 rim=rare?vec3(255,226,140)/255.0:vec3(150,240,255)/255.0;
 vec3 outc=vec3(5,10,23)/255.0;float front=reveal<1.0?178.0*reveal-4.0:269.0;
 float edge=min(min(p.x,p.y),min(299.0-p.x,160.0-p.y));
 if(!locked&&p.y<=front&&p.y<160.0&&!(edge<6.0&&threshold(p)>=edge/6.0*16.0)){
  vec4 center=representative(g);
  if(center.a>=0.07){float dark=mod(p.y+floor(clock*7.0),3.0)<1.0?0.72:1.0;outc=center.rgb*dark*row(p.y).y;}
  else if(threshold(p)<4.0){bool neighbor=false;for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){if(representative(g+vec2(float(x),float(y))).a>=0.3)neighbor=true;}if(neighbor)outc+=rim*0.12;}
 }
 if(reveal<1.0&&abs(p.y-front)<1.5)outc+=rim*0.8;
 if(p.x>=112.0&&p.x<=188.0){float f=1.0-abs(p.x-150.0)/38.0;if(p.y==164.0)outc+=rim*(0.85*f+0.15);if(p.y==163.0)outc+=rim*0.4*f;if(p.y==165.0)outc+=rim*0.3*f;}
 if(locked&&reveal>=1.0){vec2 q=floor((p-vec2(138,48))/4.0);bool question=(q.y==0.0&&q.x>=0.0&&q.x<=2.0)||(q.x==3.0&&(q.y==1.0||q.y==2.0))||(q.x==2.0&&q.y==3.0)||(q.x==1.0&&(q.y==4.0||q.y==6.0));if(question&&mod(p.x+p.y,2.0)<1.0)outc+=rim*0.55;}
 COLOR=vec4(outc,1.0);
}
