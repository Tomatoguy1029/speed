#pragma once
#include "../../runtime/run_runtime.h"
#include <optional>
namespace speed {
struct BulletValues {std::optional<double> damage,slow,turn;};
class BulletSystem {
public:
    static void petrify(godot::RunState &,godot::Rect2 view,double duration);
    static AttackHandle fire_enemy(RunRuntime &,EnemyHandle,double angle,double speed,const BulletValues &values={});
};
}
