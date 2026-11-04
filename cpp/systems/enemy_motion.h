#pragma once
#include "../runtime/run_runtime.h"
#include "tracking_policy.h"
namespace speed {
class EnemyMotion {
public:
    static void steer(godot::RunState::Enemy &,godot::Vector2,double speed,double accel,double dt,const TrackingPolicy &);
    static void turn(godot::RunState::Enemy &,double angle,double rate,double dt,const TrackingPolicy &);
    static void keep_distance(RunRuntime &,uint32_t row,double keep,double accel,double dt);
};
}
