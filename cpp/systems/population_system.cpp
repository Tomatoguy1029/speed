#include "population_system.h"
#include "attack_budget.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
namespace speed {
double PopulationSystem::sample_curve(const SpawnTimeline::Curve &curve, double at) {
    const auto &points = curve.points;
    if (points.empty()) return 0;
    if (points.size() == 1 || at <= points.front().time) return points.front().value;
    if (at >= points.back().time) return points.back().value;
    size_t k = 0;
    while (k < points.size() - 2 && at > points[k + 1].time) ++k;
    const auto &p = points[k]; const auto &q = points[k + 1];
    const double h = std::max(q.time - p.time, 0.0001), s = (at - p.time) / h, s2 = s * s, s3 = s2 * s;
    return (2*s3 - 3*s2 + 1)*p.value + (s3 - 2*s2 + s)*h*p.slope + (-2*s3 + 3*s2)*q.value + (s3 - s2)*h*q.slope;
}
void PopulationSystem::prepare(RunRuntime &run) {
    const auto &cfg=run.content->population;if (!cfg.active) return;auto &s=run.state;s.spawn_timeline=run.content->population_timeline;s.spawn_timeline_ready=true;
    auto &p=s.population;p={};p.ready=p.refill_ready=true;p.frame_enabled=!run.api_development;p.recycle_scale=cfg.recycle_scale;p.region_cap=cfg.region_cap;p.margin=cfg.margin;p.field_radius=cfg.field_radius;p.planet_radius=cfg.planet_radius;p.total_cap=cfg.total_cap;p.refill_time=cfg.refill_time;
    s.formations=run.content->formations;s.formation_base_view=run.content->formation_base_view;s.clips.clear();
    for (const auto &source:run.content->population_clips) {godot::RunState::Clip clip;static_cast<PopulationClipData &>(clip)=source;s.clips.push_back(std::move(clip));}s.clips_ready=true;
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
