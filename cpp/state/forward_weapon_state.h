#pragma once
#include "../content/generated/combat_ids.h"
#include "entity_store.h"
#include "../systems/timing.h"
#include <cstdint>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
namespace speed {
struct ForwardWeaponState {
    bool ready = false;
    IntervalTimer fire;
    double recoil = 0;
    double base_interval = 0, interval = 0, damage = 0, life = 0, spread = 0, knock = 0, character_scale = 0;
    int64_t pierce = 0;
};
}
