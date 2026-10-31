// pixel_armorと同じ照明処理。切出したArmor/Normalと、元の領域キーによる塗装を使う。
shader_type canvas_item;
uniform sampler2D painted_armor : source_color, filter_nearest;
uniform float brightness = 1.0;
uniform float ambient = 0.08;
uniform float normal_strength = 1.0;
varying float hit_flash;
varying float fuse_flash;
varying vec2 instance_x;
varying vec2 instance_y;

vec4 armor_at(sampler2D diffuse, vec2 uv) {
	return vec4(texture(painted_armor, uv * vec2(1.0, 28.0 / 42.0)).rgb, texture(diffuse, uv).a);
}
void vertex() {
	hit_flash = COLOR.r;
	fuse_flash = COLOR.g;
	instance_x = normalize(MODEL_MATRIX[0].xy);
	instance_y = normalize(MODEL_MATRIX[1].xy);
}
void fragment() {
	vec4 armor = armor_at(TEXTURE, UV);
	vec3 base = mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient;
	base = mix(base, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9 * (1.0 - hit_flash));
	COLOR = vec4(base * brightness, armor.a);
	vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
	NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
}
void light() {
	vec3 albedo = mix(armor_at(TEXTURE, UV).rgb, vec3(1.0, 0.045, 0.02), fuse_flash * 0.9);
	albedo = mix(albedo, vec3(1.0), hit_flash * 0.8);
	float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse, LIGHT_COLOR.a);
}
