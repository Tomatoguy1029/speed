#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double TILT=0.6108652381980153,MOUTH=40; // 頭を35度傾けて撃つ
void place(RunRuntime &r,BossBodyState &b,HydraNeckState &n,const TechniqueState &t,double ext) {const auto &body=r.state.enemies[b.actor.slot];const double home=n.base_angle+body.facing,rest=HydraBody::rule(r,b).neck_rest,goal=rest*(1.3+0.035*std::sin(b.clock*2.6+n.base_angle*3)*ext);n.angle=home+std::remainder(n.sweep-home,6.283185307179586)*(1-ext);const double length=n.turn+(goal-n.turn)*ext;n.strike_pos=HydraBody::neck_base(r,b,n)+godot::Vector2::from_angle(n.angle)*length;}
}
// 今の向きと長さから、予兆のあいだに首を弓なりに伸ばした形へなめらかに移る。
void HydraTechnique::curve_extend(RunRuntime &r,TechniqueState &t) {auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();const double k=std::clamp(t.elapsed/std::max(0.001,r.content->boss_techniques[t.definition-1].warn),0.0,1.0),ext=k*k*(3-2*k);for (auto actor:v.participants) {auto *n=HydraNormalAttack::neck(b,actor);if (!n || !HydraRegrow::alive(r,*n)) continue;if (!n->locked) {n->sweep=(n->strike_pos-HydraBody::neck_base(r,b,*n)).angle();n->turn=n->strike_pos.distance_to(HydraBody::neck_base(r,b,*n));n->locked=true;}place(r,b,*n,t,ext);}}
void HydraTechnique::curve(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();const auto &p=*std::find_if(r.content->hydra_curves.begin(),r.content->hydra_curves.end(),[&](const auto &p){return p.technique==t.definition;});auto &body=r.state.enemies[b.actor.slot];if (t.elapsed>=r.content->boss_techniques[t.definition-1].warn) body.facing+=p.turn*dt;if (dt<=0) return;
    for (auto actor:v.participants) {auto *n=HydraNormalAttack::neck(b,actor);if (!n || !HydraRegrow::alive(r,*n)) continue;place(r,b,*n,t,1);const auto u=godot::Vector2::from_angle(n->angle-TILT),from=n->strike_pos+u*MOUTH;const std::vector<godot::Vector2> points{from,from+u*p.length};
        if (!n->emission.generation) n->emission=emit(r,t,actor,points,p.width,p.delay,p.time);else if (const auto *a=AttackSystem::get(r.state,n->emission)) {auto &h=r.state.hazards[a->row];std::get<HydraShapeHazard>(h.shape).points=points;h.pos=points.front();}
        if (v.time>=p.time) AttackSystem::end(r.state,n->emission,AttackEndReason::Lifetime);
    }
}
}
