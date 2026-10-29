shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clock=0.0;
uniform float strength=0.0;
uniform float pop=0.0;
uniform float pixel_scale=1.0;
uniform vec4 tint : source_color=vec4(1.0);
vec3 palette(float stage, int band){
 vec3 a[3]=vec3[](vec3(242,246,255),vec3(185,198,230),vec3(111,127,174));
 vec3 b[3]=vec3[](vec3(230,248,255),vec3(127,208,255),vec3(47,111,192));
 vec3 c[3]=vec3[](vec3(255,246,208),vec3(255,210,74),vec3(176,122,20));
 return (stage<1.0?mix(a[band],b[band],stage):mix(b[band],c[band],min(1.0,stage-1.0)))/255.0;
}
void fragment(){
 vec2 p=(floor(UV*vec2(83,122)*0.55/pixel_scale)+0.5)*pixel_scale;
 vec2 uv=p/(vec2(83,122)*0.55);
 float raw=texture(TEXTURE,uv).r*255.0;
 float distance=raw/8.0*0.55;
 float base=0.5+3.3*strength*strength+0.7*pop;
 float n=clamp(texture(noise_tex,(p*1.2+vec2(0,clock*28.0))/64.0).r+texture(noise_tex,(p*0.96+vec2(23,clock*16.0+41.0))/64.0).r-0.5,0.0,1.0);
 float up=max(0.0,30.0*0.55+26.0*0.55-p.y)/50.0;
 float e=base*(0.75+0.55*n)+up*base*0.6*n;
 float inner=e-distance;
 vec4 col=vec4(0.0);
 if(raw>0.0&&distance<14.0&&distance<=e&&base>=1.0){
  if(inner<1.0) col=vec4(pop>0.5?vec3(1.0):palette(strength*2.0,0),1.0);
  else if(inner<2.0) col=vec4(palette(strength*2.0,1),1.0);
  else if(mod(p.x+p.y,2.0)<1.0) col=vec4(palette(strength*2.0,2),1.0);
 }
 COLOR=col*tint;
}
