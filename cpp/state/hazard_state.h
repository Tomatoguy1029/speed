#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <variant>
#include <vector>
namespace speed {
enum class CircleHazardKind { Bite, Blast };
struct CircleHazard {float radius=0;CircleHazardKind kind=CircleHazardKind::Bite;};
struct BeamHazard {float angle=0,length=0,half_width=0,arc=0;uint32_t definition=0,style=0;int64_t flood_group=0;};
struct WallHazard {float angle=0,length=0,half_width=0;uint32_t definition=0,style=0;bool blocking=false;};
struct WaveHazard {
    float angle=0,arc=0,radius=0,start_radius=0,speed=0,half_width=0,gap=0,gap_arc=0;
    double enemy_damage=0;
    uint32_t definition=0,style=0;
    std::vector<int64_t> enemy_hits;
};
struct MonocerosWaveHazard {
    double radius=0,maximum=0,speed=0,angle=0,half_angle=0,width=0;
};
struct CanisFlameHazard {
    enum class Kind : uint8_t { Jet,Particle,Trail,Transfer };
    Kind kind=Kind::Particle;
    uint32_t definition=0;
    int64_t observation=0;
    godot::Vector2 origin,velocity;
    double age=0,life=0,emit=0,angle=0,length=0,radius=0;
    bool source_ended=false;
    EnemyHandle target;
    AttackHandle jet,trail;
};
struct CanisHoundLungeHazard {
    EnemyHandle actor;
    godot::Vector2 previous,velocity;
    int64_t action=0;
    double until=0,last_world_time=-1;
    bool sweep=true,shared_hit=false,overwrite_velocity=true,release_on_cancel=true,release_on_end=true,defer_first_contact=false;
};
struct HazardState {
    godot::Vector2 pos;
    float time=0,delay=0,duration=0;
    double damage=0;
    godot::Color color;
    AttackHandle attack;
    uint32_t zone_definition=0;
    double enemy_damage=0;
    bool alive=true,hit=false;
    std::variant<CircleHazard,BeamHazard,WaveHazard,WallHazard,MonocerosWaveHazard,CanisFlameHazard,CanisHoundLungeHazard> shape=CircleHazard{};
};
}
