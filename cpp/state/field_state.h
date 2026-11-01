#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct FieldBody {
    uint32_t definition=0;
    godot::Vector2 position;
    double radius=0,orbit=0,a0=0,direction=1;
    bool moon=false;
};
struct FieldState {bool ready=false;double body_speed_max=0;std::vector<FieldBody> bodies;};
}
