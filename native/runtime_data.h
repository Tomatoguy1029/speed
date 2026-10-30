#pragma once
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <vector>

namespace speed {
// 編集元から生成した固定値。ランの可変状態とは別に保持する。
struct EnemyDefinition {
    godot::StringName id;
    enum class Kind { Chase, Shield } kind = Kind::Chase;
    double accel = 0, turn = 0, weak_arc = 0;
    double front_arc = 0, reflect_speed = 0, reflect_life = 0, reflect_damage = 0, reflect_interval = 0, shield_time = 0;
    double hp = 0.0;
    double armor = 0.0;
    double radius = 0.0;
    double speed = 0.0;
    double fire_interval = 0.0;
    double xp = 0.0, knockback = 0.0, hitstop_multiplier = 0.0;
    godot::Color color;
};
}
