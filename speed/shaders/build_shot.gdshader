shader_type canvas_item;
render_mode unshaded;
uniform int style=0;
uniform float pixel_scale=1.0;
uniform float length_scale=1.0;
uniform float width_scale=1.0;
uniform vec4 tint : source_color=vec4(1.0);
varying vec4 parameters;
void vertex(){ parameters=COLOR; COLOR=vec4(1.0); }
void fragment(){
 float a=parameters.r*6.2831853;
 vec2 c=(floor((UV-0.5)*36.0/pixel_scale)+0.5)*pixel_scale;
 vec2 p=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*c;
 float k=floor(-p.x+0.5)/max(length_scale,0.1); float o=floor(abs(p.y)/max(width_scale,0.1)+0.5);
 vec4 col=vec4(0.0);
 if(style==4){
  if(abs(p.x)<=3.0&&abs(p.y)<=2.0||abs(p.x)<=2.0&&abs(p.y)<=3.0) col=vec4(0.13,0.11,0.16,1.0);
  if(abs(p.x)<=1.0&&abs(p.y)<=1.0) col=vec4(1.0,0.82,0.3,1.0);
 }else if(style==3){
  float d=abs(p.x)+abs(p.y)*1.3;
  if(d<4.0) col=vec4(0.68,0.4,1.0,1.0);
  if(abs(p.x)<0.6&&abs(p.y)<4.5||abs(p.y)<0.6&&abs(p.x)<4.5) col=vec4(0.9,0.8,1.0,1.0);
  if(d<1.8) col=vec4(1.0);
 }else if(style==2){
  if(k>=1.0&&k<=4.0&&o<0.5) col=vec4(0.56,1.0,0.89,1.0);
  else if(k>=1.0&&k<=3.0&&o<1.5) col=vec4(0.56,1.0,0.89,0.4);
  if(abs(k)<0.5&&o<0.5) col=vec4(1.0);
 } else {
  float len=style==1?(parameters.g>0.5?3.0:6.0):17.0;
  float wide=style==1?(parameters.g>0.5?0.0:1.0):2.0;
  if(k>=1.0&&k<len&&o==(wide>=2.0?3.0:2.0)&&!(k>len*0.6&&mod(k,2.0)>0.5)&&wide>0.0) col=vec4(0.165,0.498,0.816,0.45);
  if(k>=0.0&&k<len&&o<0.5&&!(k>=len*0.75&&mod(k,2.0)>0.5)) col=k<len*0.4?vec4(1.0):(k<len*0.75?vec4(0.498,0.847,1.0,1.0):vec4(0.227,0.612,0.941,1.0));
  if(wide>0.0&&k>=0.0&&k<len*0.75&&o<1.5&&o>0.5) col=k<len*0.35?(wide>=2.0?vec4(1.0):vec4(0.847,0.965,1.0,1.0)):vec4(0.498,0.847,1.0,1.0);
  if(wide>=2.0&&k>=1.0&&k<len*0.6&&o>1.5&&o<2.5) col=k<len*0.3?vec4(0.847,0.965,1.0,1.0):vec4(0.498,0.847,1.0,1.0);
  if((k==-1.0&&o<0.5)||(wide>=2.0&&k==-2.0&&o<0.5)) col=vec4(1.0);
  if(wide>=2.0&&k==-1.0&&o>0.5&&o<1.5) col=vec4(0.847,0.965,1.0,1.0);
 }
 COLOR=col*tint;
}
