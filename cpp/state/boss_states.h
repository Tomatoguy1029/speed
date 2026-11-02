#pragma once
#include "entity_store.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <vector>
#include <variant>
#include <unordered_map>
#include <unordered_set>
namespace speed {
enum class TechniqueStage : uint8_t { Windup,Active,Recovery,Stuck,Extract,Finished,Failed,Cancelled };
enum class TechniqueCommand : uint8_t { LockAim,LaunchStrike,EndStrike,ReleaseArrow,FinishVolley,StrikeRear,BeginRain,AlertPower };
struct CentaurusShowerMark {godot::Vector2 center;double at=0;bool shown=false,landed=false;};
struct CentaurusShowerState {std::vector<CentaurusShowerMark> marks;uint32_t placed=0;bool launched=false;};
struct CentaurusRainTrace {godot::Vector2 start,direction;double started=0,next_drop=0,landed=0;int32_t turn=1;bool hit=false;};
struct CentaurusRainState {std::vector<CentaurusRainTrace> traces;uint32_t left=0;double next_at=0,expire_at=0;};
struct CentaurusPowerState {godot::Vector2 origin;double angle=0;uint32_t released=0;bool alerting=false;};
struct CentaurusSailState {godot::Vector2 center;double radius=0,angle=0;int32_t side=1;uint32_t fired=0;bool boosted=false;};
struct CentaurusVolleyState {uint32_t released=0;};
struct MonocerosSweepState {
    enum class Stage : uint8_t { Approach,Stop,Swing,Hold,Return };
    Stage stage=Stage::Approach;
    double elapsed=0,angle=0,glow=0,base=0,speed=0;
    int32_t side=1;
};
struct MonocerosLanceState {
    enum class Stage : uint8_t { Gather,Run,Stop };
    Stage stage=Stage::Gather;
    double elapsed=0,form=0,glow=0,traveled=0,boom_time=0,speed=0;
    bool shattered=false;
};
struct MonocerosReturnState {
    enum class Stage : uint8_t { Aim,Run,Brake,Turn };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,travel=0,traveled=0,from_angle=0,turn_delta=0;
    uint32_t completed=0;
};
struct MonocerosHornWaveState {
    enum class Stage : uint8_t { Windup,Swing,Recharge,Return };
    Stage stage=Stage::Windup;
    double elapsed=0,angle=0,glow=0;
    int32_t direction=1;
    bool released=false;
};
struct MonocerosDanceState {
    enum class Stage : uint8_t { Aim,Run,Circle,End };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,run_speed=0,travel=0,traveled=0,heading=0,speed=0;
    uint32_t completed=0;
};
struct MonocerosSwordState {
    enum class Stage : uint8_t { Aim,Swing,Gap,Return };
    Stage stage=Stage::Aim;
    double elapsed=0,angle=0,glow=0,base=0,speed=0,released_at=0;
    uint32_t cut=0;
    int32_t side=1;
    bool released=false;
    godot::Vector2 target;
};
struct CanisPounceState {uint32_t definition=0;int64_t left=1;double stage_time=0,warn_time=0;bool jumping=false,done=false;};
struct CanisSequenceItem {EnemyHandle actor;double mark=0,launch=0;bool marked=false,launched=false;};
struct CanisHowlState {bool formed=false;double last_launch=0;std::vector<CanisSequenceItem> sequence;};
struct CanisCommandState {std::vector<EnemyHandle> warned;};
struct TechniqueState {
    std::variant<std::monostate,MonocerosSweepState,MonocerosLanceState,MonocerosReturnState,MonocerosHornWaveState,MonocerosDanceState,MonocerosSwordState,CentaurusVolleyState,CentaurusRainState,CentaurusPowerState,CentaurusShowerState,CentaurusSailState,CanisCommandState,CanisHowlState,CanisPounceState> detail;
    int64_t id=0;
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
    std::unordered_map<uint64_t,double> cooldown_started;
};
enum class BossMode : uint8_t { Entrance,Idle,Phase,Final,Defeated,Cancelled };
// 単体のボスは本体が唯一の参加者。独立した護衛は敵として別に寿命を持つ。
struct ParticipantState {
    EnemyHandle actor,health_target;
    int64_t id=0;
    bool is_body=true,active=true;
};
struct CentaurusGuardState {EnemyHandle actor;double scale=1,phase=0;};
struct CentaurusBodyState {
    std::vector<CentaurusGuardState> guards;
    std::unordered_map<uint32_t,double> cooldowns;
    godot::Vector2 guard_point,leap_from,leap_to;
    bool has_guard_point=false,leaping=false;
    double guard_scan=0,guard_refill=0,path_hold=0,turn_motion=0,leap_ready_at=0,leap_elapsed=0,retreat_ready_at=0;
    int32_t path_side=1,sail_side=1;
};
struct CanisHoundRef {EnemyHandle actor;double base_hp=0;godot::Color color;};
struct CanisRingMember {EnemyHandle actor;double angle=0;};
struct CanisBodyState {
    std::vector<CanisRingMember> ring;
    godot::Vector2 ring_center;
    double ring_started=-1,ring_tick_at=0;
    uint32_t ring_definition=0;
    bool pack_spawned=false,barking=false,calling=false;
    double call_left=0,call_ready_at=0,lead_scan=0,turn_motion=0;
    std::unordered_set<int64_t> lunge_hits;
    std::vector<CanisHoundRef> led;
    std::vector<EnemyHandle> lunging;
};
struct BossBodyState {
    CanisBodyState canis;
    CentaurusBodyState centaurus;
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
    double elapsed=0;
    godot::Vector2 origin;
    std::vector<godot::Vector2> approach,replay;
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
