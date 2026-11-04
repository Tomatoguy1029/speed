#include "sequence.h"
#include "howl.h"
#include "technique_common.h"
#include "hound_lunge.h"
#include "../flow/phase_controller.h"
#include "../../systems/group_system.h"
#include <algorithm>
namespace speed {
std::vector<EnemyHandle> CanisSequence::shuffled(RunRuntime &r,const BossBodyState &b) {std::vector<EnemyHandle> rows;for (const auto &v:b.canis.led) if (r.state.enemy_handles.contains(v.actor) && !r.state.enemies[v.actor.slot].dead && !CanisHowl::in_ring(b,v.actor)) rows.push_back(v.actor);for (size_t k=rows.size();k>1;--k) {const auto j=r.state.control.rng.randi_range(0,k-1).value();std::swap(rows[k-1],rows[j]);}return rows;}
double CanisSequence::begin(std::vector<CanisSequenceItem> &out,const std::vector<EnemyHandle> &rows,double start,double interval,double warn) {out.clear();for (size_t k=0;k<rows.size();++k) out.push_back({rows[k],start+k*interval,start+k*interval+warn,false,false});return start+std::max(0,int(rows.size())-1)*interval+warn;}
void CanisSequence::tick(RunRuntime &r,TechniqueState &t,BossBodyState &b,std::vector<CanisSequenceItem> &sequence,double speed,double duration,double damage,const char *prefix,bool manual_retained) {
    for (auto &v:sequence) {if (!r.state.enemy_handles.contains(v.actor) || r.state.enemies[v.actor.slot].dead) continue;if (!v.marked && b.clock>=v.mark) {v.marked=true;GroupSystem::mark(r.state,v.actor,r.state.world_time+std::max(0.0,v.launch-b.clock));CanisTechnique::cue(r,t,(std::string(prefix)+"_mark").c_str(),v.actor);}if (!v.launched && b.clock>=v.launch) {v.launched=true;HoundLungeSettings p;p.speed=speed;p.duration=duration;p.damage=damage;p.technique=r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data()));p.source_technique=t.definition;p.manual_retained=manual_retained;CanisHoundLunge::begin(r,b,v.actor,t.id,p);auto &ring=b.canis.ring;ring.erase(std::remove_if(ring.begin(),ring.end(),[&](const auto &n){return same_handle(n.actor,v.actor);}),ring.end());CanisTechnique::cue(r,t,(std::string(prefix)+"_launch").c_str(),v.actor);}}
}
void CanisSequence::cancel(RunRuntime &r,TechniqueState &t,std::vector<CanisSequenceItem> &sequence) {for (const auto &v:sequence) if (r.state.enemy_handles.contains(v.actor)) GroupSystem::release_order(r.state,v.actor);if (auto *b=PhaseController::find(r,t.actor)) CanisHoundLunge::end_action(r,*b,t.id,true);sequence.clear();}
}
