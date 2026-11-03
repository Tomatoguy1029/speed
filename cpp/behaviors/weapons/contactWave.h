#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {class RunRuntime;
class ContactWaveBehavior {
public:
    static void contact(RunRuntime &,godot::Vector2);
    static void step(RunRuntime &,double dt);
};
}
