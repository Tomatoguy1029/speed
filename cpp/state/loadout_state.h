#pragma once
#include "../content/generated/combat_ids.h"
#include <cstdint>
#include <vector>
namespace speed {
struct EquipmentLevel {uint32_t definition=0,level=0;};
struct CardCandidate {int64_t id=0;CardKind kind=CardKind::Weapon;uint32_t definition=0,level=0;};
struct LoadoutState {
    bool ready=false,initial_offer=false;
    int64_t level=0,pending_levels=0,rerolls=0,next_offer_id=1,offer_id=0,selected_id=0;
    double xp=0,xp_gained=0,xp_gain_mult=1;
    std::vector<EquipmentLevel> weapons,traits;
    std::vector<CardCandidate> candidates;
};
}
