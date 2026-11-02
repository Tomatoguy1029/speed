#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <cstddef>
#include <vector>
#include <variant>
namespace speed {
using godot::Vector2;
enum class EnemyMode { Move, Windup, Dash, Recover };
struct AurigaState {};
struct SoldierFormation {Vector2 anchor;double spacing=0,row_near=0,row_far=0,fan_radius=0,fan_step=0;uint32_t tier=1;};
struct SoldierState {EnemyHandle king;int64_t king_id=0;uint32_t slot=0;SoldierFormation formation;};
struct LynxState {int32_t buds=0;};
struct MarlinState {godot::Vector2 anchor;};
struct SniperState {std::vector<float> rays;};
struct Enemy {
    std::variant<std::monostate,SniperState,MarlinState,LynxState,SoldierState,AurigaState> behavior_state;
    int64_t id = 0;
    int64_t attack_group = 0;
    double attack_value = 1, attack_priority = 0;
    bool attack_managed = false;
    size_t definition = 0, behavior_group = 0, behavior_slot = 0;
    Vector2 pos, vel;
    double hp = 0.0, max_hp = 0.0, radius = 0.0, armor = 0.0, xp = 0.0, speed = 0.0;
    double facing = 0.0, age = 0.0, fire_t = 0.0, spin = 0.0;
    EnemyMode mode = EnemyMode::Move;
    double timer = 0, charge = 0;
    bool alive = false, dead = false, elite = false, is_boss = false, hull_scattered = false;
    double guard = 0;
    speed::EnemyHandle damage_target;
    speed::EnemyHandle parent;
    int64_t parent_id=0;
    std::vector<speed::EnemyHandle> parts;
    speed::RockHandle rock;
    speed::EnemyHandle pump_owner;
    double hit_cd = 0, flash = 0;
    double stone = 0, knock_t = 0, shove_time = 0;
    Vector2 shove_vel, shove_from;
    double body_gap=-1,body_gap_time=0;
    Vector2 body_gap_pos;
    bool held = false, slash_hold = false, shoved = false;
    int64_t group_id = 0;
    bool pursuit_ready = false;
    Vector2 pursuit;
    int64_t dash_seen = -1;
    bool dash_fresh = false;
};
}
