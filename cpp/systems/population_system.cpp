#include "population_system.h"
#include "attack_budget.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
namespace speed {
void PopulationSystem::prepare(RunRuntime &run) {
    const auto &cfg=run.content->population;if (!cfg.active) return;auto &s=run.state;s.spawn_timeline=run.content->population_timeline;s.spawn_timeline_ready=true;
    auto &p=s.population;p={};p.ready=p.refill_ready=true;p.frame_enabled=!run.api_development;p.recycle_scale=cfg.recycle_scale;p.region_cap=cfg.region_cap;p.margin=cfg.margin;p.field_radius=cfg.field_radius;p.planet_radius=cfg.planet_radius;p.total_cap=cfg.total_cap;p.refill_time=cfg.refill_time;
    const size_t count=run.content->definitions.size();p.maximum.resize(count);p.type_counts.resize(count);p.effective.resize(count);p.region_types.resize(count*5);
    for (size_t i=0;i<count;++i) {const auto &id=run.content->definitions[i].id;const auto found=std::find_if(s.spawn_timeline.types.begin(),s.spawn_timeline.types.end(),[&](const auto &type){return type.id==id;});p.maximum[i]=found->maximum;}
}
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
