shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clock=0.0;
uniform float strength=0.0;
uniform float pop=0.0;
uniform float pixel_scale=1.0;
uniform vec4 tint : source_color=vec4(1.0);
// tuning の値は戦闘エフェクトツールで上書きする（ShaderTuning）。強さで銀→青→金に変わり、各段は縁・中・外の3色
group_uniforms tuning;
uniform vec4 silver_rim : source_color=vec4(0.949,0.965,1.0,1.0);
uniform vec4 silver_mid : source_color=vec4(0.725,0.776,0.902,1.0);
uniform vec4 silver_outer : source_color=vec4(0.435,0.498,0.682,1.0);
uniform vec4 blue_rim : source_color=vec4(0.902,0.973,1.0,1.0);
uniform vec4 blue_mid : source_color=vec4(0.498,0.816,1.0,1.0);
uniform vec4 blue_outer : source_color=vec4(0.184,0.435,0.753,1.0);
uniform vec4 gold_rim : source_color=vec4(1.0,0.965,0.816,1.0);
uniform vec4 gold_mid : source_color=vec4(1.0,0.824,0.290,1.0);
uniform vec4 gold_outer : source_color=vec4(0.690,0.478,0.078,1.0);
uniform float flicker_speed : hint_range(0.0, 3.0, 0.05)=1.0;
uniform float rise : hint_range(0.0, 2.0, 0.05)=0.6;
group_uniforms;
vec3 palette(float stage, int band){
 vec3 a[3]=vec3[](silver_rim.rgb,silver_mid.rgb,silver_outer.rgb);
 vec3 b[3]=vec3[](blue_rim.rgb,blue_mid.rgb,blue_outer.rgb);
 vec3 c[3]=vec3[](gold_rim.rgb,gold_mid.rgb,gold_outer.rgb);
 return stage<1.0?mix(a[band],b[band],stage):mix(b[band],c[band],min(1.0,stage-1.0));
}
void fragment(){
 vec2 p=(floor(UV*vec2(83,122)*0.55/pixel_scale)+0.5)*pixel_scale;
 vec2 uv=p/(vec2(83,122)*0.55);
 float raw=texture(TEXTURE,uv).r*255.0;
 float distance=raw/8.0*0.55;
 float base=0.5+3.3*strength*strength+0.7*pop;
 float n=clamp(texture(noise_tex,(p*1.2+vec2(0,clock*flicker_speed*28.0))/64.0).r+texture(noise_tex,(p*0.96+vec2(23,clock*flicker_speed*16.0+41.0))/64.0).r-0.5,0.0,1.0);
 float up=max(0.0,30.0*0.55+26.0*0.55-p.y)/50.0;
 float e=base*(0.75+0.55*n)+up*base*rise*n;
 float inner=e-distance;
 vec4 col=vec4(0.0);
 if(raw>0.0&&distance<14.0&&distance<=e&&base>=1.0){
  if(inner<1.0) col=vec4(pop>0.5?vec3(1.0):palette(strength*2.0,0),1.0);
  else if(inner<2.0) col=vec4(palette(strength*2.0,1),1.0);
  else if(mod(p.x+p.y,2.0)<1.0) col=vec4(palette(strength*2.0,2),1.0);
 }
 COLOR=col*tint;
}
