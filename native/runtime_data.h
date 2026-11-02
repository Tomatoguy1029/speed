#pragma once
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <vector>
#include <array>

namespace speed {
// 編集元から生成した固定値。ランの可変状態とは別に保持する。
struct EnemyDefinition {
    godot::StringName id;
    uint32_t reflected_definition=0,gunner_definition=0,beamer_definition=0,missile_definition=0,rocket_definition=0,drift_definition=0,dash_definition=0,battleship_definition=0,sniper_definition=0;
    uint32_t visual_id=0;double sprite_scale=1,sprite_angle=0;bool polygon_visual=false,ram_guard=false;
    enum class Kind { Chase, Shield, Biter, Hound, Meteor, Obstacle, Saw, Gunner, Beamer, Missile, Rocket, Drift, Part, Dash, Battleship, Sniper } kind = Kind::Chase;
    struct Bite { double reach = 0, telegraph = 0, rest = 0, radius = 0, damage = 0; } bite;
    struct Pack { int64_t count = 1; double gap = 0, reach = 1, alignment = 0, cohesion = 0, separation = 0; } pack;
    bool spawn_ready = false, size_var = false;
    double attack_value = 1, attack_priority = 0, attack_weight = 0, attack_telegraph = 0;
    bool attack_managed = true;
    int64_t rank = 0;
    double accel = 2, turn = 4, weak_arc = 0;
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
    std::array<uint32_t,3> xp_rewards{};
    bool gold_eligible=false,reward_scattered=false,reward_burst=false;
    godot::Color color;
};
struct SpawnTimeline {
    struct Phase {
        godot::StringName id, wave_type;
        double wave_interval = 0;
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
