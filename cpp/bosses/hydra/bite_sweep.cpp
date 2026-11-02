#include "normal_attack.h"
#include "body.h"
#include "swim.h"
#include "squad.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
namespace speed {
namespace {
void bite(RunRuntime &r,const BossBodyState &b,TechniqueState &t,godot::Vector2 from,godot::Vector2 to,const HydraNormalDefinition &v) {
    HazardState h;h.pos=from;h.duration=b.hydra.separated && !same_handle(t.actor,b.hydra.bearer.actor)?0.1:0.12;h.damage=r.content->boss_techniques[t.definition-1].damage;h.shape=HydraShapeHazard{{from,to},v.bite_radius};AttackSpec s;s.owner.live_source=t.actor;s.owner.attached=true;s.technique=r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data()));s.boss=r.state.bosses.body_handles.at(uint32_t(&b-r.state.bosses.bodies.data()));s.source_technique=t.definition;s.cause=Cause::Bite;s.policies=EndPolicy::NaturalLifetime|EndPolicy::CancelWithTechnique;s.policies|=policy(EndPolicy::CancelWithParticipant)|policy(EndPolicy::ClearWithBoss);s.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,true};const auto handle=AttackSystem::emit_hazard(r.state,h,s);if (AttackSystem::get(r.state,handle)) {auto &record=r.state.attacks.records[handle.slot];record.ship_previous=t.previous_ship;record.ship_previous_ready=true;}
}
}
void HydraNormalAttack::step_sweep(RunRuntime &r,TechniqueState &t,double dt) {
    auto *b=body(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}auto &n=*neck(*b,t.actor);if (b->hydra.growth_left>0 || b->hydra.separation_left>0) return;
    const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=*std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==t.definition;});const auto &sweep=*std::find_if(r.content->hydra_sweeps.begin(),r.content->hydra_sweeps.end(),[&](const auto &v){return v.technique==t.definition;});const bool free=b->hydra.separated && &n!=&b->hydra.bearer;
    n.elapsed+=dt;const double time=n.elapsed,elapsed=time-p.warn;t.elapsed=time;t.remaining=std::max(0.0,p.warn+p.active+p.hold-time);const auto &health=r.state.enemies[t.actor.slot];if (health.hp<n.head_hp) {n.hit_left=0.35;if (free) HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));cue(r,*b,n,"hit",t.definition,n.head_hp-std::max(0.0,health.hp));}n.head_hp=health.hp;const auto from=HydraBody::head_position(r,*b,n);const auto base=HydraBody::neck_base(r,*b,n);
    const auto &e=r.state.enemies[b->actor.slot];const bool tracking_locked=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();if (tracking_locked && !n.locked) n.target=from+godot::Vector2::from_angle(b->hydra.separated?n.look_angle:n.angle)*std::max(1.0,double(from.distance_to(n.target)));if (p.track_during_warn && time<=std::min(v.aim_tracking,p.warn) && !tracking_locked) n.target=r.state.ship_pos;
    const auto previous_phase=n.normal_phase;n.normal_phase=time<p.warn?0:time<p.warn+p.active?1:2;if (free && n.normal_phase==2 && previous_phase!=2) {HydraSquad::watch_player(r,*b,n,HydraSquad::profile(n));AttackSystem::source_ended(r.state,t.actor,AttackEndReason::TechniqueEnd);}
    if (time<p.warn) {aim(r,*b,n,(n.target-(free?n.free_pos:base)).angle()-(free?0:sweep.arc*0.5),dt);n.glow=time/std::max(p.warn,0.001);}
    else {
        if (!n.locked) {n.locked=true;n.strike_from=n.strike_pos=from;n.sweep=free?n.look_angle:(n.target-base).angle();if (free) cue(r,*b,n,"attack_started",t.definition);}
        const double fraction=std::clamp(elapsed/std::max(p.active,0.001),0.0,1.0),angle=n.sweep+sweep.arc*(fraction-0.5);
        if (free) {
            if (!n.lunge_done) {n.strike_pos=n.strike_from+godot::Vector2::from_angle(angle)*sweep.reach;n.look_angle=angle;n.extension=true;n.free_pos=HydraBody::head_position(r,*b,n);n.strike_pos=n.free_pos;
                if (elapsed<p.active) bite(r,*b,t,from,n.free_pos,v);else {n.extension=false;n.lunge_done=true;n.angle=n.look_angle;const auto &swim=HydraSwim::rule(r,*b);n.velocity=godot::Vector2::from_angle(n.angle)*swim.attack_speed*swim.lunge_momentum;}}
            n.glow=0;
        } else if (time<p.warn+p.active) {n.angle=angle;n.strike_pos=base+godot::Vector2::from_angle(angle)*sweep.reach;bite(r,*b,t,from,n.strike_pos,v);}
    }
    t.aim=n.target;t.locked=n.locked;t.direction=godot::Vector2::from_angle(free?n.look_angle:n.angle);t.stage=time<p.warn?TechniqueStage::Windup:time<p.warn+p.active?TechniqueStage::Active:TechniqueStage::Recovery;
    auto &part=r.state.enemies[t.actor.slot];part.pos=HydraBody::head_position(r,*b,n);part.facing=b->hydra.separated?n.look_angle:n.angle;
    if (time>=p.warn+p.active+p.hold) {const auto at=part.pos;if (!b->hydra.separated) n.angle=(at-base).angle();n.length=at.distance_to(base);n.free_pos=at;n.locked=n.extension=false;n.normal=0;n.cd=v.attack_cd;t.stage=TechniqueStage::Finished;AttackSystem::end_technique(r.state,r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data())),false);AttackSystem::source_ended(r.state,t.actor,AttackEndReason::TechniqueEnd);if (b->hydra.separated) HydraSquad::watch_player(r,*b,n,&n==&b->hydra.bearer?HydraSquadRole::Bearer:HydraSquad::profile(n));cue(r,*b,n,"finished");}
    t.previous_ship=r.state.ship_pos;HydraBody::follow_neck(r,*b,n,dt);
}
}
