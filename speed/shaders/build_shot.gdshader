shader_type canvas_item;
render_mode unshaded;
uniform int style=0;
uniform float pixel_scale=1.0;
uniform float length_scale=1.0;
uniform float width_scale=1.0;
uniform vec4 tint : source_color=vec4(1.0);
varying vec4 parameters;
void vertex(){ parameters=COLOR; COLOR=vec4(1.0); }
// 試作と同じく、元の各ドットを回して丸める。逆回転した画素の判定では斜めの輪郭が変わる。
vec4 bolt_dot(float k,float o,float len,float wide){
 float ay=abs(o);
 if(k==-2.0&&o==0.0&&wide>=2.0)return vec4(1.0);
 if(k==-1.0){
  if(o==0.0)return vec4(1.0);
  if(ay==1.0&&wide>=2.0)return vec4(0.847,0.965,1.0,1.0);
 }
 if(k<0.0||k>=len)return vec4(0.0);
 if(ay==0.0&&!(k>=len*0.75&&mod(k,2.0)>0.5))return k<len*0.4?vec4(1.0):(k<len*0.75?vec4(0.498,0.847,1.0,1.0):vec4(0.227,0.612,0.941,1.0));
 if(ay==1.0&&wide>0.0&&k<len*0.75)return k<len*0.35?(wide>=2.0?vec4(1.0):vec4(0.847,0.965,1.0,1.0)):vec4(0.498,0.847,1.0,1.0);
 if(ay==2.0&&wide>=2.0&&k>=1.0&&k<len*0.6)return k<len*0.3?vec4(0.847,0.965,1.0,1.0):vec4(0.498,0.847,1.0,1.0);
 if(wide>0.0&&ay==(wide>=2.0?3.0:2.0)&&k>=1.0&&!(k>len*0.6&&mod(k,2.0)>0.5))return vec4(0.165,0.498,0.816,0.45);
 return vec4(0.0);
}
void fragment(){
 float a=parameters.r*6.2831853;
 vec2 c=floor((UV-0.5)*36.0/pixel_scale+0.5)*pixel_scale;
 vec2 p=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*c;
 float k=floor(-p.x+0.5)/max(length_scale,0.1); float o=floor(abs(p.y)/max(width_scale,0.1)+0.5);
 vec4 col=vec4(0.0);
 if(style==4){
  if((abs(p.x)<=2.0&&abs(p.y)<=1.0)||(abs(p.x)<=1.0&&abs(p.y)<=2.0)) col=vec4(vec3(43,53,80)/255.0,1.0);
  if((abs(p.x)<0.5&&abs(p.y)>=3.0&&abs(p.y)<=4.0)||(abs(p.y)<0.5&&abs(p.x)>=3.0&&abs(p.x)<=4.0)) col=vec4(vec3(91,106,144)/255.0,1.0);
  if(abs(p.x)<0.5&&abs(p.y)<0.5) col=vec4((parameters.g>=0.14&&mod(floor(parameters.b*6.0),2.0)==0.0?vec3(143,224,255):vec3(53,98,138))/255.0,1.0);
  if(parameters.g>=0.14&&parameters.g<0.22&&abs(length(p)-6.0)<0.6) col=vec4(vec3(207,234,255)/255.0,1.0);
 }else if(style==3){
  float d=abs(p.x)+abs(p.y)*1.3;
  if(d<4.0) col=vec4(0.68,0.4,1.0,1.0);
  if(abs(p.x)<0.6&&abs(p.y)<4.5||abs(p.y)<0.6&&abs(p.x)<4.5) col=vec4(0.9,0.8,1.0,1.0);
  if(d<1.8) col=vec4(1.0);
 } else {
  float len=style==1?(parameters.g>0.5?3.0:6.0):17.0;
  float wide=style==1?(parameters.g>0.5?0.0:1.0):2.0;
  vec2 base=floor(vec2(-p.x/max(length_scale,0.1),p.y/max(width_scale,0.1))+0.5);
  vec2 dir=vec2(cos(a),sin(a));vec2 side=vec2(-sin(a),cos(a));float best=-1e10;
  for(int dk=-1;dk<=1;dk++)for(int dy=-1;dy<=1;dy++){
   float sk=base.x+float(dk);float sy=base.y+float(dy);
   vec2 target=floor((-dir*sk*length_scale+side*sy*width_scale)/pixel_scale+0.5)*pixel_scale;
   if(distance(target,c)>0.1)continue;
   vec4 dot_color=bolt_dot(sk,sy,len,wide);
   if(style==2){
    dot_color=vec4(0.0);
    if(sk>=1.0&&sk<=4.0&&sy==0.0)dot_color=vec4(vec3(143,255,226)/255.0,1.0);
    if(sk>=1.0&&sk<=3.0&&abs(sy)==1.0)dot_color=vec4(vec3(143,255,226)/255.0,0.4);
    if(sk==0.0&&sy==0.0)dot_color=vec4(1.0);
   }
   if(dot_color.a==0.0)continue;
   float rank=sk<0.0?1000.0-sk:(dot_color.a<1.0?-100.0:sk*6.0+abs(sy)*2.0+(sy<0.0?1.0:0.0));
   if(rank>best){col=dot_color;best=rank;}
  }
 }
 COLOR=col*tint;
}
