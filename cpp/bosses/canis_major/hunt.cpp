#include "hunt.h"
#include "stream.h"
#include "sequence.h"
#include "flame_aim.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include <algorithm>
namespace speed {
namespace {
const CanisHuntDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.canis_hunts.begin(),c.canis_hunts.end(),[&](const auto &v){return v.technique==definition;});}
CanisFlameAimSettings aim_settings(const CanisHuntDefinition &p) {return {p.aim_warn,p.aim_lock,p.aim_lead,p.aim_turn,p.flame,false};}
void remember_stream(RunRuntime &r,const TechniqueState &t,const BossBodyState &b) {for (auto &f:r.state.bosses.flows) for (const auto &node:r.content->flow_nodes) if (node.kind==1 && node.participant<f.participants.size() && same_handle(f.participants[node.participant],t.actor) && r.content->boss_techniques[node.technique-1].external_id=="stream") f.cooldown_started[uint64_t(node.participant)<<32|node.technique]=b.clock;}
}
bool CanisHunt::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && !b->canis.barking && !b->canis.calling && b->canis.led.size()>=rule(*r.content,definition).min_hounds;}
double CanisHunt::attack_length(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto &p=rule(*r.content,definition);const auto *b=PhaseController::find(r,actor);const auto &stream=*std::find_if(r.content->canis_streams.begin(),r.content->canis_streams.end(),[&](const auto &v){return v.technique==p.stream;});return r.content->boss_techniques[p.stream-1].warn+std::max(0,int(b?b->canis.led.size():0)-1)*stream.interval+stream.each_warn+p.gap+p.aim_warn+r.content->canis_flames[p.flame-1].duration+0.1;}
void CanisHunt::begin(RunRuntime &r,TechniqueState &t) {t.detail=CanisHuntState{};auto &v=std::get<CanisHuntState>(t.detail);remember_stream(r,t,*PhaseController::find(r,t.actor));CanisStream::start(r,t,v.stream,rule(*r.content,t.definition).stream);}
void CanisHunt::step(RunRuntime &r,TechniqueState &t,double dt) {auto &v=std::get<CanisHuntState>(t.detail);const auto &p=rule(*r.content,t.definition);const auto *b=PhaseController::find(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}if (t.stage==TechniqueStage::Recovery) {r.state.enemies[t.actor.slot].vel={};t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}CanisStream::advance(r,t,v.stream,dt);if (v.combo_pending && v.stream.sent && b->clock>=v.stream.last_launch+p.gap) {v.combo_pending=false;v.aiming=true;CanisFlameAim::begin(r,t,v.aim);}if (v.aiming && CanisFlameAim::advance(r,t,v.aim,aim_settings(p),dt)) {t.stage=TechniqueStage::Recovery;t.remaining=r.content->boss_techniques[t.definition-1].recover;t.locked=false;r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"recovery_started");}}
void CanisHunt::cancel(RunRuntime &r,TechniqueState &t) {auto &v=std::get<CanisHuntState>(t.detail);CanisSequence::cancel(r,t,v.stream.sequence);v.combo_pending=false;}
bool CanisHunt::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=std::get_if<CanisHuntState>(&t.detail);return v && CanisStream::validate(v->stream,c) && CanisFlameAim::validate(v->aim) && !(v->combo_pending && v->aiming);}
double CanisHunt::progress(const RunRuntime &r,const TechniqueState &t) {const auto &v=std::get<CanisHuntState>(t.detail);if (v.aiming) return CanisFlameAim::progress(v.aim,rule(*r.content,t.definition).aim_warn);const auto *b=PhaseController::find(r,t.actor);return b?std::clamp((b->clock-v.stream.started)/std::max(0.001,r.content->boss_techniques[v.stream.definition-1].warn),0.0,1.0):0;}
godot::Dictionary CanisHunt::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &v=std::get<CanisHuntState>(t.detail);auto out=CanisStream::snapshot(r,t.actor,v.stream);out["aiming"]=v.aiming;out["combo_pending"]=v.combo_pending;out["windup_progress"]=progress(r,t);if (v.aiming) {const auto aim=CanisFlameAim::snapshot(r,t,v.aim,aim_settings(rule(*r.content,t.definition)));for (const auto &key:aim.keys()) out[key]=aim[key];}return out;}
}
