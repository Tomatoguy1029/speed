#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <vector>
#include <unordered_map>
namespace speed {
enum class TechniqueStage : uint8_t { Windup,Active,Recovery,Stuck,Extract,Finished,Failed,Cancelled };
enum class TechniqueCommand : uint8_t { LockAim,LaunchStrike,EndStrike };
struct TechniqueState {
    int64_t id=0;
    uint32_t definition=0,command_cursor=0,ticket_refs=0;
    EnemyHandle actor;
    TechniqueStage stage=TechniqueStage::Windup;
    double elapsed=0,remaining=0,reposition=0;
    godot::Vector2 aim,direction,previous_ship,stuck_offset,reposition_direction;
    uint32_t stuck_body=UINT32_MAX;
    bool locked=false,hit=false;
};
enum class FlowStatus : uint8_t { Running,Finished,Failed,Cancelled };
struct FlowNodeState {
    uint32_t definition=0,cursor=0,child=UINT32_MAX;
    double elapsed=0;
    FlowStatus status=FlowStatus::Running;
    TechniqueHandle ticket;
    std::vector<uint32_t> branches;
};
struct BossFlowState {
    uint32_t definition=0,index=0,rest_next=0,completed_actions=0,phase=1;
    EnemyHandle actor;
    bool active=false,waiting=false,blocked=false,suspended=false,selection_enabled=true;
    double clock=0,retry=0,stamina=0,rest_remaining=0,section_spent=0,interval=0,no_candidate_elapsed=0,post_gap=0;
    std::vector<uint32_t> last,roots;
    std::vector<FlowNodeState> nodes;
    std::vector<EnemyHandle> participants;
    std::unordered_map<uint64_t,double> cooldowns;
};
enum class BossMode : uint8_t { Entrance,Idle,Phase,Final,Defeated,Cancelled };
struct BossBodyState {
    int64_t id=0;
    uint32_t definition=0,phase=1;
    EnemyHandle actor;
    BossMode mode=BossMode::Idle;
    bool phase_pending=false,final_landed=false;
    double clock=0,initial_wait=0,entrance_elapsed=0,phase_remaining=0,final_started=-1,final_elapsed=0,final_charge=0;
    godot::Vector2 entrance_from,entrance_target,final_to;
    double final_width=0;
};
struct BossStates {
    std::vector<BossBodyState> bodies;
    EntityStore<BossTag> body_handles;
    int64_t next_body_id=1;
    std::vector<BossFlowState> flows;
    std::vector<TechniqueState> techniques;
    EntityStore<TechniqueTag> handles;
    int64_t next_id=1;
};
}
