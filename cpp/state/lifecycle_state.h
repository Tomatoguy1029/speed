#pragma once
#include "loadout_state.h"
#include "combat_types.h"
#include <optional>
namespace speed {
struct ResultReward {uint32_t equipment=0;int64_t amount=0;};
struct RunResult {
    int64_t id=0;ResultKind kind=ResultKind::Death;
    double run_time=0,world_time=0,peak_speed=0;
    int64_t level=0,kills=0,coins=0;
    std::vector<ResultReward> rewards;
    std::vector<EquipmentLevel> weapons,traits;
    ShipDamageRequest last_request;ShipDamageResult last_damage;bool has_damage=false;
};
struct LifecycleState {
    int64_t coins=0;
    bool endless=false;
    std::optional<RunResult> result;
    std::vector<uint32_t> obtained;
    ShipDamageRequest last_request;ShipDamageResult last_damage;bool has_damage=false;
};
}
