// Specialized by tools/art/bake_landmark_aura.py; edit the saved profile, then rebake.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clock=0.0;
const float strength=0.0;
const float pop=0.0;
const float pixel_scale=2.5;
const vec4 tint=vec4(1.0);
// 機体の既定値を維持し、敵は元画像の座標系と余白を渡す。
instance uniform vec2 mask_size=vec2(83,122);
const float distance_scale=1.0;
const float rise_origin=30.8;
const bool landmark_mode=true;
const float aura_width=1.25;
const float aura_variation=6.5;
const float aura_intensity=1.0;
const vec4 aura_core=vec4(1.0,0.7011018991470337,0.15896081924438477,1.0);
const vec4 aura_outer=vec4(0.4620770514011383,0.05951124057173729,0.010329820215702057,1.0);
instance uniform bool pump_mask=false;
instance uniform float pump_full=0.0;
instance uniform float mask_padding=32.0;
const float lm_edge_falloff=3.0999999046325684;
const float lm_core_width=3.0;
const float lm_flow_angle=-90.0;
const float lm_flow_coherence=0.699999988079071;
const float lm_flow_spread=2.0;
const float lm_flow_field_scale=0.20000000298023224;
const float lm_flow_field_speed=0.05000000074505806;
const float lm_noise_span=70.0;
const float lm_noise_frequency_1=1.2000000476837158;
const float lm_noise_frequency_2=0.9599999785423279;
const float lm_noise_speed_1=28.0;
const float lm_noise_speed_2=16.0;
const float lm_noise_weight_1=1.0;
const float lm_noise_weight_2=1.0;
const float lm_noise_offset_x=23.0;
const float lm_noise_offset_y=41.0;
const float lm_noise_bias=0.5;
const float lm_noise_contrast=1.0;
const float lm_breakup_span=37.0;
const float lm_breakup_speed=9.0;
const float lm_breakup_strength=0.3499999940395355;
const float lm_breakup_offset_x=17.0;
const float lm_breakup_offset_y=0.0;
const float lm_core_noise_threshold=0.4000000059604645;
const float lm_core_noise_gain=1.600000023841858;
const float lm_edge_opacity=0.9100000262260437;
const float lm_core_opacity=0.4699999988079071;
const float lm_max_opacity=0.8941176533699036;
const float lm_pulse_amount=0.07999999821186066;
const float lm_pulse_seconds=2.0;
const float lm_opacity_step=5.0;
#include "res://shaders/pump_outline.gdshaderinc"
// tuning の値は戦闘エフェクトツールで上書きする（ShaderTuning）。強さで銀→青→金に変わり、各段は縁・中・外の3色
const vec4 silver_rim=vec4(0.949,0.965,1.0,1.0);
const vec4 silver_mid=vec4(0.725,0.776,0.902,1.0);
const vec4 silver_outer=vec4(0.435,0.498,0.682,1.0);
const vec4 blue_rim=vec4(0.902,0.973,1.0,1.0);
const vec4 blue_mid=vec4(0.498,0.816,1.0,1.0);
const vec4 blue_outer=vec4(0.184,0.435,0.753,1.0);
const vec4 gold_rim=vec4(1.0,0.965,0.816,1.0);
const vec4 gold_mid=vec4(1.0,0.824,0.290,1.0);
const vec4 gold_outer=vec4(0.690,0.478,0.078,1.0);
const float flicker_speed=0.30000001192092896;
const float rise=0.6;
vec3 palette(float stage, int band){
 vec3 a[3]=vec3[](silver_rim.rgb,silver_mid.rgb,silver_outer.rgb);
 vec3 b[3]=vec3[](blue_rim.rgb,blue_mid.rgb,blue_outer.rgb);
 vec3 c[3]=vec3[](gold_rim.rgb,gold_mid.rgb,gold_outer.rgb);
 return stage<1.0?mix(a[band],b[band],stage):mix(b[band],c[band],min(1.0,stage-1.0));
}
uniform bool linear_colors=true;
const vec4 aura_core_srgb=vec4(1.0,0.8549019694328308,0.43529412150382996,1.0);
const vec4 aura_outer_srgb=vec4(0.7098039388656616,0.2705882489681244,0.10196078568696976,1.0);
vec2 landmark_flow(vec2 p, float layer){
 float angle=radians(lm_flow_angle);
 vec2 aligned=vec2(cos(angle),sin(angle));
 if(lm_flow_coherence>=1.0) return aligned;
 vec2 offset=vec2(lm_noise_offset_x,lm_noise_offset_y)*layer;
 float field=texture(noise_tex,(p*lm_flow_field_scale+offset)/64.0+vec2(clock*flicker_speed*lm_flow_field_speed)).r;
 float scattered_angle=angle+(field*2.0-1.0)*radians(lm_flow_spread);
 vec2 scattered=vec2(cos(scattered_angle),sin(scattered_angle));
 return normalize(mix(scattered,aligned,lm_flow_coherence));
}
float landmark_noise(vec2 p){
 float t=clock*flicker_speed;
 float a=texture(noise_tex,(p*lm_noise_frequency_1-landmark_flow(p,0.0)*t*lm_noise_speed_1)/lm_noise_span).r;
 float b=texture(noise_tex,(p*lm_noise_frequency_2+vec2(lm_noise_offset_x,lm_noise_offset_y)-landmark_flow(p,1.0)*t*lm_noise_speed_2)/lm_noise_span).r;
 return clamp((a*lm_noise_weight_1+b*lm_noise_weight_2-lm_noise_bias)*lm_noise_contrast,0.0,1.0);
}
void fragment(){
 vec2 p=(floor(UV*mask_size*distance_scale/pixel_scale)+0.5)*pixel_scale;
 vec2 uv=p/(mask_size*distance_scale);
 float raw=texture(TEXTURE,uv).r*255.0;
 float distance=raw/8.0*distance_scale;
 if(landmark_mode && pump_mask && pump_full>0.001){
  vec2 at=floor(p-vec2(mask_padding));
  vec2 radii=pump_radii(at,pump_full);
  vec2 source=pump_source(at,radii);
  vec2 warped=(source+vec2(mask_padding)+0.5)/mask_size;
  float front_distance=texture(TEXTURE,uv).g*255.0/8.0;
  float rear_distance=texture(TEXTURE,warped).b*255.0/8.0*radii.y/radii.x;
  rear_distance=max(rear_distance,length(at-vec2(12.0,27.0))-radii.y);
  distance=min(front_distance,rear_distance);
  raw=distance*8.0;
 }
 float base=0.5+3.3*strength*strength+0.7*pop;
 float n=landmark_mode?landmark_noise(p):clamp(texture(noise_tex,(p*1.2+vec2(0,clock*flicker_speed*28.0))/64.0).r+texture(noise_tex,(p*0.96+vec2(23,clock*flicker_speed*16.0+41.0))/64.0).r-0.5,0.0,1.0);
 float up=max(0.0,rise_origin-p.y)/50.0;
 float e=base*(0.75+0.55*n)+up*base*rise*n;
 float inner=e-distance;
 vec4 col=vec4(0.0);
 if(landmark_mode){
  // 輪郭から外へ薄くなる濃金の揺らぎ。機体の段階色とは独立する。
  float width=aura_width+aura_variation*n;
  if(raw>0.0 && distance<width){
   float edge=distance/max(width,0.001);
   float breakup=texture(noise_tex,(p+vec2(lm_breakup_offset_x,lm_breakup_offset_y)-landmark_flow(p,2.0)*clock*flicker_speed*lm_breakup_speed)/lm_breakup_span).r;
   float broken=(1.0-lm_breakup_strength)+lm_breakup_strength*breakup;
   float core=max(0.0,1.0-distance/lm_core_width)*max(0.0,(n-lm_core_noise_threshold)*lm_core_noise_gain);
   float alpha=(lm_edge_opacity*pow(1.0-edge,lm_edge_falloff)*broken+lm_core_opacity*core)*255.0*aura_intensity;
   alpha*=1.0-lm_pulse_amount+lm_pulse_amount*sin(clock*TAU/lm_pulse_seconds);
   alpha=min(lm_max_opacity*255.0,floor(alpha/lm_opacity_step+0.5)*lm_opacity_step)/255.0;
   col=mix(linear_colors?aura_core:aura_core_srgb,linear_colors?aura_outer:aura_outer_srgb,edge);
   col.a*=alpha;
  }
 }else{
 if(raw>0.0&&distance<14.0&&distance<=e&&base>=1.0){
  if(inner<1.0) col=vec4(pop>0.5?vec3(1.0):palette(strength*2.0,0),1.0);
  else if(inner<2.0) col=vec4(palette(strength*2.0,1),1.0);
  else if(mod(p.x+p.y,2.0)<1.0) col=vec4(palette(strength*2.0,2),1.0);
 }
 }
 COLOR=col*tint;
}
