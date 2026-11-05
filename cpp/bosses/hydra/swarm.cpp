#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "swim.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const HydraSwarmDefinition &swarm_rule(const RunRuntime &r,uint32_t definition) {return *std::find_if(r.content->hydra_swarms.begin(),r.content->hydra_swarms.end(),[&](const auto &p){return p.technique==definition;});}
}
void HydraTechnique::swarm_prepare(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();const auto &p=swarm_rule(r,t.definition);HydraSwarmState s;s.arrived.resize(v.participants.size(),false);godot::Rect2 arena,rect(r.state.view_center-r.state.view_half,r.state.view_half*2);for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) {arena=a.bounds;rect=rect.intersection(arena);}rect=rect.grow(-p.formation_margin);
    for (size_t i=0;i<v.participants.size();++i) {const double angle=6.283185307179586*i/v.participants.size();const auto slot=rect.get_center()+godot::Vector2(std::cos(angle)*rect.size.x*0.45,std::sin(angle)*rect.size.y*0.45);s.slots.push_back(FieldSystem::safe_point(r,arena,slot,r.state.enemies[v.participants[i].slot].radius+12));}v.move=s;
}
bool HydraTechnique::swarm_position(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();auto &s=std::get<HydraSwarmState>(v.move);const auto &p=swarm_rule(r,t.definition);s.position_elapsed+=dt;if (s.position_elapsed>p.formation_timeout) {finish(r,t,true);return false;}bool ready=true;
    for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n)) continue;if (!s.arrived[i]) HydraSwim::steer(r,b,*n,s.slots[i],dt,1.8,true);n->strike_pos=n->free_pos;r.state.enemies[n->actor.slot].pos=n->free_pos;if (n->free_pos.distance_to(s.slots[i])<=p.formation_tolerance) s.arrived[i]=true;if (!s.arrived[i]) ready=false;}
    if (!ready) return false;for (auto actor:v.participants) {const auto *n=HydraNormalAttack::neck(b,actor);if (n && HydraRegrow::alive(r,*n) && !godot::Rect2(r.state.view_center-r.state.view_half,r.state.view_half*2).grow(-r.state.enemies[actor.slot].radius).has_point(n->strike_pos)) {finish(r,t,true);return false;}}
    s.positioning=false;const auto &e=r.state.enemies[b.actor.slot];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};for (auto actor:v.participants) if (auto *n=HydraNormalAttack::neck(b,actor)) {n->strike_from=n->strike_pos;const auto direction=(tracking.target(n->strike_pos,n->angle,r.state.ship_pos)-n->strike_pos).normalized();n->target=n->strike_pos+direction*p.reach;if (auto hit=FieldSystem::arena_hit(r,n->strike_pos,n->target,r.state.enemies[actor.slot].radius)) n->target=hit->position;}return true;
}
void HydraTechnique::swarm(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();const auto &p=swarm_rule(r,t.definition);
    for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n)) continue;const double local=v.time-i*p.gap;if (local<0) continue;
        if (!n->emission.generation) {n->emission=emit(r,t,n->actor,{n->strike_from,n->target},p.radius,p.charge,0.001,Cause::Bite);if (const auto *a=AttackSystem::get(r.state,n->emission)) r.state.hazards[a->row].damage=0;}
        if (local<p.charge) continue;if (!n->locked) {n->locked=true;n->angle=(n->target-n->strike_from).angle();HydraNormalAttack::cue(r,b,*n,"target_locked",t.definition);HydraNormalAttack::cue(r,b,*n,"attack_started",t.definition);}
        const double fraction=std::clamp((local-p.charge)/p.flight,0.,1.);if (n->step!=2) {const auto before=n->strike_pos;n->strike_pos=n->strike_from.lerp(n->target,fraction);n->free_pos=n->strike_pos;emit(r,t,n->actor,{before,n->strike_pos},p.radius,0,dt+0.001,Cause::Bite);if (fraction>=1) n->step=2;}
    }
}
}
