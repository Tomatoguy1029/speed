#include "pursuit.h"
#include "../../systems/motion_math.h"
#include <algorithm>
namespace speed {
void PursuitBehavior::turn(godot::RunState::Enemy &enemy,double angle,double rate,double dt,const TrackingPolicy &policy) {
    if (policy.locked()) return;
    const double difference=angle_difference(angle-enemy.facing),limit=rate*dt;
    enemy.facing+=std::clamp(difference,-limit,limit);
}
godot::Vector2 PursuitBehavior::velocity(godot::RunState::Enemy &enemy,godot::Vector2 target,double rate,double dt,const TrackingPolicy &policy) {
    const auto distance=target-enemy.pos;
    if (distance.length_squared()<0.000001) return {};
    turn(enemy,distance.angle(),rate,dt,policy);
    return godot::Vector2::from_angle(enemy.facing)*enemy.speed;
}
}
