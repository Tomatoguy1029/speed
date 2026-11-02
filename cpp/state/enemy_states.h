#pragma once
#include "entity_store.h"
#include "../content/generated/combat_ids.h"
#include <godot_cpp/variant/vector2.hpp>
#include <cstddef>
#include <vector>
#include <array>
#include <variant>
#include <optional>
namespace speed {
using godot::Vector2;
enum class EnemyMode { Move, Windup, Dash, Recover };
struct CoronaBucket {uint32_t definition=0;std::vector<EnemyHandle> items;};
struct CoronaState {std::vector<CoronaBucket> types;uint32_t count=0;double capture_t=0,wait=0;EnemyHandle selected;Vector2 center;bool ready=false;};
struct CoronaMember {EnemyHandle owner;uint32_t definition=0,slot=0;uint64_t serial=0;double angle=0,radius=0,life=0,release_fraction=0,damage=0,effect=0;Vector2 from,ship_from;int64_t attack_token=0;bool settled=false,thrown=false;};
struct CoronaMemberRef {EnemyHandle target;uint64_t serial=0;};
struct PumpState {std::vector<uint32_t> contents;double bud_t=0;};
struct CrabState {int32_t buds=1;AttackHandle sweep;};
struct AquilaState {Vector2 anchor;double bud_t=0;};
struct PhoenixState {Vector2 anchor;};
struct PendingEnemySpawn {uint32_t definition=0;Vector2 position,velocity;double facing=0,hit_cd=0,guard=0,knock=0,priority=0;SpawnOrigin origin=SpawnOrigin::Split;};
struct CrowState {};
struct DefenderBoost {bool active=false;double speed=0,wobble=0,until=0,phase=0;};
struct DefenderState {DefenderBoost boost;};
struct SplitState {double bud_t=0;uint32_t buds=0;};
struct ReticleState {EnemyHandle rock;int64_t rock_id=0;};
struct ClockState {std::array<AttackHandle,2> hands;};
struct AurigaState {};
struct TriangleState {uint32_t buds=0;std::array<AttackHandle,3> trails;};
struct RulerState {int32_t side=0;AttackHandle beam;};
struct CepheusState {uint32_t tier=0;Vector2 anchor;double volley=0;};
struct SoldierFormation {Vector2 anchor;double spacing=0,row_near=0,row_far=0,fan_radius=0,fan_step=0;uint32_t tier=1;};
struct SoldierState {EnemyHandle king;int64_t king_id=0;uint32_t slot=0;SoldierFormation formation;};
struct LynxState {int32_t buds=0;};
struct MarlinState {godot::Vector2 anchor;};
struct SniperState {std::vector<float> rays;};
struct Enemy {
    std::variant<std::monostate,TriangleState,RulerState,CepheusState,SniperState,MarlinState,LynxState,SoldierState,AurigaState,ClockState,ReticleState,PhoenixState,AquilaState,SplitState,DefenderState,CrabState,CrowState,PumpState,CoronaState> behavior_state;
    std::optional<CoronaMember> corona;
    SpawnOrigin origin=SpawnOrigin::Normal;
    SpawnRole role=SpawnRole::Regular;
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
    bool landmark = false;
    bool held = false, slash_hold = false, shoved = false;
    int64_t group_id = 0;
    bool pursuit_ready = false;
    Vector2 pursuit;
    int64_t dash_seen = -1;
    bool dash_fresh = false;
};
}
