#[compute]
#version 450
// GPU の火花（コンピュートの演出、設計書 10）：火花を画面の大きさの絵に点として描く。
// 1回目（mode 0）は絵を消し、2回目（mode 1）は火花ごとに小さな円を足す。
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Spark {
	vec2 pos;
	vec2 vel;
	float life;
	float max_life;
	float size;
	float pad;
	vec4 color;
};

layout(set = 0, binding = 0, std430) restrict readonly buffer Sparks {
	Spark sparks[];
};

layout(set = 0, binding = 1, rgba16f) uniform restrict image2D canvas;

layout(push_constant, std430) uniform Params {
	vec2 view_center;
	vec2 image_size;
	float zoom;
	uint count;
	uint mode;
	float pad;
} params;

void main() {
	uint i = gl_GlobalInvocationID.x;
	if (params.mode == 0u) {
		uint w = uint(params.image_size.x);
		uint total = w * uint(params.image_size.y);
		for (uint k = i; k < total; k += gl_NumWorkGroups.x * 64u) {
			imageStore(canvas, ivec2(int(k % w), int(k / w)), vec4(0.0));
		}
		return;
	}
	if (i >= params.count) {
		return;
	}
	Spark s = sparks[i];
	if (s.life <= 0.0) {
		return;
	}
	vec2 p = (s.pos - params.view_center) * params.zoom + params.image_size * 0.5;
	float k = clamp(s.life / s.max_life, 0.0, 1.0);
	int r = int(max(1.0, s.size * params.zoom * 0.5));
	for (int x = -r; x <= r; x++) {
		for (int y = -r; y <= r; y++) {
			if (x * x + y * y > r * r) {
				continue;
			}
			ivec2 q = ivec2(p) + ivec2(x, y);
			if (q.x < 0 || q.y < 0 || q.x >= int(params.image_size.x) || q.y >= int(params.image_size.y)) {
				continue;
			}
			vec4 prev = imageLoad(canvas, q);
			imageStore(canvas, q, prev + vec4(s.color.rgb * k, k));
		}
	}
}
