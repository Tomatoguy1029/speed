#include "sirius.h"
#include "flames.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/field.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CanisSiriusDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.canis_sirius.begin(),c.canis_sirius.end(),[&](const auto &v){return v.technique==definition;});}
void start_shot(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<CanisSiriusState>();v.age=0;v.fired=false;t.locked=false;t.stage=TechniqueStage::Windup;CanisTechnique::cue(r,t,"telegraph");}
}
bool CanisSirius::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && !b->canis->barking && !b->canis->calling && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && std::any_of(r.content->canis_sirius.begin(),r.content->canis_sirius.end(),[&](const auto &p){return p.technique==definition;});}
double CanisSirius::attack_length(const RunRuntime &r,uint32_t definition) {const auto &p=rule(*r.content,definition);const auto &base=r.content->boss_techniques[definition-1];return p.shots*(base.warn+base.active)+std::max(int64_t(0),int64_t(p.shots)-1)*p.shot_gap+0.1;}
void CanisSirius::begin(RunRuntime &r,TechniqueState &t) {t.detail=CanisSiriusState{};r.state.enemies[t.actor.slot].vel={};start_shot(r,t);}
void CanisSirius::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &v=t.detail.get<CanisSiriusState>();const auto &base=r.content->boss_techniques[t.definition-1];const auto &p=rule(*r.content,t.definition);auto &e=r.state.enemies[t.actor.slot];e.vel={};
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    if (v.gap_left>0) {v.gap_left-=dt;if (v.gap_left<=0) start_shot(r,t);return;}
    if (!v.fired) {
        if (!t.locked) {if (base.track_during_warn) {t.aim=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*p.lead);CanisTechnique::face(r,t,t.aim,p.aim_turn,dt);}if (v.age>=base.warn-p.lock) CanisTechnique::lock_aim(r,t,true);}
        v.age+=dt;if (v.age<base.warn) return;t.locked=true;t.direction=godot::Vector2::from_angle(e.facing);auto *b=PhaseController::find(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}CanisFlames::begin(r,*b,p.flame,{},0,t.definition);v.fired=true;v.age=0;t.stage=TechniqueStage::Active;CanisTechnique::cue(r,t,"sirius");return;
    }
    v.age+=dt;if (v.age<base.active) return;++v.shot;if (v.shot>=p.shots) {t.stage=TechniqueStage::Recovery;t.remaining=base.recover;t.locked=false;CanisTechnique::cue(r,t,"recovery_started");}else v.gap_left=std::max(0.001,p.shot_gap);
}
bool CanisSirius::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=t.detail.get_if<CanisSiriusState>();if (!v || !std::isfinite(v->age) || v->age<0 || !std::isfinite(v->gap_left)) return false;const auto p=std::find_if(c.canis_sirius.begin(),c.canis_sirius.end(),[&](const auto &v){return v.technique==t.definition;});return p!=c.canis_sirius.end() && v->shot<=std::max(uint32_t(1),p->shots);}
double CanisSirius::progress(const TechniqueState &t,const BossTechniqueDefinition &p) {const auto &v=t.detail.get<CanisSiriusState>();return !v.fired?std::clamp(v.age/std::max(p.warn,0.001),0.0,1.0):0;}
godot::Dictionary CanisSirius::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=t.detail.get<CanisSiriusState>();const auto &p=rule(*r.content,t.definition);const auto &flame=r.content->canis_flames[p.flame-1];godot::Dictionary out;out["shot"]=v.shot;out["age"]=v.age;out["gap_left"]=v.gap_left;out["fired"]=v.fired;out["windup_progress"]=progress(t,r.content->boss_techniques[t.definition-1]);out["beam_width"]=flame.width;out["warning_length"]=flame.length;double length=flame.length;if (r.state.enemy_handles.contains(t.actor)) {const auto &e=r.state.enemies[t.actor.slot];const auto from=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*0.84;if (const auto hit=FieldSystem::first_body_hit(r,from,from+godot::Vector2::from_angle(e.facing)*length,0)) length*=hit->t;}out["beam_length"]=length;return out;}
}
