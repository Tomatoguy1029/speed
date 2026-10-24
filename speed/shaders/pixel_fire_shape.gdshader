// 変形した密度場を画素の中心で評価し、画素化後にAlpha境界を補正する。
shader_type canvas_item;
render_mode unshaded;
uniform vec2 field_size = vec2(220.0, 280.0);
uniform float pixel_size = 4.0;
uniform float clock = 0.0;
uniform float deformation = 4.5;
uniform float threshold = 0.32;
uniform float edge_softness = 0.04;
uniform vec4 outer_color : source_color = vec4(0.9, 0.3, 0.1, 1.0);
uniform vec4 inner_color : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
void fragment() {
	vec2 pixel = (floor(UV * field_size / pixel_size) + 0.5) * pixel_size / field_size;
	vec2 w = pixel * field_size;
	vec2 warp = vec2(sin(w.y * 0.075 - clock * 4.4) + sin(w.x * 0.11 + w.y * 0.033 + clock * 2.1),
		cos(w.x * 0.08 + clock * 3.0) * 0.55);
	vec3 density = texture(TEXTURE, clamp(pixel + warp * deformation / field_size, vec2(0.001), vec2(0.999))).rgb;
	vec3 coverage = smoothstep(vec3(threshold), vec3(threshold + edge_softness), density);
	// 中間の半透明を残さず、結合した輪郭と色面をくっきりさせる。
	vec3 mask = step(vec3(0.5), coverage);
	mask.g *= mask.r;
	mask.b *= mask.g;
	vec3 color = mix(outer_color.rgb, inner_color.rgb, mask.g);
	color = mix(color, core_color.rgb, mask.b);
	COLOR = vec4(color, mask.r);
}
