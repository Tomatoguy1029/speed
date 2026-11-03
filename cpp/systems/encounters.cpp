#include "encounters.h"
#include "route_constraints.h"
#include "enemy_system.h"
#include "attack_budget.h"
#include "field.h"
#include "combat_resolver.h"
#include "../runtime/run_runtime.h"
#include "../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
struct Candidate {uint32_t definition=0;godot::Vector2 position;double facing=0;bool fodder=false,elite=false;};
bool admit(const RunRuntime &run,const EncounterPatternData &p,const std::vector<godot::Vector2> &path,const std::vector<Candidate> &candidates,double sweep_radius) {
    uint32_t fodder=0;std::vector<godot::Vector2> positions;const auto &s=run.state;
    for (const auto &item:candidates) {
        if (!item.definition || item.elite) return false;const auto &d=run.content->definitions[item.definition-1];
        if (d.kind==EnemyDefinition::Kind::Meteor || d.kind==EnemyDefinition::Kind::Saw || d.kind==EnemyDefinition::Kind::Obstacle || d.kind==EnemyDefinition::Kind::Part) return false;
        for (auto pos:positions) if (pos.distance_to(item.position)<p.min_spacing) return false;positions.push_back(item.position);
        const double radius=d.scaling.radius*d.scaling.character+sweep_radius;
        const double attack=CombatResolver::attack_power(run);const bool can_kill=d.gate==EnemyDefinition::Gate::None && d.hp<=attack && d.armor<=attack;
        const bool simple=d.kind==EnemyDefinition::Kind::Drift || d.kind==EnemyDefinition::Kind::Chase;
        if (p.window>0 && (d.speed>0 || !simple || d.death_chain_definition || d.split_definition || (d.drift_definition && run.content->drifts[d.drift_definition-1].has_life))) return false;
        if (item.position.length()+radius>=s.ship_config.field_radius || FieldSystem::body_gap(run,item.position,radius)<=0) return false;
        const double near=std::min(RouteConstraints::distance(item.position,path),double(item.position.distance_to(path.back()))-p.exit_clearance);
        if (near<=radius) {if (!can_kill || !item.fodder) return false;++fodder;}
    }
    return fodder>=p.min_fodder;
}
}
bool EncounterSystem::advance(RunRuntime &run) {
    auto &s=run.state;const auto &content=*run.content;auto &state=s.encounter;
    if (!content.encounter.active || AttackBudgetSystem::guard_active(s) || s.world_time<state.next) return true;
    state.next=s.world_time+std::max(0.5,content.encounter.interval);
    if (!content.encounter_phases.empty()) {
        const auto &phases=s.spawn_timeline.phases;if (phases.empty()) return true;size_t phase=0;for (size_t i=1;i<phases.size();++i) {if (phases[i].start>s.time) break;phase=i;}
        if (std::find(content.encounter_phases.begin(),content.encounter_phases.end(),phases[phase].id)==content.encounter_phases.end()) return true;
    }
    if (content.encounter_patterns.empty()) return true;
    auto &rng=s.control.rng;const auto index=rng.randi_range(0,int64_t(content.encounter_patterns.size()-1));if (!index) return false;const auto &p=content.encounter_patterns[size_t(*index)];
    for (uint32_t attempt=0;attempt<p.attempts;++attempt) {
        const double angle=rng.randf_range(-p.rotation,p.rotation),scale=rng.randf_range(p.scale_min,p.scale_max);
        std::vector<godot::Vector2> path;for (auto point:p.route) path.push_back(s.view_center+point.rotated(angle)*scale);
        std::vector<Candidate> candidates;
        for (const auto &region:p.regions) {
            const auto count=rng.randi_range(region.min_count,region.max_count);if (!count) return false;
            for (int64_t k=0;k<*count;++k) {const double jitter_angle=rng.randf()*godot::Math::TAU,jitter_root=std::sqrt(rng.randf());const auto offset=(godot::Vector2::from_angle(jitter_angle)*jitter_root)*region.jitter;const auto pos=s.view_center+(region.position+offset).rotated(angle)*scale;candidates.push_back({region.enemy,pos,region.angle+angle,region.fodder,region.elite});}
        }
        if (path.size()<2) continue;
        RouteOptions options;options.margin=p.margin;options.window=p.window;options.draw_seconds=p.draw_seconds;options.exit_clearance=p.exit_clearance;
        auto context=RouteConstraints::context(run);
        // 成立後の既存guardが補充を止める。通常の経路問い合わせでは自動補充を未対応として返す。
        context.auto_spawn=false;
        const auto validation=RouteConstraints::validate(context,path,options);
        if (!validation.valid || !admit(run,p,path,candidates,validation.radius)) continue;
        for (const auto &candidate:candidates) {EnemySpawn params;params.origin=SpawnOrigin::Summon;params.position=candidate.position;params.facing=candidate.facing;params.has_facing=true;if (EnemySystem::spawn(run,candidate.definition-1,params)<0) return false;}
        state.opportunity=true;state.route=path;state.start=s.world_time;state.window=p.window;state.margin=p.margin;
        if (p.window>0) AttackBudgetSystem::set_guard(s,true,s.world_time+p.window);
        godot::Dictionary event;godot::PackedVector2Array points;for (auto point:path) points.push_back(point);event["route"]=points;event["status"]=p.window>0?"window":"static";event["start"]=state.start;event["window"]=state.window;event["margin"]=state.margin;FrameBuilder::append(run,"route_opportunity",event);return true;
    }
    godot::Dictionary event;event["reason"]=godot::String::utf8("条件に合う配置を見つけられませんでした。");FrameBuilder::append(run,"encounter_deferred",event);return true;
}
}
