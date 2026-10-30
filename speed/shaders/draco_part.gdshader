shader_type canvas_item;
render_mode unshaded;

uniform bool use_normal = true;
uniform bool cosmic = false;
uniform float boss_hit_white : hint_range(0.0, 0.28) = 0.0;
uniform bool normal_flip_x = false;
uniform bool painted = false;
uniform vec4 paint : source_color = vec4(1.0);
uniform float normal_strength = 1.0;
uniform float ambient = 0.08;
uniform float key_energy = 1.1;
uniform float fill_energy = 0.6;
uniform vec3 key_direction = vec3(0.686, -0.686, 0.243);
uniform vec3 fill_direction = vec3(-0.686, 0.686, 0.243);
varying vec2 axis_x;
varying vec2 axis_y;
varying vec4 vertex_tint;

void vertex() {
	axis_x = normalize(MODEL_MATRIX[0].xy);
	axis_y = normalize(MODEL_MATRIX[1].xy);
	vertex_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec3 albedo = pixel.rgb;
	if (painted) {
		float shade = max(pixel.r, max(pixel.g, pixel.b));
		albedo = paint.rgb * shade;
	}
	float light_amount = 1.0;
	if (use_normal) {
		vec3 normal = texture(NORMAL_TEXTURE, UV).rgb * 2.0 - 1.0;
		if (normal_flip_x) { normal.x = -normal.x; }
		normal = normalize(vec3(normal.xy * normal_strength, max(normal.z, 0.001)));
		vec2 world_xy = mat2(axis_x, -axis_y) * normal.xy;
		normal = vec3(world_xy, normal.z);
		light_amount = ambient + key_energy * max(dot(normal, key_direction), 0.0)
			+ fill_energy * max(dot(normal, fill_direction), 0.0);
	}
	vec3 result = albedo * light_amount;
	if (cosmic) {
		float wave = sin(UV.y * 19.0 + UV.x * 8.0 + TIME * 2.0) * 0.5 + 0.5;
		result = mix(result, mix(vec3(0.14, 0.08, 0.45), vec3(0.25, 0.8, 1.0), wave), 0.65);
	}
	COLOR = vec4(mix(result, vec3(1.0), boss_hit_white), pixel.a) * vertex_tint;
}
