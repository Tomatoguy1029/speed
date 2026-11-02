#include "missile.h"
#include "../motion_math.h"
#include <algorithm>
namespace speed {
AttackHandle MissileSystem::fire_enemy(RunRuntime &run,EnemyHandle source,double angle,double speed,const BulletValues &values) {
    return BulletSystem::fire_kind(run,HostileKind::Missile,source,angle,speed,values);
}
godot::Vector2 MissileSystem::steer(const RunRuntime &run,const godot::RunState::Hostile &shot,godot::Vector2 velocity,double dt) {
    const auto aim=run.state.aim_ready?run.state.enemy_aim:run.state.ship_pos;
    const double current=velocity.angle(),turn=double(shot.turn)*dt;
    const double difference=angle_difference(double((aim-shot.pos).angle())-current);
    return godot::Vector2::from_angle(current+std::clamp(difference,-turn,turn))*shot.speed;
}
}
