shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.4,0.75,1.0,1.0);
uniform float clock=0.0;
uniform float thickness=300.0;
uniform bool warning=false;
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
void fragment(){
 float cells=max(thickness/4.0,8.0);
 vec2 p=((floor(UV*cells)+0.5)/cells-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float inside=1.0-step(1.0,r);
 float ring=step(0.90,r)*inside;
 float stagger=hash(floor(r*14.0)+floor(clock*24.0))*0.8;
 float branches=pow(abs(cos(a*5.0+stagger)),28.0)*inside;
 float halo=pow(abs(cos(a*5.0+stagger)),8.0)*inside;
 float center=1.0-step(0.14,r);
 float circuit=(1.0-step(0.04,abs(fract(r*3.0-clock*4.0)-0.5)))*0.3;
 float alpha=inside*(0.06+halo*0.2+branches*0.75+center*0.8+circuit*0.2)+ring*0.3;
 vec3 color=tint.rgb*(0.6+halo)+vec3(branches*1.2+center);
 if(warning){
  float ticks=step(0.4,fract(a*6.0+clock));
  alpha=inside*0.06+ring*(0.35+ticks*0.4);
  color=mix(tint.rgb,vec3(1.0,0.85,0.45),0.6);
 }
 COLOR=vec4(color,clamp(alpha,0.0,1.0));
}
