#include "normal_attack.h"
#include "body.h"
#include "swim.h"
#include "squad.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
namespace speed {
void HydraNormalAttack::step_wind(RunRuntime &r,TechniqueState &t,double dt,const HydraNormalContext *ctx) {
    auto *b=body(r,t.actor,ctx);if (!b) {t.stage=TechniqueStage::Failed;return;}auto &n=*neck(*b,t.actor,ctx);if (b->hydra.growth_left>0 || b->hydra.separation_left>0) return;
    const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=*std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==t.definition;});const auto &wind=*std::find_if(r.content->hydra_wind_bands.begin(),r.content->hydra_wind_bands.end(),[&](const auto &v){return v.technique==t.definition;});const bool free=b->hydra.separated && &n!=&b->hydra.bearer;
    n.elapsed+=dt;const double time=n.elapsed;t.elapsed=time;t.remaining=std::max(0.0,p.warn+p.active+p.hold-time);const auto &health=r.state.enemies[t.actor.slot];if (health.hp<n.head_hp) {n.hit_left=0.35;if (free) HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));cue(r,*b,n,"hit",t.definition,n.head_hp-std::max(0.0,health.hp),0,ctx);}n.head_hp=health.hp;const auto from=head_position(r,*b,n,ctx);const auto base=neck_base(r,*b,n,ctx);
    const auto &e=r.state.enemies[b->actor.slot];const bool tracking_locked=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();if (tracking_locked && !n.locked) n.target=from+godot::Vector2::from_angle(b->hydra.separated?n.look_angle:n.angle)*std::max(1.0,double(from.distance_to(n.target)));if (p.track_during_warn && time<=std::min(v.aim_tracking,p.warn) && !tracking_locked) n.target=r.state.ship_pos;
    const auto previous_phase=n.normal_phase;n.normal_phase=time<p.warn?0:time<p.warn+p.active?1:2;if (free && n.normal_phase==2 && previous_phase!=2) {HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));AttackSystem::source_ended(r.state,t.actor,AttackEndReason::TechniqueEnd);}
    const auto emission=[&](godot::Vector2 at,double angle,double delay) {
        HazardState h;h.pos=at;h.delay=delay;h.duration=p.active;h.damage=0;h.shape=HydraShapeHazard{{at,at+godot::Vector2::from_angle(angle)*wind.length},wind.width};auto &shape=std::get<HydraShapeHazard>(h.shape);shape.life=p.active;shape.delay=delay;shape.wind_force=wind.force;
        AttackSpec spec;spec.owner.live_source=t.actor;spec.owner.attached=true;spec.technique=ticket(r,t,ctx);spec.boss=r.state.bosses.body_handles.at(uint32_t(b-r.state.bosses.bodies.data()));spec.source_technique=t.definition;spec.cause=Cause::Wind;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::CancelWithTechnique;spec.policies|=policy(EndPolicy::CancelWithParticipant)|policy(EndPolicy::ClearWithBoss);spec.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,true};n.emission=(context_spec(r,spec,ctx),AttackSystem::emit_hazard(r.state,h,spec));if (AttackSystem::get(r.state,n.emission)) r.state.attacks.records[n.emission.slot].ship_previous=t.previous_ship;
    };
    const auto update_emission=[&](godot::Vector2 at,double angle) {if (const auto *record=AttackSystem::get(r.state,n.emission)) {auto &h=r.state.hazards[record->row];auto &shape=std::get<HydraShapeHazard>(h.shape);shape.points={at,at+godot::Vector2::from_angle(angle)*wind.length};h.pos=at;}};
    if (time<p.warn) {
        aim(r,*b,n,(n.target-from).angle(),dt,ctx);n.glow=time/std::max(p.warn,0.001);
    } else {
        if (!n.locked) {n.locked=true;n.strike_pos=n.strike_from=free?from:base+godot::Vector2::from_angle(n.angle)*n.length;n.sweep=free?n.look_angle:n.angle;if (!n.emission.generation) emission(free?n.free_pos:n.strike_pos,n.sweep,0);cue(r,*b,n,"attack_started",t.definition,0,0,ctx);}
        if (free) {if (n.normal_phase==1) n.look_angle=n.sweep;update_emission(n.free_pos,n.sweep);n.glow=0;}
    }
    t.aim=n.target;t.locked=n.locked;t.direction=godot::Vector2::from_angle(free?n.look_angle:n.angle);t.stage=time<p.warn?TechniqueStage::Windup:time<p.warn+p.active?TechniqueStage::Active:TechniqueStage::Recovery;
    auto &part=r.state.enemies[t.actor.slot];if (!ctx) {part.pos=head_position(r,*b,n,ctx);part.facing=b->hydra.separated?n.look_angle:n.angle;}
    if (time>=p.warn+p.active+p.hold) {if (!ctx) {const auto at=part.pos;if (!b->hydra.separated) n.angle=(at-base).angle();n.length=at.distance_to(base);n.emission={};n.free_pos=at;n.locked=n.extension=false;n.normal=0;n.cd=v.attack_cd;}t.stage=TechniqueStage::Finished;finish(r,t,ctx);if (b->hydra.separated) HydraSquad::watch_player(r,*b,n,&n==&b->hydra.bearer?HydraSquadRole::Bearer:HydraSquad::profile(n));cue(r,*b,n,"finished",0,0,0,ctx);}
    t.previous_ship=r.state.ship_pos;
}
}
