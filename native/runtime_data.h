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
    struct Scaling {
        bool ready = false, fixed_sprite = false;
        double radius = 0, hp = 0, armor = 0, hp_mult = 1, armor_mult = 1;
        double character = 1, visual = 1, collision = 1;
    } scaling;
    double hp = 0.0;
    double armor = 0.0;
    double radius = 0.0;
    double speed = 0.0;
    double fire_interval = 0.0;
    double xp = 0.0, knockback = 0.0, hitstop_multiplier = 0.0;
    godot::Color color;
};
struct SpawnTimeline {
    struct Phase {
        godot::StringName id;
        double start = 0, pop_from = 0, pop_to = 0, rate = 0, xp_bonus = 0;
        double interval = 0, pop = 0, ranged = 0, elite = 0;
        int64_t budget = 0;
        std::vector<std::pair<godot::StringName, double>> mix;
    };
    struct Point { double time, value, slope; };
    struct Curve { godot::StringName type; std::vector<Point> points; };
    struct Type { godot::StringName id; double rank, maximum; bool ranged; };
    std::vector<Phase> phases;
    std::vector<Curve> curves;
    std::vector<Type> types;
    std::vector<std::pair<double, double>> windows;
    double boss_start = 0, density = 0, bonus_pop = 0;
};
}
