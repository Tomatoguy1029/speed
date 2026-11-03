#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <cstdint>
#include <vector>
namespace speed {
struct PreviousPose {int64_t id=0;godot::Vector2 position;double angle=0;};
struct PreviousPoseState {
    godot::Vector2 ship_position;double ship_angle=0;bool ready=false;
    std::vector<PreviousPose> enemies,friendly;
};
}
