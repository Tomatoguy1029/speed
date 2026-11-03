#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
class RunUpBehavior {
public:
    static void step(RunRuntime &,double);
    static void launch(RunRuntime &);
    static double multiplier(RunRuntime &,double extra_distance);
    static void contact(RunRuntime &,godot::Vector2,godot::Vector2,double applied);
};
}
