#pragma once
#include "../state/run_state.h"
namespace speed {
class RunRuntime;
class EnemySystem {
public:
    static bool relocate(RunRuntime &,EnemyHandle,godot::Vector2);
    static bool attack_active(const godot::RunState &,EnemyHandle);
    static bool attack_due(const RunRuntime &,EnemyHandle,double dt);
    static EnemyHandle insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy);
    static bool retire(godot::RunState &state,EnemyHandle enemy,RetireReason reason);
    static void leave_hound(godot::RunState &state,size_t row);
    static void release(godot::RunState &state, uint32_t slot);
};
}
