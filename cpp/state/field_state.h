#pragma once
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct FieldBody {uint32_t definition=0;godot::Vector2 position;};
struct FieldState {bool ready=false;std::vector<FieldBody> bodies;};
}
