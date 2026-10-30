// PixelShapes の図形の判定（pixel_shapes.gdshader・pixel_shapes_mix.gdshader で共有）。
// INSTANCE_CUSTOM：x 四角の半幅（ドット、整数）＋中心の横の端数、y・z・w は図形ごとの値。四角の中心は格子の角で、
// 図形の本当の中心はそこから端数だけずれる（縦の端数は図形ごとの値に入れる）。
// shape 0：隙間のない輪（y 半径、z 1ドット内側の輪の濃さの割合。0 なら描かない、w 縦の端数）。PixelPainter.ring と同じ形。
// shape 1：両端の尖った針（y 長さ、z 片側の幅、w 向き）。外側は紫、内側に白い芯。PixelPainter.spindle と同じ形。
// shape 2：太さのある輪（y 半径、z 太さ（整数）＋縦の端数、w 揺らぎ）。PixelPainter.thick_ring と同じ形。
// shape 3：六角形の輪郭（y 頂点までの半径、z 縦の端数。頂点は 30 度から 60 度おき）。
uniform int shape = 0;
varying vec4 data;
varying vec2 local;

void vertex() {
	data = INSTANCE_CUSTOM;
	local = VERTEX * floor(INSTANCE_CUSTOM.x);
}

// 図形の色（rgb）と濃さ（a）。図形の外は a = 0。
vec4 shape_color(vec4 tint) {
	vec2 cell = floor(local);
	float fx = fract(data.x);
	if (shape == 0) {
		cell -= vec2(fx, data.w);
		float dist = length(cell);
		float r = data.y;
		if (abs(dist - r) < 0.55) {
			return tint;
		}
		if (data.z > 0.0 && r > 3.0 && abs(dist - (r - 1.0)) < 0.55) {
			return vec4(tint.rgb, tint.a * data.z);
		}
		return vec4(0.0);
	}
	if (shape == 1) {
		vec2 d = cell + 0.5;
		vec2 u = vec2(cos(data.w), sin(data.w));
		vec2 n = vec2(-u.y, u.x);
		float a = abs(dot(d, u));
		float b = abs(dot(d, n));
		if (a / (data.y * 0.5) + b / max(data.z, 0.01) > 1.0) {
			return vec4(0.0);
		}
		bool white = a / (data.y * 0.42) + b / max(data.z * 0.35, 0.01) <= 1.0;
		return vec4(white ? vec3(1.0) : vec3(0.659, 0.333, 1.0), tint.a);
	}
	if (shape == 2) {
		cell -= vec2(fx, fract(data.z));
		float dist = length(cell);
		float rr = data.y * (1.0 + data.w * sin(atan(cell.y, cell.x) * 5.0 + data.y * 0.1));
		if (dist <= rr + 0.5 && dist >= rr - (floor(data.z) - 1.0) - 0.5) {
			return tint;
		}
		return vec4(0.0);
	}
	cell -= vec2(fx, data.z);
	float edge = 0.0;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0471976;
		edge = max(edge, dot(cell, vec2(cos(a), sin(a))));
	}
	if (abs(edge - data.y * 0.8660254) < 0.5) {
		return tint;
	}
	return vec4(0.0);
}
