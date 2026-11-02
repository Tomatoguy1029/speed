#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "../flow/phase_controller.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
namespace speed {
void HydraTechnique::sequence_prepare(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);const auto &e=r.state.enemies[b.actor.slot];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};for (auto h:std::get<HydraTechniqueState>(t.detail).participants) if (auto *n=HydraNormalAttack::neck(b,h)) n->target=tracking.target(n->strike_pos,n->angle,r.state.ship_pos);
}
void HydraTechnique::sequence(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);const auto &p=*std::find_if(r.content->hydra_sequences.begin(),r.content->hydra_sequences.end(),[&](const auto &p){return p.technique==t.definition;});const auto &e=r.state.enemies[b.actor.slot];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n)) continue;const double local=v.time-i*p.gap;if (local<0) continue;
        if (!n->locked) {if (r.content->boss_techniques[t.definition-1].track_during_warn && !tracking.locked()) n->target=r.state.ship_pos;if (local<p.charge) continue;n->target=tracking.target(n->strike_pos,n->angle,n->target);n->locked=true;n->strike_from=n->strike_pos;n->angle=(n->target-n->strike_from).angle();HydraNormalAttack::cue(r,b,*n,"target_locked",t.definition);HydraNormalAttack::cue(r,b,*n,"attack_started",t.definition);}
        const double fraction=std::clamp((local-p.charge)/p.lunge,0.,1.);if (n->step!=2) {const auto before=n->strike_pos;n->strike_pos=n->strike_from.lerp(n->target,fraction);emit(r,t,n->actor,{before,n->strike_pos},p.radius*2,0,std::max(dt,0.02)+0.001,Cause::Bite);if (fraction>=1) n->step=2;}
    }
}
}
