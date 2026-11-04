#include "blast.h"
#include "../attack_system.h"
#include "../../state/boss_states.h"
#include <cmath>
#include <algorithm>
namespace speed {
AttackHandle BlastSystem::emit(RunRuntime &run,const BlastParams &p) {
    auto &state=run.state;
    if ((p.technique.generation && !state.bosses->handles.contains(p.technique)) || p.source_id<0 || p.source_definition>run.content->definitions.size() || !state.started || state.closed || !p.position.is_finite() || (p.source.generation && !state.enemy_handles.contains(p.source)) || p.duration<=0) return {};
    for (double value:{p.radius,p.damage,p.duration,p.delay}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.radius,p.duration,p.delay}) if (!std::isfinite(float(value))) return {};
    for (float channel:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(channel)) return {};
    HazardState hazard;hazard.pos=p.position;hazard.shape=CircleHazard{float(p.radius),CircleHazardKind::Blast};
    hazard.delay=p.delay;hazard.duration=p.duration;hazard.damage=p.damage;hazard.color=p.color;
    AttackSpec spec;spec.technique=p.technique;if (state.bosses->handles.contains(p.technique)) spec.source_technique=state.bosses->techniques[p.technique.slot].definition;spec.cause=Cause::Blast;spec.owner.live_source=p.source;spec.owner.attached=p.attached && p.source.generation>0;spec.owner.budget=p.budget;spec.owner.source_id=p.source_id;spec.owner.source_definition=p.source_definition;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (spec.owner.attached) spec.policies|=policy(EndPolicy::CancelWithParticipant);
    if (!AttackSystem::configure_contact(*run.content,p.contact,spec)) return {};
    return AttackSystem::emit_hazard(state,hazard,spec);
}
void BlastSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &shapes) {
    using namespace godot;
    const auto &hazard=run.state.hazards[row];const auto *circle=std::get_if<CircleHazard>(&hazard.shape);
    if (!hazard.alive || hazard.zone_definition || !circle || circle->kind!=CircleHazardKind::Blast || !view.grow(circle->radius).has_point(hazard.pos)) return;
    const auto *record=AttackSystem::get(run.state,hazard.attack);if (!record) return;
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Blast);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;points.push_back(hazard.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);
    PackedFloat32Array widths;widths.push_back(circle->radius);auto color=hazard.color;color.a=1.0-std::clamp(double(hazard.time)/std::max(0.001,double(hazard.duration)),0.0,1.0);
    PackedColorArray colors;colors.push_back(color);shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shapes.push_back(shape);
}
}
