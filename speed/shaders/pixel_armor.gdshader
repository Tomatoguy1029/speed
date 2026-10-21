shader_type canvas_item;
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
	vec4 armor = texture(TEXTURE, UV);
	COLOR = vec4(mix(armor.rgb, vec3(1.0), hit_flash * 0.8) * ambient * brightness, armor.a);
	// MultiMeshの個体ごとの回転も法線へ反映する（描画ノード自体の変換は単位行列）。
	vec3 surface_normal = normalize(vec3(NORMAL.xy * normal_strength, max(NORMAL.z, 0.001)));
	NORMAL = vec3(mat2(instance_x, instance_y) * surface_normal.xy, surface_normal.z);
}

void light() {
	vec3 albedo = mix(texture(TEXTURE, UV).rgb, vec3(1.0), hit_flash * 0.8);
	float diffuse = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	LIGHT = vec4(albedo * brightness * LIGHT_COLOR.rgb * LIGHT_ENERGY * diffuse, LIGHT_COLOR.a);
}
