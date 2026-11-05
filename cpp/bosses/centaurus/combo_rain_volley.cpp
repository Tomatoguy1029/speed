#include "combo_rain_volley.h"
#include "../flow/phase_controller.h"
#include "../flow/technique_runner.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
namespace speed {
namespace {
const CentaurusComboDefinition &rule(const ContentBundle &c,uint32_t definition) {return *std::find_if(c.centaurus_combos.begin(),c.centaurus_combos.end(),[&](const auto &v){return v.technique==definition;});}
uint32_t canonical(const ContentBundle &c,uint32_t definition) {const auto &p=c.boss_techniques[definition-1];for (const auto &v:c.boss_techniques) if (v.boss==p.boss && v.phase==1 && v.external_id==p.external_id) return v.id;return 0;}
void cooldown(RunRuntime &r,BossBodyState &b,uint32_t definition) {b.centaurus->cooldowns[canonical(*r.content,definition)]=b.clock+r.content->boss_techniques[definition-1].cd;}
}
bool CentaurusCombo::cooldown_ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);if (!b || r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind!=1) return true;const auto found=b->centaurus->cooldowns.find(canonical(*r.content,definition));return found==b->centaurus->cooldowns.end() || b->clock>=found->second;}
bool CentaurusCombo::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto &p=rule(*r.content,definition);return PhaseController::find(r,actor) && cooldown_ready(r,actor,definition) && TechniqueRunner::ready(r,actor,p.first) && TechniqueRunner::ready(r,actor,p.second);}
void CentaurusCombo::started(RunRuntime &r,TechniqueState &t,uint32_t definition) {auto *b=PhaseController::find(r,t.actor);if (!b || r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind!=1) return;cooldown(r,*b,definition);if (r.content->boss_techniques[definition-1].kind==16) {const auto &p=rule(*r.content,definition);cooldown(r,*b,p.first);cooldown(r,*b,p.second);}}
void CentaurusCombo::begin(RunRuntime &r,TechniqueState &t) {t.combo_definition=t.definition;t.combo_step=0;TechniqueRunner::begin_part(r,t,rule(*r.content,t.combo_definition).first);}
bool CentaurusCombo::advance(RunRuntime &r,TechniqueState &t,double dt) {if (!t.combo_waiting) return false;t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) {t.combo_step=1;TechniqueRunner::begin_part(r,t,rule(*r.content,t.combo_definition).second);}return true;}
void CentaurusCombo::transition(RunRuntime &r,TechniqueState &t) {if (t.combo_definition && t.combo_step==0 && !t.combo_waiting && t.stage==TechniqueStage::Recovery) {t.combo_waiting=true;t.remaining=rule(*r.content,t.combo_definition).gap;}}
bool CentaurusCombo::validate(const TechniqueState &t,const ContentBundle &c) {if (!t.combo_definition) return !t.combo_waiting && t.combo_step==0;if (t.combo_definition>c.boss_techniques.size() || c.boss_techniques[t.combo_definition-1].kind!=16 || t.combo_step>1) return false;const auto &p=rule(c,t.combo_definition);return t.definition==(t.combo_step==0?p.first:p.second) && (!t.combo_waiting || (t.combo_step==0 && (t.stage==TechniqueStage::Recovery || t.stage==TechniqueStage::Cancelled)));}
}
