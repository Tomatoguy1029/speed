#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class ShieldBehavior {
public:
    static void step(RunRuntime &,uint32_t row,double dt);
    static bool blocks_front(const RunRuntime &,EnemyHandle,godot::Vector2 impact,godot::Vector2 direction);
    static bool rear_open(const RunRuntime &,EnemyHandle,godot::Vector2 impact);
    static void steal(RunRuntime &,EnemyHandle);
};
}
