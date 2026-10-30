shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float span = 90.0;
uniform float thickness = 210.0;
uniform float power = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float pixel_size = 3.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 extent=vec2(span+thickness,thickness);
 vec2 pixel=(floor(UV*extent/pixel_size)+0.5)*pixel_size-extent*0.5;
 vec2 p=pixel/(extent*0.5);
 float r=length(p);
 float angle=atan(p.y,p.x);
 float edge=length(vec2(max(abs(pixel.x)-span*0.5,0.0),pixel.y))/(thickness*0.5);
 float mask=1.0-step(0.98,edge);
 float spiral=sin(angle*3.0+r*15.0-clock*15.0);
 float wake=sin(angle*5.0-r*22.0-clock*9.0);
 float band=step(0.55,spiral);
 float thread=step(0.94,spiral)*step(0.23,r);
 float grit=hash(floor(pixel/6.0));
 float clouds=floor((sin(r*24.0-angle*3.0+clock*4.0)*0.5+0.5)*3.0)/3.0;
 vec3 shadow=vec3(0.06,0.12,0.15);
 vec3 wind=vec3(0.23,0.52,0.53);
 vec3 light=vec3(0.70,0.90,0.85);
 vec3 color=mix(shadow,wind,clouds*0.6+band*0.4);
 color=mix(color,light,thread*(0.6+power*0.4));
 color+=vec3(0.24,0.42,0.39)*step(0.88,wake)*step(0.78,grit);
 float rim=step(0.90,edge);
 color=mix(color,vec3(0.10,0.24,0.27),rim);
 float alpha=mask*(0.40+band*0.30+thread*0.30)*(0.45+power*0.55);
 COLOR=vec4(color*tint.rgb,alpha*tint.a);
}
