#include "normal_attack.h"
#include "body.h"
#include "swim.h"
#include "squad.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
void HydraNormalAttack::step_blades(RunRuntime &r,TechniqueState &t,double dt) {
    auto *b=body(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}auto &n=*neck(*b,t.actor);if (b->hydra.growth_left>0 || b->hydra.separation_left>0) return;
    const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=*std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==t.definition;});const auto &blade=*std::find_if(r.content->hydra_wind_blades.begin(),r.content->hydra_wind_blades.end(),[&](const auto &v){return v.technique==t.definition;});const bool free=b->hydra.separated && &n!=&b->hydra.bearer;
    n.elapsed+=dt;const double time=n.elapsed,elapsed=time-p.warn;t.elapsed=time;t.remaining=std::max(0.0,p.warn+p.active+p.hold-time);const auto &health=r.state.enemies[t.actor.slot];if (health.hp<n.head_hp) {n.hit_left=0.35;if (free) HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));cue(r,*b,n,"hit",t.definition,n.head_hp-std::max(0.0,health.hp));}n.head_hp=health.hp;const auto from=HydraBody::head_position(r,*b,n);const auto base=HydraBody::neck_base(r,*b,n);
    const auto &e=r.state.enemies[b->actor.slot];const bool tracking_locked=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();if (tracking_locked && !n.locked) n.target=from+godot::Vector2::from_angle(b->hydra.separated?n.look_angle:n.angle)*std::max(1.0,double(from.distance_to(n.target)));if (p.track_during_warn && time<=std::min(v.aim_tracking,p.warn) && !tracking_locked) n.target=r.state.ship_pos;
    const auto previous_phase=n.normal_phase;n.normal_phase=time<p.warn?0:time<p.warn+p.active?1:2;if (free && n.normal_phase==2 && previous_phase!=2) {HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));AttackSystem::source_ended(r.state,t.actor,AttackEndReason::TechniqueEnd);}
    if (time<p.warn) {aim(r,*b,n,(n.target-from).angle()-(free?0:blade.spread*0.5),dt);n.glow=time/std::max(p.warn,0.001);}
    else {
        if (!n.locked) {n.locked=true;n.strike_pos=n.strike_from=from;n.sweep=free?n.look_angle:(n.target-from).angle();if (free) cue(r,*b,n,"attack_started",t.definition);}
        if (free && n.normal_phase==1) n.look_angle=n.sweep;
        if (n.step<3 && elapsed>=n.step*blade.interval) {
            const double angle=n.sweep+(double(n.step)*0.5-0.5)*blade.spread;const auto origin=free?n.free_pos:n.strike_pos,direction=godot::Vector2::from_angle(angle);if (!free) n.angle=angle;
            HazardState h;h.pos=origin;h.duration=blade.life;h.damage=p.damage;HydraShapeHazard shape;shape.life=blade.life;shape.width=blade.width;shape.velocity=direction*blade.speed;
            for (int i=0;i<13;++i) {const double arc=-3.141592653589793*0.5+3.141592653589793*i/12;shape.points.push_back(origin+godot::Vector2(std::cos(arc)*blade.size*0.6,std::sin(arc)*blade.size).rotated(angle));}h.shape=shape;
            AttackSpec spec;spec.owner.live_source=t.actor;spec.technique=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));spec.boss=r.state.bosses->body_handles.at(uint32_t(b-r.state.bosses->bodies.data()));spec.source_technique=t.definition;spec.cause=Cause::WindBlade;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBoss;spec.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,true};const auto handle=AttackSystem::emit_hazard(r.state,h,spec);if (AttackSystem::get(r.state,handle)) r.state.attacks.records[handle.slot].ship_previous=t.previous_ship;
            ++n.step;if (!free) cue(r,*b,n,"attack_started",t.definition);
        }
        if (free) n.glow=0;
    }
    t.aim=n.target;t.locked=n.locked;t.direction=godot::Vector2::from_angle(free?n.look_angle:n.angle);t.stage=time<p.warn?TechniqueStage::Windup:time<p.warn+p.active?TechniqueStage::Active:TechniqueStage::Recovery;
    auto &part=r.state.enemies[t.actor.slot];part.pos=HydraBody::head_position(r,*b,n);part.facing=b->hydra.separated?n.look_angle:n.angle;
    if (time>=p.warn+p.active+p.hold) {const auto at=part.pos;if (!b->hydra.separated) n.angle=(at-base).angle();n.length=at.distance_to(base);n.free_pos=at;n.locked=n.extension=false;n.normal=0;n.cd=v.attack_cd;t.stage=TechniqueStage::Finished;AttackSystem::end_technique(r.state,r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data())),false);AttackSystem::source_ended(r.state,t.actor,AttackEndReason::TechniqueEnd);if (b->hydra.separated) HydraSquad::watch_player(r,*b,n,&n==&b->hydra.bearer?HydraSquadRole::Bearer:HydraSquad::profile(n));cue(r,*b,n,"finished");}
    t.previous_ship=r.state.ship_pos;
}
}
