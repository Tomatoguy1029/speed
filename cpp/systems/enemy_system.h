#pragma once
#include "../state/run_state.h"
namespace speed {
class EnemySystem {
public:
    static EnemyHandle insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy);
    static bool retire(godot::RunState &state,EnemyHandle enemy,RetireReason reason);
    static void leave_hound(godot::RunState &state,size_t row);
    static void release(godot::RunState &state, uint32_t slot);
};
}
