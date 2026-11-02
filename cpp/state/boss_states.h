#pragma once
#include "entity_store.h"
#include "combat_types.h"
#include "../content/generated/combat_ids.h"
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
struct CanisSiriusState {uint32_t shot=0;double age=0,gap_left=0;bool fired=false;};
struct CanisPounceState {uint32_t definition=0;int64_t left=1;double stage_time=0,warn_time=0;bool jumping=false,done=false;};
struct CanisBayMember {EnemyHandle actor;double angle=0,phase=0,cool=0,bark=0,warn=-1;AttackHandle lunge;bool nipping=false;};
struct CanisBayState {std::vector<CanisBayMember> members;CanisPounceState jump;double heading=0;bool jumping=false;};
struct CanisBlazeChosen {EnemyHandle actor;double at=0;bool sent=false,lit=false;};
struct CanisBlazeState {std::vector<CanisBlazeChosen> chosen;double age=0;};
struct CanisSequenceItem {EnemyHandle actor;double mark=0,launch=0;bool marked=false,launched=false;};
struct CanisHowlState {bool formed=false;double last_launch=0;std::vector<CanisSequenceItem> sequence;};
struct CanisCommandState {std::vector<EnemyHandle> warned;};
struct CanisStreamState {uint32_t definition=0;bool sent=false;double started=0,last_launch=0;std::vector<CanisSequenceItem> sequence;};
struct CanisFlameAimState {double age=0;bool fired=false,done=false;};
struct CanisHuntState {CanisStreamState stream;CanisFlameAimState aim;bool aiming=false,combo_pending=true;};
struct CanisHuntPounceState {CanisStreamState stream;CanisPounceState jump;bool jumping=false,combo_pending=true;};
struct CanisNovaPair {EnemyHandle actor;uint32_t group=0;double angle=0,side=1;bool stationed=false;};
struct CanisNovaShadow {double angle=0,half=0,near=0;};
struct CanisNovaState {double started=0;std::vector<CanisNovaPair> pairs;std::vector<CanisNovaShadow> shadows;std::vector<bool> ring_hit;bool flashed=false,released=false;};
struct CanisRelayItem {EnemyHandle actor;double at=0,angle=0;godot::Vector2 from;bool marked=false,fired=false,released=false;};
struct CanisRelayState {CanisFlameAimState aim;double started=0,last_fire=0,tint_until=0;std::vector<CanisRelayItem> items;bool ordered=false,aiming=false,cancelled=false;};
struct DracoBiteState {godot::Vector2 origin,retracted,strike;std::vector<godot::Vector2> base,landed;};
struct DracoBreathState {std::vector<RockHandle> rocks;std::vector<godot::Vector2> destinations,base,recovering;godot::Vector2 mouth;double axis=0,fan_angle=0;bool reused=false;};
struct DracoStagingState {uint8_t phase=0;bool enter=false;double side=1,height=0,exit_angle=0,away_angle=0,exit_time=0,entry_time=0;godot::Vector2 entry_from,entry_to;std::vector<godot::Vector2> trail,points;};
struct DracoChargeState {DracoStagingState staging;godot::Vector2 origin,destination,settled;bool positioned=false;};
struct DracoLeapState {DracoStagingState staging;godot::Vector2 origin,destination,takeoff,landed;bool positioned=false;};
struct DracoTailSlamState {godot::Vector2 origin,target;std::vector<godot::Vector2> base,lifted,last;bool fired=false;};
struct DracoTailSweepState {godot::Vector2 origin;double facing=0;std::vector<godot::Vector2> base,last,prior,area;};
struct DracoStarFanState {std::vector<godot::Vector2> positions;std::vector<double> angles;bool fired=false;};
struct DracoRiftsState {DracoStagingState staging;std::vector<std::vector<godot::Vector2>> paths;std::vector<AttackHandle> walls,slashes;godot::Vector2 center;uint32_t claws=3,sides=0;bool ended=false;};
struct DracoTechniqueState {double stage_time=0;std::vector<godot::Vector2> warning,attack;double warning_width=0,attack_width=0;std::vector<std::vector<godot::Vector2>> warning_paths;std::variant<DracoBiteState,DracoBreathState,DracoChargeState,DracoLeapState,DracoTailSlamState,DracoTailSweepState,DracoStarFanState,DracoRiftsState> move;};
struct CanisSiriusFlameState {double age=0,emit_left=0;bool started=false;};
struct HydraTornadoState {bool initialized=false,launched=false;godot::Vector2 center,direction,from;AttackHandle vortex;std::vector<EnemyHandle> rubble;};
struct HydraCurveState {};
struct HydraPincerState {std::vector<double> aims;};
struct HydraGridPlan {uint32_t layout=0,region=0;std::vector<godot::Vector2> starts,ends,path;godot::Vector2 bearer;double length=0;};
struct HydraGridState {HydraGridPlan plan;std::vector<bool> arrived;double position_elapsed=0;bool positioning=true;};
struct HydraTechniqueState {double time=0;bool playing=false;std::vector<EnemyHandle> participants;std::variant<HydraCurveState,HydraGridState,HydraPincerState,HydraTornadoState> move;};
struct TechniqueState {
    std::variant<std::monostate,MonocerosSweepState,MonocerosLanceState,MonocerosReturnState,MonocerosHornWaveState,MonocerosDanceState,MonocerosSwordState,CentaurusVolleyState,CentaurusRainState,CentaurusPowerState,CentaurusShowerState,CentaurusSailState,CanisCommandState,CanisHowlState,CanisPounceState,CanisSiriusState,CanisBayState,CanisBlazeState,CanisStreamState,CanisHuntState,CanisHuntPounceState,CanisNovaState,CanisRelayState,DracoTechniqueState,CanisSiriusFlameState,HydraTechniqueState> detail;
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
struct CanisBurningHound {EnemyHandle actor;uint32_t definition=0,technique=0;double base_hp=0,age=0,blink_age=-1;godot::Color color;};
struct CanisBodyState {
    TechniqueHandle nova;
    std::vector<CanisBurningHound> burning;
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
struct DracoPicaroMember {
    EnemyHandle actor;
    std::vector<EnemyHandle> parts,clone_parts;
    double born=0,angle=0;
    uint32_t stars=1;
};
struct DracoCinematicState {
    bool saved=false,controls_locked=false,protected_ship=false,camera=false,hide=false;
    double bars=0,zoom=1,world_scale=1;
    godot::Vector2 center,half,heading;
};
struct DracoIntroState {
    struct Held {EnemyHandle actor;bool held=false;};
    DracoCinematicState saved;
    std::vector<Held> held;
    bool active=false;
    uint8_t stage=0;
    double time=0,rift=0,eyes=0,chest=0,emerged=0,zoom=1,facing=0,guard=0;
    BossMode mode=BossMode::Idle;
    godot::Vector2 origin,ship,camera,center,rift_center;
};
enum class DracoCycleStage : uint8_t { None,Roar,Collect,WaitBeams,Return,Generate };
struct DracoCycleState {
    DracoCinematicState saved;
    DracoCycleStage stage=DracoCycleStage::None;
    bool first=false;
    uint32_t generated=0;
    double time=0,next_cycle=12,zoom=1,return_depth=1,return_alpha=1,return_angle=0;
    godot::Vector2 home,from,return_from;
};
struct DracoImpact {godot::Vector2 position;double time=0,radius=0;uint32_t technique=0;};
struct DracoClosingWall {AttackHandle attack;godot::Vector2 from;double time=0.3,duration=0.3,delay=0,length=0,half_width=0,angle=0;};
struct DracoBodyState {
    std::vector<DracoClosingWall> closing_walls;
    std::vector<RockHandle> placed_meteors;
    std::vector<DracoImpact> impacts;
    DracoCycleState cycle;
    DracoIntroState intro;
    std::vector<DracoPicaroMember> picaro;
    std::vector<EnemyHandle> picaro_pending;
    bool picaro_attacking=true;
    std::vector<godot::Vector2> trail,pose,override_points;
    double width=154,head_scale=1.35,depth=1,alpha=1;
};
enum class HydraSquadRole : uint32_t {Close,Front,Attack,Block,Bearer};
struct HydraSquadMotion {
    bool attack=false,front=false,counter=false,ready=false,has_goal=false,look_on=true;
    int32_t block=-1,slot=0,slot_count=1;
    uint32_t move=0;
    double reserved=0,attack_angle=0,wait=0,last_attack=-9,close_angle=0,close_radius=0,detour_side=0,look_time=0,look_offset=0;
    godot::Vector2 goal,block_target,separation;
};
struct HydraSquadState {
    godot::Vector2 predicted,bearer_goal;
    double replan_time=0,formation_angle=0,reorient_time=0,bearer_replan=0,panic=0,panic_cooldown=0,tactic_time=0,attack_gap=1,pair_elapsed=0,wave_angle=0,wave_gap=0.6,counter_time=0;
    bool chasing=false,pair_launched=false,has_wave_angle=false,suspended=false;
    int32_t tactic=-1,section_index=-1;
    EnemyHandle wave_current;
    std::vector<EnemyHandle> roster,pair;
};
struct HydraNeckState {
    HydraSquadMotion motion;
    HydraHeadKind kind=HydraHeadKind::Bite;
    EnemyHandle actor;
    int64_t id=0;
    double base_angle=0,angle=0,length=0,head_hp=0,cd=0,aim_wait=0,aim_velocity=0;
    bool has_aim=false,burned=false;
    double regrow=0;
    godot::Vector2 aim_target,free_pos,velocity,strike_from,strike_pos,target;
    double look_angle=0,elapsed=0,glow=0,turn=0,hit_left=0,sweep=0;
    AttackHandle emission;
    uint32_t normal=0,normal_phase=0,step=0,major=0;
    bool locked=false,extension=false,lunge_done=false;
    std::vector<godot::Vector2> trail;
    double weights[6]={};
    std::vector<godot::Vector2> points;
};
struct HydraBodyState {double major_cd=0,combo_left=0,major_padding_left=0;std::unordered_map<uint32_t,double> major_until;HydraSquadState squad;DamageRequest bearer_death;HydraNeckState bearer;double separation_left=0;bool separation_pending=false,separated=false,attack_field_advance=false;double growth_left=0,chance_left=0,recovery_left=0;std::unordered_map<int64_t,uint32_t> dash_kills;std::vector<HydraNeckState> necks;};
struct BossBodyState {
    HydraBodyState hydra;
    DracoBodyState draco;
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
