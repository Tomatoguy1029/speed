#pragma once
#include "../../state/run_state.h"
#include "../../systems/tracking_policy.h"
namespace speed {
class PursuitBehavior {
public:
    static void turn(godot::RunState::Enemy &enemy,double angle,double rate,double dt,const TrackingPolicy &policy);
    static godot::Vector2 velocity(godot::RunState::Enemy &enemy,godot::Vector2 target,double rate,double dt,const TrackingPolicy &policy);
};
}
