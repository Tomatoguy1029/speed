#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct BlastParams {
    godot::Vector2 position;
    godot::Color color;
    EnemyHandle source;
    BudgetToken budget;
    double radius=0,damage=0,duration=0;
    uint32_t contact=0;
};
class BlastSystem {
public:
    static AttackHandle emit(RunRuntime &,const BlastParams &);
    static void render(const RunRuntime &,uint32_t row,godot::Rect2 view,godot::Array &shapes);
};
}
