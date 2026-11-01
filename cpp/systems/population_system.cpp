#include "population_system.h"
#include "attack_budget.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
namespace speed {
void PopulationSystem::sync_attack_budget(RunRuntime &run) {
    auto &state=run.state;auto &budget=state.world.attack_budget;
    if (!budget.stage_budget) return;
    double capacity=0;
    if (!run.content->budget_phases.empty()) {
        const auto &phases=run.content->budget_phases;size_t phase=0;
        for (size_t i=1;i<phases.size();++i) {if (phases[i].start>state.time) break;phase=i;}
        capacity=phases[phase].budget;
    } else {
        // 旧比較入口はZ1で撤去する。同じ更新時点で同じ値を適用する。
        const auto &phases=state.spawn_timeline.phases;if (phases.empty()) return;
        size_t phase=0;for (size_t i=1;i<phases.size();++i) {if (phases[i].start>state.time) break;phase=i;}
        capacity=std::max(int64_t(0),phases[phase].budget);
    }
    AttackBudgetSystem::apply_stage_budget(state,capacity);
}
}
