#include "enemy_motion.h"
#include "motion_math.h"
#include <algorithm>
namespace speed {
void EnemyMotion::steer(godot::RunState::Enemy &enemy,godot::Vector2 target,double speed,double accel,double dt,const TrackingPolicy &policy) {
    const auto relative=target-enemy.pos;double distance=relative.length();if (distance<0.001) distance=1;
    const auto desired=policy.velocity(enemy.vel,enemy.facing,relative/distance*speed);
    enemy.vel+=(desired-enemy.vel)*std::min(1.0,accel*dt);
}
void EnemyMotion::turn(godot::RunState::Enemy &enemy,double angle,double rate,double dt,const TrackingPolicy &policy) {
    if (policy.locked()) return;
    enemy.facing=enemy.facing+std::clamp(angle_difference(angle-enemy.facing),-rate*dt,rate*dt);
}
void EnemyMotion::keep_distance(RunRuntime &run,uint32_t row,double keep,double accel,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto aim=state.enemy_aim;
    const TrackingPolicy policy{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    const auto relative=enemy.pos-aim;double distance=relative.length();if (distance<0.001) distance=1;
    const auto unit=relative/distance;
    const auto target=aim+unit*keep+godot::Vector2(-unit.y,unit.x)*200.0*(enemy.id%2==1?1.0:-1.0);
    if (enemy.charge>0) {steer(enemy,target,enemy.speed,accel,dt,policy);turn(enemy,(aim-enemy.pos).angle(),3.0,dt,policy);return;}
    if (policy.locked()) {steer(enemy,target,enemy.speed,accel,dt,policy);return;}
    const auto delta=target-enemy.pos;distance=delta.length();if (distance<0.001) distance=1;
    enemy.vel+=(delta*(enemy.speed/distance)-enemy.vel)*std::min(1.0,accel*dt);
    const double weight=run.content->config.enemy_face_move*std::min(1.0,double(enemy.vel.length())/std::max(1.0,enemy.speed));
    const auto face=enemy.vel.normalized()*weight+(aim-enemy.pos).normalized()*(1.0-weight);
    if (face.length_squared()>0.0025) turn(enemy,face.angle(),3.0,dt,policy);
}
}
