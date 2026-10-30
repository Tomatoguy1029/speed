shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink : source_color=vec4(0.91,0.957,1.0,1.0);
void fragment(){ vec4 source=texture(TEXTURE,UV); COLOR=vec4(ink.rgb,source.a*COLOR.a); }
