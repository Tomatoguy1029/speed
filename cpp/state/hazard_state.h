#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <variant>
namespace speed {
struct CircleHazard {float radius=0;};
struct BeamHazard {float angle=0,length=0,half_width=0,arc=0;uint32_t definition=0;};
struct HazardState {
    godot::Vector2 pos;
    float time=0,delay=0,duration=0;
    double damage=0;
    godot::Color color;
    AttackHandle attack;
    bool alive=true,hit=false;
    std::variant<CircleHazard,BeamHazard> shape=CircleHazard{};
};
}
