shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec4 base=texture(TEXTURE,UV);
 float wave=sin(UV.y*19.0+UV.x*8.0+TIME*2.0)*0.5+0.5;
 vec3 cosmic=mix(vec3(0.14,0.08,0.45),vec3(0.25,0.8,1.0),wave);
 float stars=pow(max(0.0,sin(UV.x*117.0+sin(UV.y*83.0))*sin(UV.y*131.0)),24.0);
 COLOR=vec4(mix(base.rgb,cosmic,0.65)+stars*1.5,base.a)*COLOR;
}
