#include "pounce.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include "../../systems/field.h"
#include "../../systems/boss_contact.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CanisPounceDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.canis_pounces.begin(),c.canis_pounces.end(),[&](const auto &v){return v.technique==definition;});}
void aim(RunRuntime &r,TechniqueState &t,CanisPounceState &v,double dt) {const auto &p=rule(*r.content,v.definition);auto &e=r.state.enemies[t.actor.slot];t.aim=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*(std::max(0.0,v.warn_time-v.stage_time)+p.lead_extra));CanisTechnique::face(r,t,t.aim,r.content->bosses[r.content->boss_techniques[v.definition-1].boss-1].turn,dt);}
void prepare(RunRuntime &r,TechniqueState &t,CanisPounceState &v) {v.stage_time=0;v.jumping=false;t.stage=TechniqueStage::Windup;t.locked=t.hit=false;r.state.enemies[t.actor.slot].vel={};aim(r,t,v,0);CanisTechnique::cue(r,t,"telegraph");}
}
bool CanisPounce::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && !b->canis->barking && !b->canis->calling && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && std::any_of(r.content->canis_pounces.begin(),r.content->canis_pounces.end(),[&](const auto &p){return p.technique==definition;});}
double CanisPounce::cooldown(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto &p=rule(*r.content,definition);const auto *b=PhaseController::find(r,actor);return b && b->canis->led.size()<p.alone_hounds?p.cd_alone:r.content->boss_techniques[definition-1].cd;}
// 試作 canisJump は元の飛行時間を1.7で割る。3技の移動・時計・予約で同じ値を使う。
double CanisPounce::flight_time(const RunRuntime &r,uint32_t definition) {return rule(*r.content,definition).active/1.7;}
double CanisPounce::attack_length(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto &p=rule(*r.content,definition);const auto &base=r.content->boss_techniques[definition-1];const auto *b=PhaseController::find(r,actor);const int64_t count=b && b->canis->led.size()<p.alone_hounds?p.chain:1;const double active=flight_time(r,definition);return base.warn+active+(count-1)*(p.chain_warn+active)+0.05;}
void CanisPounce::start(RunRuntime &r,TechniqueState &t,CanisPounceState &v,uint32_t definition,int64_t count) {v={};v.definition=definition;v.left=count;v.warn_time=r.content->boss_techniques[definition-1].warn;t.previous_ship=r.state.ship_pos;prepare(r,t,v);}
void CanisPounce::begin(RunRuntime &r,TechniqueState &t) {t.detail=CanisPounceState{};const auto &p=rule(*r.content,t.definition);const auto *b=PhaseController::find(r,t.actor);start(r,t,t.detail.get<CanisPounceState>(),t.definition,b && b->canis->led.size()<p.alone_hounds?p.chain:1);}
bool CanisPounce::advance(RunRuntime &r,TechniqueState &t,CanisPounceState &v,double dt) {
    if (v.done) return true;const auto &p=rule(*r.content,v.definition);const auto &base=r.content->boss_techniques[v.definition-1];
    if (!v.jumping) {if (!t.locked && base.track_during_warn) aim(r,t,v,dt);v.stage_time+=dt;if (!t.locked && v.stage_time>=v.warn_time-p.lock) CanisTechnique::lock_aim(r,t,false,p.overshoot);if (v.stage_time<v.warn_time) return false;if (!t.locked) CanisTechnique::lock_aim(r,t,false,p.overshoot);v.jumping=true;v.stage_time=0;t.stage=TechniqueStage::Active;CanisTechnique::cue(r,t,"pounce");return false;}
    auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos;const double active=flight_time(r,v.definition);const auto movement=(t.aim-from)*std::clamp(dt/std::max(active-v.stage_time,dt),0.0,1.0);e.pos+=movement;e.vel=movement/std::max(dt,0.001);FieldSystem::collide_enemy(r,t.actor.slot,from,dt);e.facing=t.direction.angle();v.stage_time+=dt;const bool collision=e.pos.distance_squared_to(from+movement)>0.01;if (v.stage_time<active && !collision) return false;BossContactSystem::register_landing(r,t.actor,e.pos,e.radius,v.definition,t.observation_id);if (auto *body=PhaseController::find(r,t.actor)) body->canis->image_pose.landed_at=body->clock;CanisTechnique::cue(r,t,"landing");--v.left;if (v.left>0) {v.warn_time=p.chain_warn;prepare(r,t,v);return false;}v.done=true;return true;
}
void CanisPounce::step(RunRuntime &r,TechniqueState &t,double dt) {auto &v=t.detail.get<CanisPounceState>();if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}if (advance(r,t,v,dt)) {t.stage=TechniqueStage::Recovery;t.remaining=r.content->boss_techniques[v.definition-1].recover;t.locked=false;r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"recovery_started");}}
bool CanisPounce::validate(const CanisPounceState &v,const ContentBundle &c) {const auto p=std::find_if(c.canis_pounces.begin(),c.canis_pounces.end(),[&](const auto &p){return p.technique==v.definition;});return p!=c.canis_pounces.end() && v.left>=-1 && uint64_t(std::max(int64_t(0),v.left))<=std::max(uint32_t(1),p->chain) && std::isfinite(v.stage_time) && v.stage_time>=0 && std::isfinite(v.warn_time) && v.warn_time>=0;}
double CanisPounce::progress(const CanisPounceState &v) {return v.jumping?0:std::clamp(v.stage_time/std::max(v.warn_time,0.001),0.0,1.0);}
godot::Dictionary CanisPounce::motion_snapshot(const RunRuntime &r,const CanisPounceState &v) {godot::Dictionary out;out["jumping"]=v.jumping;out["done"]=v.done;out["stage_time"]=v.stage_time;out["warn_time"]=v.warn_time;out["active_time"]=flight_time(r,v.definition);return out;}
godot::Dictionary CanisPounce::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=t.detail.get<CanisPounceState>();godot::Dictionary out;out["jumping"]=v.jumping;out["done"]=v.done;out["left"]=v.left;out["stage_time"]=v.stage_time;out["warn_time"]=v.warn_time;out["pounce_motion"]=motion_snapshot(r,v);out["windup_progress"]=progress(v);out["crouch"]=progress(v);out["stretch"]=v.jumping?1.15:1.0-progress(v)*0.15;return out;}
}
