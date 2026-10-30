#pragma once
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <vector>

namespace speed {
// 編集元から生成した固定値。ランの可変状態とは別に保持する。
struct EnemyDefinition {
    godot::StringName id;
    double hp = 0.0;
    double armor = 0.0;
    double radius = 0.0;
    double speed = 0.0;
    double fire_interval = 0.0;
    godot::Color color;
};
}
