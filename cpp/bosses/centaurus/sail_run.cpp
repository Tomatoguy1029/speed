#include "sail_run.h"
#include "../flow/phase_controller.h"
#include "../../behaviors/enemies/defender.h"
#include "../../systems/attacks/light_arrow.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusSailDefinition &rule(const ContentBundle &c,const TechniqueState &t) {return *std::find_if(c.centaurus_sails.begin(),c.centaurus_sails.end(),[&](const auto &v){return v.technique==t.definition;});}
const CentaurusBodyDefinition &body_rule(const RunRuntime &r,const BossBodyState &b) {return *std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &p){return p.body==b.definition;});}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {godot::Dictionary p;p["id"]=r.state.enemy_handles.entity_id(t.actor);p["technique"]=t.definition;p["cue"]=name;p["world_time"]=r.state.world_time;if (r.state.enemy_handles.contains(t.actor)) {p["position"]=r.state.enemies[t.actor.slot].pos;p["angle"]=r.state.enemies[t.actor.slot].facing;}else {p["position"]=godot::Vector2();p["angle"]=0.0;}FrameBuilder::append(r,"centaurus_cue",p);}
void move(RunRuntime &r,TechniqueState &t,godot::Vector2 step,double dt) {auto &e=r.state.enemies[t.actor.slot];const auto before=e.pos;e.vel=step/std::max(dt,0.001);e.pos+=step;FieldSystem::collide_enemy(r,t.actor.slot,before,dt);}
}
bool CentaurusSail::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && b->phase>=2 && definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusSail::begin(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);const auto &e=r.state.enemies[t.actor.slot];const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=rule(*r.content,t);const auto &d=body_rule(r,b);
    CentaurusSailState s;s.center=r.state.ship_pos;const auto offset=e.pos-s.center;s.radius=std::clamp(double(offset.length()),v.radius_min,v.radius_max);s.angle=offset.angle();s.side=b.centaurus.sail_side;b.centaurus.sail_side*=-1;s.boosted=true;t.detail=s;t.started_at=b.clock;
    auto &guards=b.centaurus.guards;guards.erase(std::remove_if(guards.begin(),guards.end(),[&](const auto &g){return !r.state.enemy_handles.contains(g.actor) || r.state.enemies[g.actor.slot].dead;}),guards.end());
    for (const auto &g:guards) DefenderBehavior::boost(r,g.actor,d.sail_guard_speed*g.scale,d.sail_guard_wobble,r.state.world_time+p.warn+v.duration,g.phase);
    cue(r,t,"sail_windup");
}
void CentaurusSail::release(RunRuntime &r,TechniqueState &t) {auto *s=std::get_if<CentaurusSailState>(&t.detail);if (!s || !s->boosted) return;s->boosted=false;if (auto *b=PhaseController::find(r,t.actor)) for (const auto &g:b->centaurus.guards) DefenderBehavior::clear_boost(r,g.actor);}
void CentaurusSail::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=rule(*r.content,t);auto &s=std::get<CentaurusSailState>(t.detail);auto &b=*PhaseController::find(r,t.actor);const auto &d=r.content->bosses[p.boss-1];
    if (t.stage==TechniqueStage::Recovery) {e.vel={};t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    const double elapsed=b.clock-t.started_at;const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    if (elapsed<p.warn) {move(r,t,(s.center+godot::Vector2::from_angle(s.angle)*s.radius-e.pos).limit_length(v.approach_speed*dt),dt);if (!tracking.locked()) e.facing+=std::clamp(angle_difference(s.angle+s.side*godot::Math::PI*0.5-e.facing),-d.turn*dt,d.turn*dt);return;}
    if (t.stage==TechniqueStage::Windup) {t.stage=TechniqueStage::Active;cue(r,t,"sail_run");}
    const double running=elapsed-p.warn,duration=std::max(v.duration,0.001),theta=s.angle+s.side*v.arc*std::clamp(running/duration,0.0,1.0);
    move(r,t,s.center+godot::Vector2::from_angle(theta)*s.radius-e.pos,dt);e.facing=theta+s.side*godot::Math::PI*0.5;
    const double interval=std::max(v.interval,0.001);
    while (s.fired*interval<=running && s.fired*interval<duration) {LightArrowParams shot;shot.position=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*body_rule(r,b).bow_reach;shot.angle=tracking.angle(e.facing,(r.state.enemy_aim-shot.position).angle());shot.speed=p.speed;shot.radius=v.radius;shot.travel=v.travel;shot.damage=p.damage*r.state.combat_config.atk_scale;shot.length=v.length;shot.owner=t.actor;shot.definition=v.projectile;shot.technique=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));LightArrowSystem::emit(r,shot);++s.fired;cue(r,t,"sail_shot");}
    if (running>=duration) {release(r,t);e.vel={};t.stage=TechniqueStage::Recovery;t.remaining=p.recover;cue(r,t,"sail_folded");}
}
bool CentaurusSail::validate(const TechniqueState &t,const ContentBundle &c) {const auto *s=std::get_if<CentaurusSailState>(&t.detail);if (!s || !s->center.is_finite() || !std::isfinite(s->radius) || !std::isfinite(s->angle) || s->radius<0 || (s->side!=1 && s->side!=-1)) return false;return s->fired<=std::ceil(std::max(rule(c,t).duration,0.001)/std::max(rule(c,t).interval,0.001));}
godot::Dictionary CentaurusSail::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &s=std::get<CentaurusSailState>(t.detail);const auto &p=rule(*r.content,t);godot::Dictionary out;out["released"]=s.fired;out["interval"]=p.interval;out["center"]=s.center;out["orbit_radius"]=s.radius;out["sail_angle"]=s.angle;out["side"]=s.side;out["boosted"]=s.boosted;out["recovery_fraction"]=t.remaining/std::max(0.001,r.content->boss_techniques[t.definition-1].recover);return out;}
}
