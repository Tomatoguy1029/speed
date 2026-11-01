shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.4,0.75,1.0,1.0);
uniform float clock=0.0;
uniform float thickness=300.0;
uniform bool warning=false;
uniform float cell_size=4.0;
group_uniforms tuning;
uniform float branch_count : hint_range(2,16,1) = 5.0;
uniform float branch_sharpness : hint_range(4,64,1) = 28.0;
uniform float halo_sharpness : hint_range(1,32,1) = 8.0;
uniform float noise_density : hint_range(2,40,1) = 14.0;
uniform float grain_speed : hint_range(1,48,1) = 24.0;
uniform float center_ratio : hint_range(0,0.5,0.01) = 0.14;
uniform float circuit_speed : hint_range(0,16,0.5) = 4.0;
uniform float circuit_width : hint_range(0.005,0.2,0.005) = 0.04;
uniform float visual_opacity : hint_range(0,1,0.05) = 1.0;
uniform float visual_brightness : hint_range(0,3,0.05) = 1.0;
group_uniforms;
float hash(float p){return fract(sin(p*127.1)*43758.5453);}
void fragment(){
 float cells=max(thickness/cell_size,8.0);
 vec2 p=((floor(UV*cells)+0.5)/cells-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float inside=1.0-step(1.0,r);
 float ring=step(0.90,r)*inside;
 float stagger=hash(floor(r*noise_density)+floor(clock*grain_speed))*0.8;
 float branches=pow(abs(cos(a*branch_count+stagger )),branch_sharpness)*inside;
 float halo=pow(abs(cos(a*branch_count+stagger )),halo_sharpness)*inside;
 float center=1.0-step(center_ratio,r);
 float circuit=(1.0-step(circuit_width,abs(fract(r*3.0-clock*circuit_speed)-0.5)))*0.3;
 float alpha=inside*(0.06+halo*0.2+branches*0.75+center*0.8+circuit*0.2)+ring*0.3;
 vec3 color=tint.rgb*(0.6+halo)+vec3(branches*1.2+center);
 if(warning){
  float ticks=step(0.4,fract(a*6.0+clock));
  alpha=inside*0.06+ring*(0.35+ticks*0.4);
  color=mix(tint.rgb,vec3(1.0,0.85,0.45),0.6);
 }
 COLOR=vec4(color*visual_brightness,clamp(alpha,0.0,1.0)*tint.a*visual_opacity);
}
