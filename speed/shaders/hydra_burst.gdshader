shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 tint : source_color = vec4(1.0,0.6,0.3,1.0);
uniform float progress = 0.0;
uniform float pixels = 48.0;
uniform float seed = 0.0;
group_uniforms tuning;
uniform float spokes : hint_range(4,48,1) = 18.0;
uniform float ring_start : hint_range(0,0.8,0.01) = 0.12;
uniform float ring_growth : hint_range(0,0.9,0.01) = 0.63;
uniform float ring_noise : hint_range(0,0.4,0.01) = 0.12;
uniform float ring_thickness : hint_range(0.005,0.2,0.005) = 0.025;
uniform float ring_thickness_start : hint_range(0,0.2,0.005) = 0.04;
uniform float inner_size : hint_range(0,0.6,0.01) = 0.15;
uniform float ray_threshold : hint_range(0,1,0.01) = 0.65;
uniform float ray_reach : hint_range(0,0.5,0.01) = 0.16;
uniform float ray_thickness : hint_range(0.005,0.15,0.005) = 0.025;
uniform float chip_threshold : hint_range(0,1,0.01) = 0.91;
uniform float chip_density : hint_range(4,48,1) = 18.0;
uniform float ring_opacity : hint_range(0,1,0.05) = 0.7;
uniform float ray_opacity : hint_range(0,1,0.05) = 0.8;
uniform float brightness : hint_range(0,4,0.1) = 1.2;
group_uniforms;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
 vec2 p=((floor(UV*pixels)+0.5)/pixels-0.5)*2.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float spoke=floor((a+3.14159)*spokes);
 float noise=hash(vec2(spoke,seed));
 float ring_radius=ring_start+progress*(ring_growth+noise*ring_noise);
 float ring=1.0-step(ring_thickness+ring_thickness_start*(1.0-progress),abs(r-ring_radius));
 float inner=1.0-step(inner_size*(1.0-progress),r);
 float rays=step(ray_threshold,noise)*step(r,ring_radius+ray_reach)*(1.0-step(ray_thickness,abs(sin(a*spokes+seed))));
 float chips=step(chip_threshold,hash(floor(p*chip_density)+seed))*step(ring_radius-0.12,r)*step(r,ring_radius+0.13);
 float alpha=(ring*ring_opacity+inner+rays*ray_opacity+chips)*(1.0-progress);
 vec3 color=tint.rgb*(brightness+chips)+vec3(inner*1.4+ring*0.25);
 COLOR=vec4(color,clamp(alpha,0.0,1.0)*tint.a);
}
