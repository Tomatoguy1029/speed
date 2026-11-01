#pragma once
#include <godot_cpp/core/math.hpp>
#include <cmath>
namespace speed {
// Geom.angle_diff と同じ倍精度wrapf。上端に近い値も下端へ戻す。
// https://github.com/godotengine/godot/blob/4.6-stable/core/math/math_funcs.h
inline double angle_difference(double difference) {
    const double value = difference - (2.0 * godot::Math::PI) * std::floor((difference + godot::Math::PI) / (2.0 * godot::Math::PI));
    return godot::Math::is_equal_approx(value, double(godot::Math::PI)) ? -godot::Math::PI : value;
}
}
