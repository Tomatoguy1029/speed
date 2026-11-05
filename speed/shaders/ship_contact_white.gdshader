// 接触攻撃による被弾だけを、元の透明度と点滅周期のまま白くする。
shader_type canvas_item;
render_mode unshaded;
uniform float strength = 0.0;
void fragment() { COLOR.rgb = mix(COLOR.rgb, vec3(1.0), strength); }
