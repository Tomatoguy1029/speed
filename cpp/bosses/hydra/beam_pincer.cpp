#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include <algorithm>
namespace speed {
void HydraTechnique::pincer(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);auto &state=std::get<HydraPincerState>(v.move);const auto &p=*std::find_if(r.content->hydra_pincers.begin(),r.content->hydra_pincers.end(),[&](const auto &p){return p.technique==t.definition;});
    const auto &body=r.state.enemies[b.actor.slot];const bool locked=TrackingPolicy{r.state.draw.tracing,body.held,r.state.enemy_handles.contains(body.pump_owner)}.locked();if (state.aims.empty()) for (auto actor:v.participants) {const auto &n=*HydraNormalAttack::neck(b,actor);state.aims.push_back(locked?n.angle:(r.state.ship_pos-n.strike_pos).angle());}
    for (size_t j=0;j<v.participants.size();++j) {auto &n=*HydraNormalAttack::neck(b,v.participants[j]);const double side=j==0?1:-1,f=std::clamp((v.time-p.delay)/p.time,0.,1.);n.angle=state.aims[j]+side*(p.open_angle+(p.close_angle-p.open_angle)*f);const std::vector<godot::Vector2> points{n.strike_pos,n.strike_pos+godot::Vector2::from_angle(n.angle)*p.length};if (!n.emission.generation) n.emission=emit(r,t,n.actor,points,p.width,p.delay,p.time);else if (const auto *a=AttackSystem::get(r.state,n.emission)) {auto &h=r.state.hazards[a->row];std::get<HydraShapeHazard>(h.shape).points=points;h.pos=points.front();}}
}
}
