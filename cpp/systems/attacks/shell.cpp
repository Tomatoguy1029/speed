#include "shell.h"
#include "zone.h"
#include "../attack_system.h"
#include "../attack_budget.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle ShellSystem::emit(RunRuntime &run,const ShellParams &p) {
    auto &state=run.state;if (!state.started || state.closed || !state.enemy_handles.contains(p.source) || run.content->shells.empty() || !std::isfinite(float(p.angle))) return {};
    for (double v:{p.speed,p.radius,p.range,p.burst}) if (!std::isfinite(float(v)) || v<0) return {};
    if (!std::isfinite(p.damage) || p.damage<0) return {};for (auto id:p.contents) if (!id || id>run.content->definitions.size()) return {};
    const auto &enemy=state.enemies[p.source.slot];const auto source=std::find_if(run.content->shell_sources.begin(),run.content->shell_sources.end(),[&](const auto &v){return v.enemy==uint32_t(enemy.definition+1);});if (source==run.content->shell_sources.end()) return {};
    const auto &d=run.content->shells.front();const auto u=godot::Vector2::from_angle(p.angle);godot::RunState::Hostile shot;
    shot.kind=int64_t(HostileKind::Shell);shot.pos=enemy.pos+u*(enemy.radius+p.radius);shot.vel=u*p.speed;shot.speed=p.speed;shot.radius=p.radius;shot.life=p.range/std::max(p.speed,1.0);shot.damage=p.damage;
    if (!shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.life)) return {};
    shot.shell.definition=d.id;shot.shell.burst=p.burst;shot.shell.contents=p.contents;shot.shell.full=std::clamp(double(p.contents.size())/std::max(1u,source->store_max),0.0,1.0);
    shot.shell.mouth=enemy.pos+u*(source->mouth_radius*(enemy.elite?1.25:1.0)*0.85);
    AttackSpec spec;spec.cause=Cause::Blast;spec.owner.live_source=p.source;spec.owner.budget=p.budget;
    if (!p.budget.value) spec.owner.budget.value=AttackBudgetSystem::token(state,AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group));
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;if (!AttackSystem::configure_contact(*run.content,d.contact,spec)) return {};
    const auto handle=AttackSystem::emit_hostile(state,std::move(shot),spec);
    if (AttackSystem::get(state,handle)) {godot::Dictionary event;event["pos"]=enemy.pos;event["kind"]="shell";FrameBuilder::append(run,"shoot",event);}return handle;
}
void ShellSystem::burst(RunRuntime &run,AttackHandle handle,godot::Vector2 at) {
    const auto *record=AttackSystem::get(run.state,handle);if (!record || record->pool!=AttackPool::Hostile) return;
    const auto &shot=run.state.hostiles[record->row];if (!shot.shell.definition || shot.life<=0) return;
    ZoneParams p;p.position=at;p.radius=shot.shell.burst;p.damage=shot.damage;p.style=ZoneStyle::Pump;p.color=godot::Color::html("4ee591");
    p.owner=record->spec.owner.live_source;p.budget=record->spec.owner.budget;p.source_id=record->spec.owner.source_id;p.source_definition=record->spec.owner.source_definition;ZoneSystem::emit(run,p);
}
void ShellSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &s=run.state.hostiles[row];if (!s.alive || !s.shell.definition || !view.grow(600).has_point(s.pos)) return;
    const auto *record=AttackSystem::get(run.state,s.attack);if (!record) return;const auto &d=run.content->shells[s.shell.definition-1];Dictionary shape;
    shape["kind"]=int32_t(RenderShapeKind::Shell);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;PackedVector2Array points;points.push_back(s.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(s.radius);PackedColorArray colors;colors.push_back(Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a));
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["angle"]=double(s.vel.angle());shape["clock"]=run.state.world_time;shape["flight_scale"]=d.flight_scale;shape["mouth"]=s.shell.mouth;shape["full"]=s.shell.full;
    PackedInt32Array contents;for (auto id:s.shell.contents) contents.push_back(run.content->definitions[id-1].visual_id);shape["contents"]=contents;shape["petrified_radius"]=s.stone>0?double(s.radius)*1.3:0.0;out.push_back(shape);
}
}
