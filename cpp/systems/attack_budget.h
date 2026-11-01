#pragma once
#include "../state/run_state.h"
namespace speed {
class AttackBudgetSystem {
public:
    static bool retain(godot::RunState &,BudgetToken);
    static void release(godot::RunState &,BudgetToken);
    static uint32_t retained(const godot::RunState &,BudgetToken);
};
}
