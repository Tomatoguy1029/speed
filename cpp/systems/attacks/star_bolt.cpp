#include "star_bolt.h"
#include "../attack_system.h"
#include "../../output/render_builder.h"
#include <cmath>
namespace speed {
AttackHandle StarBoltSystem::emit(RunRuntime &run,const StarBoltParams &p) {
    if (!run.state.started || run.state.closed || run.content->star_bolts.empty() || !p.position.is_finite() || !std::isfinite(p.angle) ||
        !std::isfinite(float(p.speed)) || p.speed<0 || !std::isfinite(p.damage) || p.damage<0 || (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    if (p.definition>run.content->star_bolts.size()) return {};const uint32_t definition=p.definition?p.definition:1;const auto &d=run.content->star_bolts[definition-1];godot::RunState::Hostile shot;shot.kind=int64_t(HostileKind::StarBolt);shot.star_bolt.definition=definition;
    shot.pos=p.position;shot.vel=godot::Vector2::from_angle(p.angle)*p.speed;shot.speed=p.speed;shot.radius=d.radius;shot.life=d.life;shot.damage=p.damage;
    AttackSpec spec;spec.cause=Cause::StarBolt;spec.technique=p.technique;if (run.state.bosses.handles.contains(p.technique)) spec.source_technique=run.state.bosses.techniques[p.technique.slot].definition;spec.owner.live_source=p.owner;spec.owner.budget=p.budget;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (!AttackSystem::configure_contact(*run.content,d.contact,spec)) return {};
    return AttackSystem::emit_hostile(run.state,shot,spec);
}
void StarBoltSystem::render(const RunRuntime &run,uint32_t row,RenderBatchBuffer &stars,RenderBatchBuffer &stone) {
    const auto &s=run.state.hostiles[row];const auto *record=AttackSystem::get(run.state,s.attack);if (!record) return;
    const auto &d=run.content->star_bolts[s.star_bolt.definition-1];
    stars.add(record->id,s.pos,d.turn_with_velocity?s.vel.angle():0,d.flight_scale,godot::Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a));
    if (s.stone>0) stone.add(record->id,s.pos,0,s.radius*1.3,godot::Color(0.62,0.6,0.58,0.9));
}
}
