#include "gemini.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/heroes.h"
#include "../../systems/combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
bool GeminiBehavior::capture_first(RunRuntime &r) {
    auto &s=r.state;auto &t=s.heroes.twin;
    if (s.heroes.active<=0 || !t.first.empty() || std::none_of(r.content->gemini.begin(),r.content->gemini.end(),[&](const auto &d){return d.hero==s.heroes.power;})) return false;
    s.draw.gauge=std::max(0.0,s.draw.gauge-s.draw.start_charge*std::min(1.0,s.draw.length/s.draw.limit));
    for (int64_t i=0;i<s.draw.points.size();++i) t.first.push_back(s.draw.points[i]);
    s.draw.points.clear();s.draw.length=0;s.draw.started=s.draw.blocked=false;FrameBuilder::append(r,"twin_first",{});return true;
}
bool GeminiBehavior::swap_paths(RunRuntime &r) {
    auto &s=r.state;auto &t=s.heroes.twin;if (t.first.empty()) return false;
    t.path.clear();for (int64_t i=0;i<s.draw.points.size();++i) t.path.push_back(s.draw.points[i]);
    s.draw.points.clear();for (auto p:t.first) s.draw.points.push_back(p);t.first.clear();return true;
}
void GeminiBehavior::launch(RunRuntime &r) {auto &t=r.state.heroes.twin;t.position=t.path.front();t.rate=r.state.draw.rate;t.segment=0;t.segment_position=0;t.inside.clear();t.tracing=true;}
namespace {
void sweep(RunRuntime &r,godot::Vector2 from,godot::Vector2 to) {
    auto &s=r.state;auto &t=s.heroes.twin;const double radius=s.trace_radius*HeroesSystem::trace_width(r),padding=radius+std::max(s.combat_config.max_enemy_radius,s.grid.max_radius),power=CombatResolver::attack_power(r);const godot::Vector2 pad(padding,padding),direction=(to-from).normalized();
    for (auto row:CollisionQuery::enemy_rows(s,from.min(to)-pad,from.max(to)+pad)) {
        const auto &e=s.enemies[row];if (e.dead || s.field.rock_handles.contains(e.rock)) continue;const auto target=CombatResolver::damage_target(r,s.enemy_handles.at(row));if (!s.enemy_handles.contains(target)) continue;
        const auto id=s.enemy_handles.entity_id(target);if (t.inside.count(id) || CollisionQuery::segment_circle_t(from,to,e.pos,e.radius+radius)<0) continue;t.inside.insert(id);
        DamageRequest request;request.struck=s.enemy_handles.at(row);request.amount=power;request.cause=Cause::Ram;request.direction=direction;request.impact=to;request.has_impact=true;
        if (e.stone>0) CombatResolver::kill_enemy(r,request);
        else if (CombatResolver::gate(r,request.struck,request)==GateResult::Allow && (s.loadout->effects.ignore_armor || HeroesSystem::trace_width(r)>1 || power>=e.armor)) {request.impact=e.pos;CombatResolver::damage_enemy(r,request);}
        if (s.phase!=godot::RunState::Phase::Play) return;
    }
}
}
void GeminiBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &t=s.heroes.twin;if (!t.tracing || s.phase!=godot::RunState::Phase::Play) return;double distance=t.rate*dt;
    while (distance>1e-9 && t.segment<t.path.size()-1) {
        const auto a=t.path[t.segment],b=t.path[t.segment+1];const double length=a.distance_to(b),move=std::min(distance,length-t.segment_position);const auto from=t.position;
        t.segment_position+=move;distance-=move;t.position=a+(b-a)/std::max(length,1e-6)*t.segment_position;sweep(r,from,t.position);
        if (s.phase!=godot::RunState::Phase::Play) return;
        if (t.segment_position>=length-1e-9) {++t.segment;t.segment_position=0;}
    }
    if (t.segment>=t.path.size()-1) {t.tracing=false;t.path.clear();t.inside.clear();t.segment=0;t.segment_position=t.rate=0;}
}
}
