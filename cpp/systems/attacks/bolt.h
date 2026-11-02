#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct BoltParams {
    godot::Vector2 position;
    double angle=0,speed=0,damage=0;
    EnemyHandle owner;
    BudgetToken budget;
};
class BoltSystem {
public:
    static AttackHandle emit(RunRuntime &,const BoltParams &);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
