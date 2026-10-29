shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 extent = vec2(100.0);
uniform float pixel = 2.36;
uniform float age = 0.0;
uniform float duration = 0.7;
uniform float width = 0.0;
uniform vec4 c1 : source_color = vec4(0.745098, 0.843137, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0);

#include "build_pixel_ring.gdshaderinc"

void fragment() {
 vec2 cell = floor((UV-0.5)*extent/pixel);
 float q = age/max(duration,0.001);
 float radius = (min(extent.x,extent.y)*0.5/pixel-2.0)*q;
 if(q < 0.0 || q >= 1.0 || radius < 1.0) discard;
 float dots = pixel_ring(cell,radius);
 if(radius > 3.0) dots += pixel_ring(cell,radius-1.0)*0.7;
 if(dots == 0.0) discard;
 // 加算合成では色を暗くせず、不透明度だけで輪の明るさを決める。
 COLOR = vec4(c1.rgb, c1.a*dots*0.24*(1.0-q)*(1.0+width*2.0))*tint;
}
