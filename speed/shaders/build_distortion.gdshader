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
 if(r>=min(extent.x,extent.y)*0.5-pixel) discard;
 vec2 offset=vec2(0.0); float light=1.0; float black=0.0; vec3 extra=vec3(0.0);
 if(age<0.0 || age>=duration) discard;
 if(mode==0){
  float time=age/duration*0.58;
  float q=clamp((time-0.08)/0.5,0.0,1.0);
  float radius=min(extent.x,extent.y)*0.5-10.0*pixel;
  float edge=time<0.08?mix(12.0,3.0,time/0.08)*pixel:4.0*pixel+(radius-4.0*pixel)*(1.0-pow(1.0-q,2.2));
  float gap=r-edge;
  if(abs(gap)>8.0*pixel || r<pixel) discard;
  float band=1.0-abs(gap)/(8.0*pixel);
  float amp=time<0.08?3.0:10.0*(1.0-q*0.75);
  offset=-u*band*amp*pixel;
  light=gap>0.0?1.0+0.9*band:1.0-0.35*band;
  if(gap>0.0) extra=vec3(1.0,1.0,1.15)*(38.0/255.0)*band*band;
 }else{
  float base_hole=max(0.0,min(extent.x,extent.y)*0.5-2.0*pixel)/7.0;
  float hole=base_hole*(age<0.15?mix(0.35,1.0,age/0.15):(age>duration-0.15?max(0.0,(duration-age)/0.15):1.0));
  float reach=min(hole*7.0,120.0*pixel);
  if(r>=reach || reach<=0.0) discard;
  float fade=smoothstep(reach*0.6,reach,r);
  offset=-u*hole*hole/max(r,pixel)*(1.0-fade);
  black=step(r,hole);
 }
 vec2 uv=SCREEN_UV+offset*strength*screen_scale*SCREEN_PIXEL_SIZE;
 vec4 color=texture(screen_tex,uv); color.rgb=color.rgb*mix(1.0,light,strength)+extra*strength;
 if(black>0.5) color=vec4(0.0,0.0,0.0,1.0);
 COLOR=color;
}
