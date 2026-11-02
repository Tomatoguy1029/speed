#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <vector>
namespace speed {
enum class TechniqueStage : uint8_t { Windup,Active,Recovery,Stuck,Extract,Finished,Failed,Cancelled };
enum class TechniqueCommand : uint8_t { LockAim,LaunchStrike,EndStrike };
struct TechniqueState {
    int64_t id=0;
    uint32_t definition=0,command_cursor=0;
    EnemyHandle actor;
    TechniqueStage stage=TechniqueStage::Windup;
    double elapsed=0,remaining=0,reposition=0;
    godot::Vector2 aim,direction,previous_ship,stuck_offset,reposition_direction;
    uint32_t stuck_body=UINT32_MAX;
    bool locked=false,hit=false;
};
struct BossStates {
    std::vector<TechniqueState> techniques;
    EntityStore<TechniqueTag> handles;
    int64_t next_id=1;
};
}
