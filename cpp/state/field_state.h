#pragma once
#include <cstdint>
#include <vector>
#include "entity_store.h"
#include "../content/generated/combat_ids.h"
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct FieldBody {
    uint32_t definition=0;
    godot::Vector2 position;
    double radius=0,orbit=0,a0=0,direction=1;
    bool moon=false;
};
struct FieldRock {
    RockKind kind=RockKind::Belt;
    godot::Vector2 position,velocity;
    double size=40,facing=0,spin=0,born=0,gone=0;
    uint32_t rare_weapon=0;
    bool destroyed=false,manual=false;
    EnemyHandle proxy;
};
struct GravityWell {godot::Vector2 position;double born=0,life=0,radius=0,pull=0;};
struct FieldState {bool ready=false;double body_speed_max=0;std::vector<FieldBody> bodies;
    double stream_t=0;std::vector<GravityWell> wells;std::vector<FieldRock> rocks;EntityStore<RockTag> rock_handles;};
}
