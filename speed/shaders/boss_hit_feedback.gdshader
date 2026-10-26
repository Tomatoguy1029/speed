shader_type canvas_item;
render_mode unshaded;
uniform float boss_hit_white : hint_range(0.0, 0.28) = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), boss_hit_white);
}
