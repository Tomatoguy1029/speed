shader_type canvas_item;
render_mode unshaded;

uniform bool use_normal = false;
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
		normal = normalize(vec3(normal.xy * normal_strength, max(normal.z, 0.001)));
		vec2 world_xy = mat2(axis_x, -axis_y) * normal.xy;
		normal = vec3(world_xy, normal.z);
		light_amount = ambient + key_energy * max(dot(normal, key_direction), 0.0)
			+ fill_energy * max(dot(normal, fill_direction), 0.0);
	}
	COLOR = vec4(albedo * light_amount, pixel.a) * vertex_tint;
}
