#pragma once
#include "../../runtime/run_runtime.h"
#include <optional>
namespace speed {
struct BulletSpawn {EnemyHandle source;uint32_t definition=0;godot::Vector2 position,velocity;double speed=0,radius=0,life=0,damage=0,wait=0;BudgetToken budget;};
struct BulletValues {std::optional<double> damage,slow,turn;};
class BulletSystem {
public:
    static AttackHandle emit(RunRuntime &,const BulletSpawn &);
    static void petrify(godot::RunState &,godot::Rect2 view,double duration);
    static AttackHandle fire_kind(RunRuntime &,HostileKind,EnemyHandle,double angle,double speed,const BulletValues &values={});
    static AttackHandle fire_enemy(RunRuntime &,EnemyHandle,double angle,double speed,const BulletValues &values={});
};
}
