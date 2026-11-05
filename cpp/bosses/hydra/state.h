#pragma once
#include "../../state/boss_states.h"
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct HydraShatterStone {EnemyHandle actor;godot::Vector2 from,to;bool shattered=false;};
struct HydraShatterState {bool initialized=false;double aim=0;std::vector<HydraShatterStone> rubble;};
struct HydraTornadoState {bool initialized=false,launched=false;godot::Vector2 center,direction,from;AttackHandle vortex;std::vector<EnemyHandle> rubble;};
struct HydraCurveState {};
struct HydraSequenceState {};
struct HydraSwarmState {std::vector<godot::Vector2> slots;std::vector<bool> arrived;double position_elapsed=0;bool positioning=true;};
struct HydraNorthState {bool aiming=true,burst=false,followed=false;godot::Vector2 target;};
struct HydraPincerState {std::vector<double> aims;};
struct HydraGridPlan {uint32_t layout=0,region=0;std::vector<godot::Vector2> starts,ends,path;godot::Vector2 bearer;double length=0;};
struct HydraGridState {HydraGridPlan plan;std::vector<bool> arrived;double position_elapsed=0;bool positioning=true;};
struct HydraTechniqueState {double time=0;bool playing=false;std::vector<EnemyHandle> participants;std::variant<HydraCurveState,HydraGridState,HydraPincerState,HydraTornadoState,HydraShatterState,HydraNorthState,HydraSequenceState,HydraSwarmState> move;};
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
struct HydraBodyState {std::unordered_map<int64_t,AttackHandle> final_beams;double major_cd=0,combo_left=0,major_padding_left=0;std::unordered_map<uint32_t,double> major_until;HydraSquadState squad;DamageRequest bearer_death;HydraNeckState bearer;double separation_left=0;bool separation_pending=false,separated=false,attack_field_advance=false;double growth_left=0,chance_left=0,recovery_left=0;std::unordered_map<int64_t,uint32_t> dash_kills;std::vector<HydraNeckState> necks;};
}
