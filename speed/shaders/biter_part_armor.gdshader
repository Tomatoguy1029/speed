shader_type canvas_item;
uniform sampler2D paint_tex : source_color, filter_nearest;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
varying float hit_flash;
varying vec2 instance_x;
varying vec2 instance_y;

void vertex() {
	hit_flash = COLOR.r;
	instance_x = normalize(MODEL_MATRIX[0].xy);
	instance_y = normalize(MODEL_MATRIX[1].xy);
}
void fragment() {
	// RGBは共通の確定塗装、アルファと法線は制作時に分割した部位。
	vec4 armor = texture(paint_tex, UV);
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient * brightness, alpha);
	vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
	NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
}
void light() {
	vec3 albedo = mix(texture(paint_tex, UV).rgb, vec3(1.0), hit_flash * 0.8);
	LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * max(dot(NORMAL, LIGHT_DIRECTION), 0.0), LIGHT_COLOR.a);
}
