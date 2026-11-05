#include "flames.h"
#include "fire_visual.h"
#include "image_pose.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/field.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
using Kind=CanisFlameHazard::Kind;
AttackSpec spec(const RunRuntime &r,const BossBodyState &b,uint32_t observation,Cause cause) {AttackSpec s;s.owner.live_source=b.actor;s.boss=r.state.bosses->body_handles.at(uint32_t(&b-r.state.bosses->bodies.data()));s.source_technique=observation;for (const auto &t:r.state.bosses->techniques) if (same_handle(t.actor,b.actor) && t.definition==observation && t.stage<TechniqueStage::Finished) {s.observation_id=t.observation_id;break;}s.cause=cause;s.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBoss;s.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,false};return s;}
double distance(godot::Vector2 p,godot::Vector2 a,godot::Vector2 b) {const auto delta=b-a;const double t=delta.length_squared()>0?std::clamp(double((p-a).dot(delta))/delta.length_squared(),0.0,1.0):0;return p.distance_to(a+delta*t);}
CanisFlameHazard *detail(godot::RunState &s,AttackHandle h) {const auto *a=AttackSystem::get(s,h);return a && a->pool==AttackPool::Hazard?std::get_if<CanisFlameHazard>(&s.hazards[a->row].shape):nullptr;}
AttackHandle particle(RunRuntime &r,const HazardState &parent,const AttackSpec &owner,AttackHandle jet,bool harmful=true,double clock=0) {
    const auto &source=std::get<CanisFlameHazard>(parent.shape);const auto &p=r.content->canis_flames[source.definition-1];const bool beam=bool(jet.generation);
    const auto *fx=CanisFireVisualSystem::settings(*r.content,owner.source_technique);const bool hound=beam && source.target.generation && fx && fx->has_hound_jet;
    const double length_factor=fx && harmful?(hound?fx->hound_jet_length:fx->jet_length):1.0;
    const double width_factor=fx && harmful?(hound?fx->hound_jet_width:fx->jet_width):1.0;
    const double rate=hound && fx->has_hound_speed?fx->hound_speed:1.0;
    const double length=p.length*length_factor,width=p.width*width_factor;
    const double life=!harmful?0.3:beam?std::max(0.1,p.particle_life)/rate:p.particle_life,drag=beam?0.7:p.drag;
    const double spread=beam?std::atan2(width*1.4,std::max(1.0,length))*2.0:p.spread*3.141592653589793/180.0;
    const double angle=source.angle+(harmful?r.state.control.rng.randf_range(-spread,spread)*0.5:std::sin(clock*39)*20*godot::Math::PI/180);
    const double speed=harmful?(beam?length*drag/(1.0-std::exp(-drag*life)):p.speed*length_factor)*r.state.control.rng.randf_range(0.9,1.1):100.0;
    CanisFlameHazard v;v.kind=Kind::Particle;v.definition=source.definition;v.observation=source.observation;v.origin=parent.pos;v.velocity=godot::Vector2::from_angle(angle)*speed;v.life=life;v.angle=source.angle;v.jet=jet;v.trail=source.trail;v.target=source.target;v.length=length;v.radius=!harmful?4.0:beam?width*0.5:p.r_start*width_factor;v.harmful=harmful;
    HazardState h;h.pos=parent.pos;h.damage=p.damage;h.shape=v;auto observed=owner;if (!harmful) {observed.observation_id=0;observed.source_technique=0;}const auto handle=AttackSystem::emit_hazard(r.state,h,observed);if (auto *d=detail(r.state,handle);d && !d->observation) d->observation=AttackSystem::get(r.state,handle)->id;return handle;
}
void damage(RunRuntime &r,const AttackRecord &record,double amount) {r.state.observations.effect_contact(record.id);ShipDamageRequest request;request.observation_id=record.spec.observation_id;request.effect_id=record.id;request.amount=amount;request.scale=DamageScale::AtkScale;request.cause=record.spec.cause;request.source=record.spec.owner.source_definition;request.technique=record.spec.source_technique;request.hit_policy=record.spec.contact.hit_policy;CombatResolver::ship_damage(r,request);}
std::vector<AttackHandle> handles(const RunRuntime &r,const BossBodyState &b,Kind kind) {std::vector<AttackHandle> out;const auto boss=r.state.bosses->body_handles.at(uint32_t(&b-r.state.bosses->bodies.data()));for (const auto &h:r.state.hazards) {const auto *v=std::get_if<CanisFlameHazard>(&h.shape);const auto *a=AttackSystem::get(r.state,h.attack);if (h.alive && v && v->kind==kind && a && same_handle(a->spec.boss,boss)) out.push_back(h.attack);}return out;}
}
AttackHandle CanisFlames::begin(RunRuntime &r,BossBodyState &b,uint32_t definition,EnemyHandle target,int64_t observation,uint32_t technique,std::optional<godot::Vector2> origin,std::optional<double> angle) {
    if (!definition || definition>r.content->canis_flames.size() || !r.state.enemy_handles.contains(b.actor) || b.mode>=BossMode::Defeated) return {};const auto &p=r.content->canis_flames[definition-1];if (p.boss!=r.content->boss_bodies[b.definition-1].boss || (p.kind==2 && (!r.state.enemy_handles.contains(target) || r.state.enemies[target.slot].dead))) return {};
    const auto &e=r.state.enemies[b.actor.slot];HazardState h;h.pos=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*0.84;const auto *fx=CanisFireVisualSystem::settings(*r.content,technique);if (p.kind==0 && fx && (fx->external_id=="O-sirius" || fx->external_id=="O-hunt")) h.pos=CanisImagePose::mouth(r,b);h.damage=p.damage;CanisFlameHazard v;v.definition=definition;v.observation=observation;v.angle=e.facing;v.origin=h.pos;v.life=p.duration;v.target=target;
    v.kind=p.kind==0?Kind::Jet:p.kind==1?Kind::Particle:Kind::Transfer;if (v.kind==Kind::Transfer) v.life=p.duration+0.25;if (p.kind==0 && r.state.enemy_handles.contains(target)) {const auto &source=r.state.enemies[target.slot];v.angle=angle.value_or(v.angle);h.pos=origin.value_or(source.pos)+godot::Vector2::from_angle(v.angle)*source.radius;v.origin=h.pos;}h.shape=v;auto owner=spec(r,b,technique,p.kind==0?Cause::FlameJet:Cause::SiriusFlame);
    if (p.kind==1) return particle(r,h,owner,{});
    const auto handle=AttackSystem::emit_hazard(r.state,h,owner);if (!AttackSystem::get(r.state,handle)) return {};if (!detail(r.state,handle)->observation) detail(r.state,handle)->observation=AttackSystem::get(r.state,handle)->id;
    if (p.kind==0) {
        if (p.trail_life>0) {HazardState trail;trail.pos=h.pos;trail.damage=p.trail_damage;auto tv=v;tv.observation=detail(r.state,handle)->observation;tv.kind=Kind::Trail;tv.life=p.trail_life;trail.shape=tv;auto own=owner;own.cause=Cause::SiriusTrail;const auto t=AttackSystem::emit_hazard(r.state,trail,own);detail(r.state,handle)->trail=t;}
        const auto *a=AttackSystem::get(r.state,handle);const auto copy=r.state.hazards[a->row];particle(r,copy,owner,handle);CanisFireVisualSystem::begin(r,b,handle,technique,target);
    }
    return handle;
}
AttackHandle CanisFlames::warning_particle(RunRuntime &r,BossBodyState &b,uint32_t definition,uint32_t technique) {if (!definition || definition>r.content->canis_flames.size()) return {};const auto &e=r.state.enemies[b.actor.slot];HazardState h;h.pos=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*0.84;CanisFlameHazard v;v.definition=definition;v.angle=e.facing;h.shape=v;return particle(r,h,spec(r,b,technique,Cause::SiriusFlame),{},false,b.clock);}
void CanisFlames::step(RunRuntime &r,BossBodyState &b,double dt) {
    if (dt<=0) return;auto &s=r.state;
    // 噴射→そのtickに増えた粒→焼け跡の順は旧実装と同じ。
    for (auto handle:handles(r,b,Kind::Jet)) {
        auto *v=detail(s,handle);if (!v) continue;const auto &p=r.content->canis_flames[v->definition-1];const auto record=*AttackSystem::get(s,handle);
        if (v->target.generation && (!s.enemy_handles.contains(v->target) || s.enemies[v->target.slot].dead)) {v->source_ended=true;v->age=std::max(v->age,p.duration);}
        const double elapsed=std::min(dt,std::max(0.0,p.duration-v->age));v->age+=dt;v->emit+=elapsed*100.0;const int count=int(v->emit);v->emit-=count;
        const auto copy=s.hazards[record.row];for (int k=0;k<count;++k) particle(r,copy,record.spec,handle);
    }
    for (auto handle:handles(r,b,Kind::Particle)) {
        const auto *entry=AttackSystem::get(s,handle);if (!entry) continue;const auto record=*entry;auto &h=s.hazards[record.row];auto &v=std::get<CanisFlameHazard>(h.shape);const auto &p=r.content->canis_flames[v.definition-1];const bool beam=v.jet.generation;const auto *fx=CanisFireVisualSystem::settings(*r.content,record.spec.source_technique);const bool hound=beam && v.target.generation && fx && fx->has_hound_jet;const double width_factor=fx && v.harmful?(hound?fx->hound_jet_width:fx->jet_width):1.0;const auto from=h.pos;v.age+=dt;const double elapsed=std::min(dt,std::max(0.0,v.life-v.age+dt));v.velocity*=std::exp(-(beam?0.7:p.drag)*elapsed);h.pos+=v.velocity*elapsed;const double ratio=std::clamp(v.age/v.life,0.0,1.0);v.radius=!v.harmful?4.0+5.0*ratio:beam?p.width*width_factor*(0.5+1.1*ratio):(p.r_start+(p.r_end-p.r_start)*ratio)*width_factor;
        if (v.harmful) s.observations.effect_check(record.id,false);
        const double scale=beam?0.85:p.hit_scale;if (const auto hit=FieldSystem::first_body_hit(r,from,h.pos,v.radius*scale)) {h.pos=from.lerp(h.pos,hit->t);v.age=v.life;}
        if (beam && h.pos.distance_to(v.origin)>=v.length) {h.pos=v.origin+(h.pos-v.origin).normalized()*v.length;v.age=v.life;}
        if (auto *trail=detail(s,v.trail)) trail->length=std::clamp(std::max(trail->length,double((h.pos-trail->origin).dot(godot::Vector2::from_angle(trail->angle)))),0.0,v.length);
        const auto *jet=AttackSystem::get(s,v.jet);if (v.harmful && (!beam || (jet && !jet->ship_hit)) && distance(s.ship_pos,from,h.pos)<v.radius*scale+s.ship_config.ship_radius) {if (beam) AttackSystem::mark_ship_hit(s,v.jet);damage(r,record,h.damage);}
        s.observations.effect_position(record.id,h.pos);if (v.age>=v.life) AttackSystem::end(s,handle,AttackEndReason::Lifetime);
    }
    for (auto handle:handles(r,b,Kind::Trail)) {const auto record=*AttackSystem::get(s,handle);auto &h=s.hazards[record.row];auto &v=std::get<CanisFlameHazard>(h.shape);const auto &p=r.content->canis_flames[v.definition-1];v.age+=dt;if (v.age>=v.life) {AttackSystem::end(s,handle,AttackEndReason::Lifetime);continue;}if (v.age>=p.trail_delay) s.observations.effect_check(record.id,false);if (v.age>=p.trail_delay && distance(s.ship_pos,h.pos,h.pos+godot::Vector2::from_angle(v.angle)*v.length)<p.trail_width*0.5+s.ship_config.ship_radius) damage(r,record,h.damage);}
    for (auto handle:handles(r,b,Kind::Transfer)) {const auto record=*AttackSystem::get(s,handle);auto &h=s.hazards[record.row];auto &v=std::get<CanisFlameHazard>(h.shape);if (!s.enemy_handles.contains(v.target) || s.enemies[v.target.slot].dead) {AttackSystem::end(s,handle,AttackEndReason::ParticipantEnd);continue;}v.age+=dt;const double travel=r.content->canis_flames[v.definition-1].duration;if (v.emit<1 && v.age>=travel) {v.emit=1;godot::Dictionary event;event["id"]=record.id;event["boss_id"]=b.id;event["target"]=s.enemy_handles.entity_id(v.target);event["profile"]=v.definition;event["pos"]=s.enemies[v.target.slot].pos;event["from"]=v.origin;event["life"]=travel;event["observation"]=v.observation;FrameBuilder::append(r,"canis_ignite_arrived",event);}if (v.age>=v.life) AttackSystem::end(s,handle,AttackEndReason::Lifetime);}
    for (auto handle:handles(r,b,Kind::Jet)) {const auto *v=detail(s,handle);if (v && v->age>=r.content->canis_flames[v->definition-1].duration) {bool child=false;for (const auto &h:s.hazards) if (h.alive) if (const auto *p=std::get_if<CanisFlameHazard>(&h.shape);p && same_handle(p->jet,handle)) {child=true;break;}if (!child) AttackSystem::end(s,handle,AttackEndReason::Lifetime);}}
}
bool CanisFlames::validate(const godot::RunState &s,const ContentBundle &c) {for (const auto &h:s.hazards) if (h.alive) if (const auto *v=std::get_if<CanisFlameHazard>(&h.shape)) {if (!v->definition || v->definition>c.canis_flames.size() || v->kind>Kind::Transfer || v->observation<=0 || !v->origin.is_finite() || !v->velocity.is_finite() || !std::isfinite(v->angle)) return false;for (double x:{v->age,v->life,v->emit,v->length,v->radius}) if (!std::isfinite(x) || x<0) return false;if (v->life<=0 || (v->kind==Kind::Transfer && !s.enemy_handles.contains(v->target))) return false;const auto *a=AttackSystem::get(s,h.attack);if (!a || !s.bosses->body_handles.contains(a->spec.boss)) return false;}return true;}
godot::Array CanisFlames::snapshot(const RunRuntime &r,const BossBodyState &b) {godot::Array out;for (auto kind:{Kind::Jet,Kind::Particle,Kind::Trail,Kind::Transfer}) for (auto handle:handles(r,b,kind)) {const auto record=*AttackSystem::get(r.state,handle);const auto &h=r.state.hazards[record.row];const auto &v=std::get<CanisFlameHazard>(h.shape);const auto &p=r.content->canis_flames[v.definition-1];godot::Dictionary q;q["id"]=record.id;q["kind"]=int(kind);q["harmful"]=v.harmful;q["profile"]=v.definition;q["pos"]=h.pos;q["from"]=v.origin;q["angle"]=v.angle;q["velocity"]=v.velocity;q["age"]=v.age;q["life"]=v.life;q["length"]=v.length;q["radius"]=kind==Kind::Trail?p.trail_width:v.radius;q["width"]=p.width;q["hit"]=record.ship_hit;q["observation"]=v.observation;q["emitting"]=kind==Kind::Jet && v.age<p.duration;const auto *source_jet=AttackSystem::get(r.state,v.jet);q["jet_id"]=source_jet?source_jet->id:0;q["technique"]=record.spec.source_technique;q["target"]=r.state.enemy_handles.entity_id(v.target);q["to"]=r.state.enemy_handles.contains(v.target)?r.state.enemies[v.target.slot].pos:h.pos;if (kind==Kind::Transfer) q["travel_time"]=p.duration;out.push_back(q);}return out;}
}
