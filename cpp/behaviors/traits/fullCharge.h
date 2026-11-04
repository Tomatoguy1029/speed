#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
class FullChargeBehavior {
public:
    static double multiplier(const RunRuntime &,double distance);
    static void launch(RunRuntime &);
    static void prepare(RunRuntime &,double extra_distance);
    static void trail(RunRuntime &,godot::Vector2 from,godot::Vector2 to);
    static void end(RunRuntime &);
};
}
