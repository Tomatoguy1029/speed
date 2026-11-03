#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include <algorithm>
namespace speed {
void HydraTechnique::curve(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);const auto &p=*std::find_if(r.content->hydra_curves.begin(),r.content->hydra_curves.end(),[&](const auto &p){return p.technique==t.definition;});auto &body=r.state.enemies[b.actor.slot];body.facing+=p.turn*dt;
    for (auto actor:v.participants) {auto *n=HydraNormalAttack::neck(b,actor);if (!n || !HydraRegrow::alive(r,*n)) continue;n->angle=n->base_angle+body.facing;n->strike_pos=HydraBody::neck_base(r,b,*n)+godot::Vector2::from_angle(n->angle)*HydraBody::rule(r,b).neck_rest;n->locked=true;
        std::vector<godot::Vector2> points{n->strike_pos};for (int j=1;j<=24;++j) points.push_back(points.back()+godot::Vector2::from_angle(n->angle-double(j)/24*p.lag)*(p.length/24));
        if (!n->emission.generation) n->emission=emit(r,t,actor,points,p.width,p.delay,p.time);else if (const auto *a=AttackSystem::get(r.state,n->emission)) {auto &h=r.state.hazards[a->row];std::get<HydraShapeHazard>(h.shape).points=points;h.pos=points.front();}
        if (v.time>=p.time) AttackSystem::end(r.state,n->emission,AttackEndReason::Lifetime);
    }
}
}
