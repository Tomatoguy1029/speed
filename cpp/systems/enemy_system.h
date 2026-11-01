#pragma once
#include "../state/run_state.h"
namespace speed {
class EnemySystem {
public:
    static EnemyHandle insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy);
    static void release(godot::RunState &state, uint32_t slot);
    static void aim_chase(godot::RunState::Enemy &enemy, godot::Vector2 ship);
};
}
