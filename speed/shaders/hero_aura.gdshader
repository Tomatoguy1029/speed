shader_type canvas_item;
uniform sampler2D curves : filter_linear, repeat_disable;
uniform vec2 cell_count = vec2(1.0);
uniform vec2 radii = vec2(1.0);
uniform vec2 aura_center = vec2(0.0);
uniform float cell_size = 4.0;
uniform float breath = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	// 矩形の境界でUV補間が整数の直前へ丸められる誤差を補う。
	vec2 cell = min(floor(UV*cell_count+vec2(0.0001)),cell_count-vec2(1.0));
	vec2 at = (aura_center-radii)+cell*cell_size;
	vec2 q = (at-aura_center)/radii;
	// 表には両端を含む。各軸をテクセルの中心で読む。
	float samples = float(textureSize(curves,0).x);
	vec2 sample_uv = ((q+vec2(1.0))*0.5*(samples-1.0)+vec2(0.5))/samples;
	vec4 x = texture(curves,vec2(sample_uv.x,0.125));
	float sx = texture(curves,vec2(sample_uv.x,0.375)).r;
	vec4 y = texture(curves,vec2(sample_uv.y,0.625));
	float sy5 = texture(curves,vec2(sample_uv.y,0.875)).r;
	float cloud = 0.78+0.22*(x.g*y.g+x.b*y.b)*(y.a*x.a+sy5*sx);
	float density = x.r*y.r*cloud;
	float alpha = floor(density*24.0)/24.0*0.25*breath;
	COLOR = vec4(tint.rgb,alpha)*COLOR;
}
