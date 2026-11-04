#pragma once
#include "bullet.h"
namespace speed {
class MissileSystem {
public:
    static AttackHandle fire_enemy(RunRuntime &,EnemyHandle,double angle,double speed,const BulletValues &values={});
    static godot::Vector2 steer(const RunRuntime &,const godot::RunState::Hostile &,godot::Vector2 velocity,double dt);
};
}
