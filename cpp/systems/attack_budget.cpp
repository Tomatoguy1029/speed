#include "attack_budget.h"
namespace speed {
bool AttackBudgetSystem::retain(godot::RunState &state,BudgetToken token) {
    if (!token.value) return true;
    auto *group=state.attack_budget.groups.getptr(token.value);
    if (!group || group->residuals==UINT32_MAX) return false;
    ++group->residuals;return true;
}
void AttackBudgetSystem::release(godot::RunState &state,BudgetToken token) {
    if (auto *group=state.attack_budget.groups.getptr(token.value)) if (group->residuals) --group->residuals;
    // 枠の失効判定と通知は、今と同じdirectorの世界更新位置で行う。
}
uint32_t AttackBudgetSystem::retained(const godot::RunState &state,BudgetToken token) {
    const auto *group=state.attack_budget.groups.getptr(token.value);return group?group->residuals:0;
}
}
