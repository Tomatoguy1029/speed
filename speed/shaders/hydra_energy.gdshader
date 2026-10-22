shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0,0.3,0.2,1.0);
uniform float clock = 0.0;
uniform float span = 300.0;
uniform float thickness = 32.0;
uniform bool warning = false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 grid=vec2(max(span/4.0,2.0),max(thickness/4.0,2.0));
 vec2 uv=(floor(UV*grid)+0.5)/grid;
 float edge=abs(uv.y-0.5)*2.0;
 float grain=hash(floor(uv*grid)+floor(clock*14.0));
 float flow=sin(uv.x*45.0-clock*10.0+uv.y*4.0)*0.5+0.5;
 float rim=step(edge,0.92-grain*0.12);
 float core=step(edge,0.22+flow*0.14);
 float sparks=step(0.86,grain)*step(edge,0.8);
 vec3 col=tint.rgb*(0.65+flow*0.5)+core*vec3(1.4)+sparks*tint.rgb*1.3;
 float alpha=rim*(0.7+core*0.3);
 if(warning){
  float marks=step(0.45,fract(uv.x*span/28.0-clock*1.5));
  col=mix(tint.rgb,vec3(1.0,0.85,0.45),0.7);
  alpha=rim*(0.2+0.35*marks)*step(0.65,edge)+0.12*rim;
 }
 COLOR=vec4(col,alpha);
}
