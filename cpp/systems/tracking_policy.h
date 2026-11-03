#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
// 自律操舵だけを抑える。外力と確定済みの軌道は呼出し側が進める。
struct TrackingPolicy {
    bool tracing=false,held=false,pump_owned=false;
    bool locked() const {return tracing && !held && !pump_owned;}
    double angle(double facing,double desired) const {return locked()?facing:desired;}
    godot::Vector2 target(godot::Vector2 position,double facing,godot::Vector2 desired) const;
    godot::Vector2 velocity(godot::Vector2 previous,double facing,godot::Vector2 desired) const;
};
}
