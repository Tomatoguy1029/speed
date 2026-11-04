#include "stream.h"
#include "sequence.h"
#include "technique_common.h"
#include "hound_lunge.h"
#include "roar.h"
#include "../flow/phase_controller.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {const CanisStreamDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.canis_streams.begin(),c.canis_streams.end(),[&](const auto &v){return v.technique==definition;});}}
double CanisStream::order_start(const ContentBundle &c,uint32_t technique,double warn) {
    const auto *fx=CanisRoar::settings(c,technique);if (!fx) return warn;
    const double lives[]={0,.24,.36,.52};
    return warn-std::min(warn*.65,.32)+lives[fx->level]*fx->roar_time*fx->timing+fx->order_wait;
}
double CanisStream::hound_warning(const ContentBundle &c,uint32_t technique,double fallback) {const auto *fx=CanisRoar::settings(c,technique);return fx?fx->hound_warn:fallback;}
bool CanisStream::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && !b->canis.barking && !b->canis.calling && b->canis.led.size()>=rule(*r.content,definition).min_hounds;}
double CanisStream::attack_length(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto &p=rule(*r.content,definition);const auto *b=PhaseController::find(r,actor);const auto *fx=CanisRoar::settings(*r.content,definition);return order_start(*r.content,definition,r.content->boss_techniques[definition-1].warn)+std::max(0,int(b?b->canis.led.size():0)-1)*p.interval+(fx?fx->hound_warn:p.each_warn)+p.lunge_time+0.05;}
void CanisStream::start(RunRuntime &r,TechniqueState &t,CanisStreamState &v,uint32_t definition) {v={};v.definition=definition;v.started=PhaseController::find(r,t.actor)->clock;t.stage=TechniqueStage::Windup;r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"stream_windup");}
void CanisStream::begin(RunRuntime &r,TechniqueState &t) {t.detail=CanisStreamState{};start(r,t,std::get<CanisStreamState>(t.detail),t.definition);}
bool CanisStream::advance(RunRuntime &r,TechniqueState &t,CanisStreamState &v,double dt,bool manual_retained) {auto *b=PhaseController::find(r,t.actor);if (!b) return true;const auto &p=rule(*r.content,v.definition);const auto &base=r.content->boss_techniques[v.definition-1];const auto *fx=CanisRoar::settings(*r.content,t.definition);r.state.enemies[t.actor.slot].vel={};if (!v.sent) {CanisTechnique::face(r,t,r.state.enemy_aim,r.content->bosses[base.boss-1].turn,dt);if (b->clock-v.started<order_start(*r.content,t.definition,base.warn)) return false;v.sent=true;t.stage=TechniqueStage::Active;v.last_launch=CanisSequence::begin(v.sequence,CanisSequence::shuffled(r,*b),b->clock,p.interval,fx?fx->hound_warn:p.each_warn);}CanisSequence::tick(r,t,*b,v.sequence,p.lunge_speed,p.lunge_time,base.damage,"stream",manual_retained);CanisHoundLunge::step(r,*b,t.id);return b->clock>=v.last_launch+p.lunge_time;}
void CanisStream::step(RunRuntime &r,TechniqueState &t,double dt) {auto &v=std::get<CanisStreamState>(t.detail);if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}if (advance(r,t,v,dt)) {t.stage=TechniqueStage::Recovery;t.remaining=r.content->boss_techniques[v.definition-1].recover;t.locked=false;r.state.enemies[t.actor.slot].vel={};CanisTechnique::cue(r,t,"recovery_started");}}
void CanisStream::cancel(RunRuntime &r,TechniqueState &t) {CanisSequence::cancel(r,t,std::get<CanisStreamState>(t.detail).sequence);}
bool CanisStream::validate(const TechniqueState &t,const ContentBundle &c) {return std::holds_alternative<CanisStreamState>(t.detail) && validate(std::get<CanisStreamState>(t.detail),c);}
bool CanisStream::validate(const CanisStreamState &state,const ContentBundle &c) {const auto *v=&state;if ( !v->definition || v->definition>c.boss_techniques.size() || c.boss_techniques[v->definition-1].kind!=46 || !std::isfinite(v->started) || v->started<0 || !std::isfinite(v->last_launch) || v->last_launch<0) return false;for (const auto &q:v->sequence) if (!std::isfinite(q.mark) || !std::isfinite(q.launch) || q.mark<0 || q.launch<q.mark) return false;return true;}
godot::Dictionary CanisStream::snapshot(const RunRuntime &r,const TechniqueState &t) {return snapshot(r,t.actor,std::get<CanisStreamState>(t.detail));}
godot::Dictionary CanisStream::snapshot(const RunRuntime &r,EnemyHandle actor,const CanisStreamState &v) {const auto *b=PhaseController::find(r,actor);godot::Dictionary out;out["sent"]=v.sent;out["sequence_started"]=v.started;out["last_launch"]=v.last_launch;out["windup_progress"]=v.sent?1:std::clamp(((b?b->clock:0)-v.started)/std::max(0.001,r.content->boss_techniques[v.definition-1].warn),0.0,1.0);godot::Array rows;for (const auto &q:v.sequence) {godot::Dictionary item;item["actor"]=r.state.enemy_handles.entity_id(q.actor);item["mark"]=q.mark;item["launch"]=q.launch;item["marked"]=q.marked;item["launched"]=q.launched;rows.push_back(item);}out["sequence"]=rows;return out;}
}
