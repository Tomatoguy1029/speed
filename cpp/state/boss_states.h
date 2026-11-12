#pragma once
#include "entity_store.h"
#include "state_box.h"
#include "technique_detail.h"
#include "combat_types.h"
#include "../content/generated/combat_ids.h"
#include "../content/boss_image_data.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <string>
#include <vector>
#include <variant>
#include <unordered_map>
#include <unordered_set>
namespace speed {
struct HydraBodyState;
struct DracoBodyState;
struct CanisBodyState;
struct CentaurusBodyState;
struct MonocerosBodyState;
enum class TechniqueStage : uint8_t { Windup,Active,Recovery,Stuck,Extract,Finished,Failed,Cancelled };
enum class TechniqueCommand : uint8_t { LockAim,LaunchStrike,EndStrike,ReleaseArrow,FinishVolley,StrikeRear,BeginRain,AlertPower };
struct TechniqueState {
    TechniqueDetail detail;
    int64_t id=0,observation_id=0,decision_id=0;
    std::string observation_origin="external_forced";
    uint32_t definition=0,command_cursor=0,ticket_refs=0,combo_definition=0,combo_step=0;
    bool combo_waiting=false;
    EnemyHandle actor;
    TechniqueStage stage=TechniqueStage::Windup;
    double elapsed=0,remaining=0,reposition=0,started_at=0;
    godot::Vector2 aim,direction,previous_ship,stuck_offset,reposition_direction;
    uint32_t stuck_body=UINT32_MAX;
    bool locked=false,hit=false;
};
enum class FlowStatus : uint8_t { Running,Finished,Failed,Cancelled };
struct FlowNodeState {
    int64_t decision_id=0;
    uint32_t definition=0,cursor=0,child=UINT32_MAX;
    double elapsed=0;
    FlowStatus status=FlowStatus::Running;
    TechniqueHandle ticket;
    std::vector<uint32_t> branches;
};
struct BossFlowState {
    int64_t decision_id=0;
    uint32_t definition=0,index=0,rest_next=0,completed_actions=0,phase=1;
    int32_t last_category_override=-1;
    EnemyHandle actor;
    bool active=false,waiting=false,blocked=false,suspended=false,selection_enabled=true;
    double clock=0,retry=0,stamina=0,rest_remaining=0,section_spent=0,interval=0,no_candidate_elapsed=0,post_gap=0;
    std::vector<uint32_t> last,roots;
    std::vector<FlowNodeState> nodes;
    std::vector<EnemyHandle> participants;
    std::unordered_map<uint64_t,double> cooldowns;
    std::unordered_map<uint64_t,double> cooldown_started;
};
enum class BossMode : uint8_t { Entrance,Idle,Phase,Final,Defeated,Cancelled };
// 本体と独立HPの部位を、表示Nodeに依存せず保持する。
struct ParticipantState {
    EnemyHandle actor,health_target;
    int64_t id=0;
    bool is_body=true,active=true;
};
struct BossBodyState {
    double hit_feedback_until=0;
    std::vector<BossImagePart> image_parts;
    int64_t final_observation_id=0;
    StateBox<HydraBodyState> hydra;
    StateBox<DracoBodyState> draco;
    StateBox<CanisBodyState> canis;
    StateBox<CentaurusBodyState> centaurus;
    StateBox<MonocerosBodyState> monoceros;
    std::vector<ParticipantState> participants;
    int64_t id=0;
    uint32_t definition=0,phase=1;
    int32_t sweep_side=1;
    EnemyHandle actor;
    BossMode mode=BossMode::Idle;
    bool phase_pending=false,final_landed=false,has_slash=false;
    godot::Vector2 slash_from,slash_to;
    double clock=0,initial_wait=0,entrance_elapsed=0,phase_remaining=0,final_started=-1,final_elapsed=0,final_charge=0;
    godot::Vector2 entrance_from,entrance_target,final_to;
    double final_width=0;
};
struct BossFinishState {
    bool active=false,blasted=false,banner=false,final_started=false;
    // ブーストのとどめだけが、当たった向きの切り口を持つ。
    bool boost=false,reveal=false;
    double elapsed=0,base_zoom=1;
    godot::Vector2 origin,impact,direction,ship;
    // 撃破演出の中心（うみへび座は不死の蛇の頭）と、崩れる範囲（世界単位、0なら絵の既定）。
    bool has_focus=false;
    godot::Vector2 focus;
    double reach=0;
};
struct BossStates {
    BossFinishState finish;
    std::vector<BossBodyState> bodies;
    EntityStore<BossTag> body_handles;
    int64_t next_body_id=1;
    std::vector<BossFlowState> flows;
    std::vector<TechniqueState> techniques;
    EntityStore<TechniqueTag> handles;
    int64_t next_id=1;
};
}
