#pragma once
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
// Geom.angle_diffと同じ倍精度のwrapf。上端は下端へ戻す。
inline double angle_difference(double difference) {
    const double value=difference-(2.0*godot::Math::PI)*std::floor((difference+godot::Math::PI)/(2.0*godot::Math::PI));
    return godot::Math::is_equal_approx(value,double(godot::Math::PI))?-godot::Math::PI:value;
}
inline double linear_deceleration(double speed,double deceleration,double dt) {return std::max(0.0,speed-deceleration*dt);}
template<class Value> Value exponential_deceleration(Value value,double rate,double dt) {return value*std::exp(-rate*dt);}
}
