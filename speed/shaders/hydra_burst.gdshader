shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 tint : source_color = vec4(1.0,0.6,0.3,1.0);
uniform float progress = 0.0;
uniform float pixels = 48.0;
uniform float seed = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=((floor(UV*pixels)+0.5)/pixels-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float spoke=floor((a+3.14159)*18.0);
 float noise=hash(vec2(spoke,seed));
 float ring_radius=0.12+progress*(0.63+noise*0.12);
 float ring=1.0-step(0.025+0.04*(1.0-progress),abs(r-ring_radius));
 float inner=1.0-step(0.15*(1.0-progress),r);
 float rays=step(0.65,noise)*step(r,ring_radius+0.16)*(1.0-step(0.025,abs(sin(a*18.0+seed))));
 float chips=step(0.91,hash(floor(p*18.0)+seed))*step(ring_radius-0.12,r)*step(r,ring_radius+0.13);
 float alpha=(ring*0.7+inner+rays*0.8+chips)*(1.0-progress);
 vec3 color=tint.rgb*(1.2+chips)+vec3(inner*1.4+ring*0.25);
 COLOR=vec4(color,clamp(alpha,0.0,1.0)*tint.a);
}
