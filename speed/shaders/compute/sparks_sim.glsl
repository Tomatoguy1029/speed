#[compute]
#version 450
// GPU の火花（コンピュートの演出、設計書 10）：火花を進めて減速させ、寿命を減らす。
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

layout(set = 0, binding = 0, std430) restrict buffer Sparks {
	Spark sparks[];
};

layout(push_constant, std430) uniform Params {
	float dt;
	float drag;
	uint count;
	float pad;
} params;

void main() {
	uint i = gl_GlobalInvocationID.x;
	if (i >= params.count) {
		return;
	}
	Spark s = sparks[i];
	if (s.life <= 0.0) {
		return;
	}
	s.pos += s.vel * params.dt;
	s.vel *= max(0.0, 1.0 - params.drag * params.dt);
	s.life -= params.dt;
	sparks[i] = s;
}
