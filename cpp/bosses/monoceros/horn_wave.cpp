#include "horn_wave.h"
#include "charge.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
void enter(MonocerosHornWaveState &v,MonocerosHornWaveState::Stage stage) {v.stage=stage;v.elapsed=0;v.released=false;}
void release(RunRuntime &r,TechniqueState &t) {
    const auto &p=rule(r,t);const auto &e=r.state.enemies[t.actor.slot];const auto &v=std::get<MonocerosHornWaveState>(t.detail);HazardState h;h.pos=e.pos;h.damage=p.damage;h.shape=MonocerosWaveHazard{p.wave_start,p.wave_max,p.wave_speed,v.angle,p.wave_half_angle,p.wave_width};
    AttackSpec spec;spec.owner.live_source=t.actor;spec.cause=Cause::HornWave;spec.source_technique=t.definition;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBoss;spec.contact={DamageScale::AtkScale,HitPolicy::MarkBefore,true,false};
    for (uint32_t row=0;row<r.state.bosses.techniques.size();++row) if (&r.state.bosses.techniques[row]==&t) spec.technique=r.state.bosses.handles.at(row);
    for (uint32_t row=0;row<r.state.bosses.bodies.size();++row) if (same_handle(r.state.bosses.bodies[row].actor,t.actor)) spec.boss=r.state.bosses.body_handles.at(row);
    AttackSystem::emit_hazard(r.state,std::move(h),spec);godot::Dictionary event;event["pos"]=MonocerosHornWave::horn(r,t)[1];FrameBuilder::append(r,"wave_release",event);
}
}
bool MonocerosHornWave::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && r.state.enemies[actor.slot].pos.distance_to(r.state.ship_pos)<=r.content->boss_techniques[definition-1].wave_max;}
void MonocerosHornWave::begin(RunRuntime &r,TechniqueState &t) {auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*r.content->bosses[rule(r,t).boss-1].lock_lead);t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;MonocerosHornWaveState v;v.angle=e.facing;t.detail=v;}
godot::PackedVector2Array MonocerosHornWave::horn(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=r.content->bosses[p.boss-1];const auto u=godot::Vector2::from_angle(std::get<MonocerosHornWaveState>(t.detail).angle);godot::PackedVector2Array out;out.push_back(e.pos+u*e.radius*0.65);out.push_back(e.pos+u*e.radius*(p.phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio));return out;}
void MonocerosHornWave::step(RunRuntime &r,TechniqueState &t,double dt) {
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);auto &v=std::get<MonocerosHornWaveState>(t.detail);using Stage=MonocerosHornWaveState::Stage;v.elapsed+=dt;
    const auto face=[&](double turn) {if (TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) return;const auto target=p.track_during_warn?r.state.enemy_aim:t.aim;e.facing+=std::clamp(angle_difference((target-e.pos).angle()-e.facing),-turn*dt,turn*dt);};
    switch (v.stage) {
    case Stage::Windup: {face(p.windup_turn);const double k=std::clamp(v.elapsed/std::max(p.warn,0.001),0.0,1.0);v.glow=1.0-(1.0-k)*(1.0-k);v.angle=e.facing-p.pull*v.glow;if (v.elapsed>=p.warn) {t.stage=TechniqueStage::Active;enter(v,Stage::Swing);}break;}
    case Stage::Swing: {face(p.swing_turn);const double k=std::clamp(v.elapsed/std::max(p.swing_time,0.001),0.0,1.0),ease=k*k*(3.0-2.0*k);v.angle=e.facing+v.direction*(-p.pull+2.0*p.pull*ease);v.glow=1.0-ease;if (!v.released && ease>=(p.pull+p.release_offset)/std::max(2.0*p.pull,0.001)) {v.released=true;release(r,t);}if (v.elapsed>=p.swing_time) enter(v,v.direction==1?Stage::Recharge:Stage::Return);break;}
    case Stage::Recharge:v.angle=e.facing+p.pull;v.glow=std::clamp(v.elapsed/std::max(p.recharge,0.001),0.0,1.0);if (v.elapsed>=p.recharge) {v.direction=-1;enter(v,Stage::Swing);}break;
    case Stage::Return: {const double k=std::clamp(v.elapsed/std::max(p.return_time,0.001),0.0,1.0);v.angle=e.facing-p.pull*(1.0-k*k*(3.0-2.0*k));v.glow=0;if (v.elapsed>=p.return_time) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;e.vel={};}break;}
    }
}
void MonocerosHornWave::advance_waves(RunRuntime &r,double dt) {
    if (dt<=0) return;
    for (size_t row=r.state.hazards.size();row-->0;) {auto &h=r.state.hazards[row];auto *w=std::get_if<MonocerosWaveHazard>(&h.shape);if (!h.alive || !w) continue;const auto *record=AttackSystem::get(r.state,h.attack);if (!record) continue;const auto owner=record->spec.owner.live_source;
        if (!r.state.enemy_handles.contains(owner) || r.state.enemies[owner.slot].dead) {AttackSystem::end(r.state,h.attack,AttackEndReason::BossClear);continue;}
        w->radius+=w->speed*dt;const auto offset=r.state.ship_pos-h.pos;
        if (!h.hit && std::abs(offset.length()-w->radius)<=w->width*0.5+r.state.ship_config.ship_radius && std::abs(angle_difference(offset.angle()-w->angle))<=w->half_angle) {ShipDamageRequest request;request.amount=h.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::HornWave;request.source=record->spec.owner.source_definition;request.technique=record->spec.source_technique;h.hit=true;AttackSystem::mark_ship_hit(r.state,h.attack);CombatResolver::ship_damage(r,request);}
        if (w->radius>=w->maximum) AttackSystem::end(r.state,h.attack,AttackEndReason::Lifetime);
    }
}
godot::Array MonocerosHornWave::waves(const RunRuntime &r,EnemyHandle actor) {godot::Array out;for (const auto &h:r.state.hazards) {const auto *w=std::get_if<MonocerosWaveHazard>(&h.shape);if (!h.alive || !w) continue;const auto *record=AttackSystem::get(r.state,h.attack);if (!record || !same_handle(record->spec.owner.live_source,actor)) continue;godot::Dictionary item;item["id"]=record->id;item["center"]=h.pos;item["radius"]=w->radius;item["angle"]=w->angle;item["max"]=w->maximum;item["half"]=w->half_angle;item["width"]=w->width;item["hit"]=h.hit;out.push_back(item);}return out;}
bool MonocerosHornWave::validate(const TechniqueState &t) {if (!std::holds_alternative<MonocerosHornWaveState>(t.detail)) return false;const auto &v=std::get<MonocerosHornWaveState>(t.detail);return v.stage<=MonocerosHornWaveState::Stage::Return && std::isfinite(v.elapsed) && v.elapsed>=0 && std::isfinite(v.angle) && std::isfinite(v.glow) && v.glow>=0 && v.glow<=1 && (v.direction==1 || v.direction==-1);}
}
