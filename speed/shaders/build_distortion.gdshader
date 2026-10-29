shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode=0;
uniform vec2 screen_scale=vec2(1.0);
uniform vec2 extent=vec2(200.0);
uniform float pixel=2.36;
uniform float age=0.0;
uniform float duration=0.58;
uniform float strength=1.0;
void fragment(){
 vec2 p=(floor((UV-0.5)*extent/pixel)+0.5)*pixel;
 float r=length(p); vec2 u=p/max(r,0.001);
 vec2 offset=vec2(0.0); float light=1.0; float black=0.0;
 if(mode==0){
  float q=clamp((age-0.08)/0.5,0.0,1.0); float radius=min(extent.x,extent.y)*0.5;
  if(age<0.08){ float core=mix(12.0,3.0,age/0.08)*pixel; offset=u*max(0.0,1.0-r/core)*3.0*pixel; }
  else{ float edge=radius*(1.0-pow(1.0-q,3.0)); float band=clamp(1.0-abs(r-edge)/(8.0*pixel),0.0,1.0);
   offset=u*band*10.0*pixel*(1.0-q); light=r>=edge?1.0+0.9*band*(1.0-q):1.0-0.35*band*(1.0-q); }
 }else{
  float hole=14.0*pixel*(age<0.15?mix(0.35,1.0,age/0.15):(age>duration-0.15?max(0.0,(duration-age)/0.15):1.0));
  float e=hole*1.8; float mapped=r-e*e/max(r,pixel); offset=u*(mapped-r); black=step(r,hole);
  light=1.0+0.5*max(0.0,1.0-abs(r-hole)/pixel);
 }
 vec2 uv=SCREEN_UV+offset*strength*screen_scale*SCREEN_PIXEL_SIZE;
 vec4 color=texture(screen_tex,uv); color.rgb*=mix(1.0,light,strength);
 if(black>0.5) color=vec4(0.0,0.0,0.0,1.0);
 COLOR=color;
}
