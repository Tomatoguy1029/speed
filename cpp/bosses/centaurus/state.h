#pragma once
#include "../../state/boss_states.h"
#include "image_pose_state.h"
#include "reference_fx_state.h"
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct CentaurusShowerMark {godot::Vector2 center;double at=0;bool shown=false,landed=false;};
struct CentaurusShowerState {std::vector<CentaurusShowerMark> marks;uint32_t placed=0;bool launched=false;};
struct CentaurusRainTrace {godot::Vector2 start,direction;double started=0,next_drop=0,landed=0;int32_t turn=1;bool hit=false;};
struct CentaurusRainState {std::vector<CentaurusRainTrace> traces;uint32_t left=0;double next_at=0,expire_at=0;};
struct CentaurusPowerState {godot::Vector2 origin;double angle=0;uint32_t released=0;bool alerting=false;};
struct CentaurusSailState {godot::Vector2 center;double radius=0,angle=0;int32_t side=1;uint32_t fired=0;bool boosted=false;};
struct CentaurusVolleyState {uint32_t released=0;};
struct CentaurusGuardState {EnemyHandle actor;double scale=1,phase=0;};
struct CentaurusBodyState {
    CentaurusReferenceFxState reference_fx;
    CentaurusImagePoseClock image_pose;
    std::vector<CentaurusGuardState> guards;
    std::unordered_map<uint32_t,double> cooldowns;
    godot::Vector2 guard_point,leap_from,leap_to;
    bool has_guard_point=false,leaping=false;
    double guard_scan=0,guard_refill=0,path_hold=0,turn_motion=0,leap_ready_at=0,leap_elapsed=0,retreat_ready_at=0;
    int32_t path_side=1,sail_side=1;
};
}
