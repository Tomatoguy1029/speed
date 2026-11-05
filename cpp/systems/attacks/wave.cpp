#include "wave.h"
#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../motion_math.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle WaveSystem::emit(RunRuntime &run,const WaveParams &p) {
    if ((p.technique.generation && !run.state.bosses->handles.contains(p.technique)) || !run.state.started || run.state.closed || run.content->waves.empty() || p.style>=WaveStyle::Count || !p.position.is_finite() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    for (double value:{p.arc,p.radius,p.start_radius,p.speed,p.width,p.delay,p.damage,p.gap_arc,p.enemy_damage}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.angle,p.arc,p.radius,p.start_radius,p.speed,p.width,p.delay,p.gap,p.gap_arc}) if (!std::isfinite(float(value))) return {};
    for (float value:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(value)) return {};
    HazardState h;h.pos=p.position;h.delay=p.delay;h.damage=p.damage;h.color=p.color;
    const double start=std::clamp(p.start_radius,0.0,p.radius);h.duration=(p.radius-start)/std::max(p.speed,1.0);
    if (!std::isfinite(h.duration)) return {};
    WaveHazard wave;wave.angle=p.angle;wave.arc=p.arc;wave.radius=p.radius;wave.start_radius=start;wave.speed=p.speed;
    wave.half_width=p.width*0.5;wave.gap=p.gap;wave.gap_arc=p.gap_arc;wave.enemy_damage=p.enemy_damage;wave.definition=1;wave.style=uint32_t(p.style);h.shape=wave;
    AttackSpec spec;spec.technique=p.technique;if (run.state.bosses->handles.contains(p.technique)) spec.source_technique=run.state.bosses->techniques[p.technique.slot].definition;spec.cause=Cause::Wave;spec.owner.live_source=p.owner;spec.owner.budget=p.budget;
    spec.owner.attached=p.owner.generation && p.style==WaveStyle::Pulser;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (spec.owner.attached) spec.policies|=policy(EndPolicy::CancelWithParticipant);
    if (!AttackSystem::configure_contact(*run.content,run.content->waves.front().contact,spec)) return {};
    return AttackSystem::emit_hazard(run.state,std::move(h),spec);
}
std::vector<AttackHandle> WaveSystem::emit_layers(RunRuntime &run,const WaveParams &p,uint32_t layers,double interval,double gap_step) {
    std::vector<AttackHandle> out;
    if (!std::isfinite(interval) || interval<0 || !std::isfinite(gap_step)) return out;
    for (uint32_t k=0;k<layers;++k) {
        auto layer=p;layer.angle=0;layer.arc=godot::Math::PI;layer.start_radius=0;layer.delay=p.delay+k*interval;layer.gap=p.gap+k*gap_step;
        const auto handle=emit(run,layer);if (!AttackSystem::get(run.state,handle)) break;out.push_back(handle);
    }
    return out;
}
double WaveSystem::radius(const HazardState &h) {
    const auto &w=std::get<WaveHazard>(h.shape);
    return std::min(double(w.radius),double(w.start_radius)+std::max(0.0,double(h.time)-h.delay)*w.speed);
}
ContactShape WaveSystem::geometry(const HazardState &h) {
    const auto &w=std::get<WaveHazard>(h.shape);return RingBand{h.pos,radius(h),w.half_width,w.angle,w.arc,w.gap,w.gap_arc};
}
bool WaveSystem::act(RunRuntime &run,AttackHandle handle,double dt) {
    const auto *record=AttackSystem::get(run.state,handle);if (!record) return run.state.phase==godot::RunState::Phase::Play;
    const uint32_t row=record->row;const auto h=run.state.hazards[row];const auto wave=std::get<WaveHazard>(h.shape);
    if (wave.enemy_damage<=0) return true;
    const auto &definition=run.content->waves[wave.definition-1];const double now=radius(h);
    const double before=std::min(double(wave.radius),double(wave.start_radius)+std::max(0.0,double(h.time)-dt-h.delay)*wave.speed);
    const double lo=std::max(before-wave.half_width,definition.enemy_min_distance),reach=now+wave.half_width;
    const double padding=std::max(run.state.combat_config.max_enemy_radius,run.state.grid.max_radius);
    const auto rows=CollisionQuery::enemy_rows(run.state,h.pos-godot::Vector2(reach+padding,reach+padding),h.pos+godot::Vector2(reach+padding,reach+padding));
    for (size_t enemy_row:rows) {
        const auto &enemy=run.state.enemies[enemy_row];const auto enemy_handle=run.state.enemy_handles.at(uint32_t(enemy_row));
        if (!enemy.alive || enemy.dead || run.state.field.rock_handles.contains(enemy.rock)) continue;
        auto &hits=std::get<WaveHazard>(run.state.hazards[row].shape).enemy_hits;
        if (std::find(hits.begin(),hits.end(),enemy.id)!=hits.end()) continue;
        const auto delta=enemy.pos-h.pos;const double distance=delta.length();
        if (distance+enemy.radius<lo || distance-enemy.radius>reach || std::abs(angle_difference(delta.angle()-wave.angle))>wave.arc+enemy.radius/std::max(distance,1.0)) continue;
        hits.push_back(enemy.id);
        DamageRequest request;request.struck=enemy_handle;request.amount=wave.enemy_damage;request.cause=Cause::Wave;
        request.direction=delta/std::max(distance,1.0);request.knock=definition.enemy_knock;request.no_crit=true;
        CombatResolver::damage_enemy(run,request);
        if (run.state.phase!=godot::RunState::Phase::Play) return false;
        if (!AttackSystem::get(run.state,handle)) break;
    }
    return true;
}
void WaveSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &h=run.state.hazards[row];const auto *w=std::get_if<WaveHazard>(&h.shape);if (!h.alive || !w) return;
    const bool charging=h.time<h.delay;const double r=radius(h);const bool pulser=w->style==uint32_t(WaveStyle::Pulser);
    if ((pulser && charging) || (!charging && (r<=0 || !view.grow(r+(pulser?w->half_width*4.8:0)).has_point(h.pos)))) return;
    const auto *record=AttackSystem::get(run.state,h.attack);if (!record) return;
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Wave);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    if (w->style==uint32_t(WaveStyle::Ripple)) shape["reference_dolphin"]=true;
    PackedVector2Array points;points.push_back(h.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);
    PackedFloat32Array widths;widths.push_back(w->half_width*2);PackedColorArray colors;colors.push_back(h.color);
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;
    shape["radius"]=r;shape["max_radius"]=w->radius;shape["angle"]=w->angle;shape["arc"]=w->arc;shape["gap"]=w->gap;shape["gap_arc"]=w->gap_arc;
    shape["time"]=h.time;shape["delay"]=h.delay;shape["wave_style"]=w->style;out.push_back(shape);
}
}
