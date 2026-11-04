#include "sirius_flame.h"
#include "fire_visual.h"
#include "flames.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include "../../systems/field.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {const CanisSiriusFlameDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.canis_sirius_flames.begin(),c.canis_sirius_flames.end(),[&](const auto &p){return p.technique==definition;});}}
bool CanisSiriusFlame::ready(const RunRuntime &r,EnemyHandle actor,uint32_t) {const auto *b=PhaseController::find(r,actor);return b && !b->canis.barking && !b->canis.calling;}
double CanisSiriusFlame::attack_length(const RunRuntime &r,uint32_t definition) {const auto &base=r.content->boss_techniques[definition-1];return base.warn+base.active+0.1;}
void CanisSiriusFlame::begin(RunRuntime &r,TechniqueState &t) {t.detail=CanisSiriusFlameState{};r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"flame_windup");}
void CanisSiriusFlame::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=std::get<CanisSiriusFlameState>(t.detail);const auto &base=r.content->boss_techniques[t.definition-1];const auto &p=rule(*r.content,t.definition);auto *b=PhaseController::find(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}auto &e=r.state.enemies[t.actor.slot];
    if (t.stage==TechniqueStage::Recovery) {e.vel={};t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    v.age+=dt;
    if (!v.started) {if (base.track_during_warn) CanisTechnique::face(r,t,r.state.enemy_aim,r.content->bosses[base.boss-1].turn,dt);e.vel={};v.emit_left+=dt*18;while (v.emit_left>=1) {v.emit_left-=1;CanisFlames::warning_particle(r,*b,p.flame,t.definition);}if (v.age<base.warn) return;v.started=true;v.age=0;v.emit_left=0;t.stage=TechniqueStage::Active;CanisFireVisualSystem::begin_continuous(r,*b,t,base.active);CanisTechnique::cue(r,t,"flame_start");}
    CanisTechnique::face(r,t,r.state.ship_pos,p.turn,dt);if (e.pos.distance_to(r.state.ship_pos)>p.advance_until) {const auto from=e.pos,step=godot::Vector2::from_angle(e.facing)*p.advance*dt;e.pos+=step;e.vel=step/std::max(dt,0.001);FieldSystem::collide_enemy(r,t.actor.slot,from,dt);}else e.vel={};
    v.emit_left+=dt*p.emit_rate;while (v.emit_left>=1) {v.emit_left-=1;CanisFlames::begin(r,*b,p.flame,{},0,t.definition);}if (v.age>=base.active) {t.stage=TechniqueStage::Recovery;t.remaining=base.recover;t.locked=false;e.vel={};CanisTechnique::cue(r,t,"recovery_started");}
}
bool CanisSiriusFlame::validate(const TechniqueState &t) {const auto *v=std::get_if<CanisSiriusFlameState>(&t.detail);return v && std::isfinite(v->age) && v->age>=0 && std::isfinite(v->emit_left) && v->emit_left>=0 && v->emit_left<1;}
double CanisSiriusFlame::progress(const TechniqueState &t,const BossTechniqueDefinition &base) {const auto &v=std::get<CanisSiriusFlameState>(t.detail);return v.started?1.0:std::clamp(v.age/std::max(base.warn,0.001),0.0,1.0);}
godot::Dictionary CanisSiriusFlame::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=std::get<CanisSiriusFlameState>(t.detail);godot::Dictionary out;out["started"]=v.started;out["age"]=v.age;out["emit_left"]=v.emit_left;out["windup_progress"]=progress(t,r.content->boss_techniques[t.definition-1]);out["glow"]=(t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active)?progress(t,r.content->boss_techniques[t.definition-1]):0.0;out["flame"]=(t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active);return out;}
}
