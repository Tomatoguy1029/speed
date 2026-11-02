#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <variant>
#include <vector>
namespace speed {
struct CircleHazard {float radius=0;};
struct BeamHazard {float angle=0,length=0,half_width=0,arc=0;uint32_t definition=0,style=0;};
struct WaveHazard {
    float angle=0,arc=0,radius=0,start_radius=0,speed=0,half_width=0,gap=0,gap_arc=0;
    double enemy_damage=0;
    uint32_t definition=0,style=0;
    std::vector<int64_t> enemy_hits;
};
struct HazardState {
    godot::Vector2 pos;
    float time=0,delay=0,duration=0;
    double damage=0;
    godot::Color color;
    AttackHandle attack;
    bool alive=true,hit=false;
    std::variant<CircleHazard,BeamHazard,WaveHazard> shape=CircleHazard{};
};
}
