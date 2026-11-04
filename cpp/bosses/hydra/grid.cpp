#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "swim.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/field.h"
#include "../../systems/collision_query.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
using V=godot::Vector2;
constexpr double pi=3.141592653589793;
const HydraGridDefinition &grid_rule(const RunRuntime &r,uint32_t definition) {return *std::find_if(r.content->hydra_grids.begin(),r.content->hydra_grids.end(),[&](const auto &v){return v.technique==definition;});}
double distance(V point,V a,V b) {const auto d=b-a;return point.distance_to(a+d*(d.length_squared()>0?std::clamp(double((point-a).dot(d)/d.length_squared()),0.,1.):0));}
bool crosses(V a,V b,V c,V d) {const auto u=b-a,v=d-c;const float denominator=u.cross(v);if (denominator==0) return false;const float s=(c-a).cross(v)/denominator,t=(c-a).cross(u)/denominator;return s>=0 && s<=1 && t>=0 && t<=1;}
bool clear(const HydraGridPlan &plan,double radius) {for (size_t i=1;i<plan.path.size();++i) for (size_t j=0;j<plan.starts.size();++j) {const auto a=plan.path[i-1],b=plan.path[i],c=plan.starts[j],d=plan.ends[j];if (crosses(a,b,c,d) || distance(a,c,d)<radius || distance(b,c,d)<radius || distance(c,a,b)<radius || distance(d,a,b)<radius) return false;}return true;}
}
std::optional<HydraGridPlan> HydraTechnique::grid_plan(const RunRuntime &r,const BossBodyState &b,uint32_t definition) {
    if (!b.hydra.separated || !HydraRegrow::alive(r,b.hydra.bearer)) return {};const auto &p=grid_rule(r,definition);const size_t count=std::count_if(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &n){return HydraRegrow::alive(r,n);});if (count<p.minimum) return {};
    godot::Rect2 rect(r.state.view_center-r.state.view_half,r.state.view_half*2);for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) rect=rect.intersection(a.bounds);if (!rect.has_area()) return {};
    const auto player=r.state.ship_pos,rel=(player-rect.get_center())/(rect.size*0.5);const uint32_t region=std::abs(rel.x)<=0.25 && std::abs(rel.y)<=0.25?0:std::abs(rel.x)>std::abs(rel.y)?rel.x>0?1:2:rel.y>0?4:3;
    const auto layout=std::find_if(r.content->hydra_grid_layouts.begin(),r.content->hydra_grid_layouts.end(),[&](const auto &v){return v.technique==definition && (v.region_mask&(1u<<region));});if (layout==r.content->hydra_grid_layouts.end()) return {};
    std::vector<V> path,starts,ends;for (const auto &v:r.content->hydra_grid_paths) if (v.layout==layout->id) path.emplace_back(v.x,v.y);for (const auto &v:r.content->hydra_grid_slots) if (v.layout==layout->id && starts.size()<count) {starts.emplace_back(v.from_x,v.from_y);ends.emplace_back(v.to_x,v.to_y);}if (starts.size()!=count || path.empty()) return {};
    const double radius=r.state.ship_config.ship_radius,budget=r.state.draw_config.length*r.state.draw_config.capacity*r.state.draw_config.length_mult*r.state.ship_config.max_speed/r.state.ship_config.base_max_speed;const double preferred=region==1?pi:region==3?pi*0.5:region==4?-pi*0.5:0;const auto safe=rect.grow(-radius-p.planning_width*0.5-8);
    for (double rotation:{preferred,preferred+pi*0.5,preferred-pi*0.5,preferred+pi}) for (double scale:{1.,0.9,0.8}) {
        std::vector<V> offsets;for (auto v:path) offsets.push_back((v*scale).rotated(rotation));for (size_t i=0;i<starts.size();++i) {offsets.push_back((starts[i]*scale).rotated(rotation));offsets.push_back((ends[i]*scale).rotated(rotation));}godot::Rect2 extent(offsets.front(),{});for (auto v:offsets) extent=extent.expand(v);if (extent.size.x>safe.size.x || extent.size.y>safe.size.y) continue;
        const auto origin=player.clamp(safe.position-extent.position,safe.get_end()-extent.get_end());HydraGridPlan plan;plan.layout=layout->id;plan.region=region;plan.path={player};for (auto v:path) {const auto at=origin+(v*scale).rotated(rotation);if (plan.path.back().distance_to(at)>0.01) plan.path.push_back(at);}for (size_t i=0;i<starts.size();++i) {plan.starts.push_back(origin+(starts[i]*scale).rotated(rotation));plan.ends.push_back(origin+(ends[i]*scale).rotated(rotation));}
        bool inside=true;for (const auto *points:{&plan.path,&plan.starts,&plan.ends}) for (auto v:*points) if (!safe.has_point(v)) inside=false;for (size_t i=1;i<plan.path.size();++i) plan.length+=plan.path[i-1].distance_to(plan.path[i]);if (!inside || plan.length>budget || !clear(plan,radius+p.planning_width*0.5+p.clearance)) continue;plan.bearer=plan.path.back();
        double head_radius=0;for (const auto &n:b.hydra.necks) if (HydraRegrow::alive(r,n)) head_radius=std::max(head_radius,r.state.enemies[n.actor.slot].radius);for (const auto &obstacle:r.state.field.bodies) {if (plan.bearer.distance_to(obstacle.position)<obstacle.radius+r.state.enemies[b.hydra.bearer.actor.slot].radius) return {};for (auto at:plan.starts) if (at.distance_to(obstacle.position)<obstacle.radius+head_radius) return {};for (size_t i=1;i<plan.path.size();++i) if (CollisionQuery::segment_circle_t(plan.path[i-1],plan.path[i],obstacle.position,obstacle.radius+radius)>=0) return {};}
        return plan;
    }return {};
}
void HydraTechnique::grid_prepare(RunRuntime &r,TechniqueState &t) {auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);HydraGridState g;const auto plan=grid_plan(r,b,t.definition);if (!plan) {finish(r,t,true);return;}g.plan=*plan;g.arrived.resize(v.participants.size(),false);v.move=g;}
std::optional<V> HydraTechnique::bearer_target(const RunRuntime &r,const BossBodyState &b) {for (const auto &t:r.state.bosses->techniques) if (same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished && supports(r.content->boss_techniques[t.definition-1].kind)) if (const auto *v=std::get_if<HydraTechniqueState>(&t.detail)) if (const auto *g=std::get_if<HydraGridState>(&v->move)) return g->plan.bearer;return {};}
bool HydraTechnique::grid_position(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);auto &g=std::get<HydraGridState>(v.move);const auto &p=grid_rule(r,t.definition);g.position_elapsed+=dt;if (g.position_elapsed>p.formation_timeout) {finish(r,t,true);return false;}bool ready=true;
    for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n)) continue;const auto slot=g.plan.starts[i];if (!g.arrived[i]) {if (n->free_pos.distance_to(slot)<45) {n->velocity=(slot-n->free_pos).limit_length(100);n->free_pos+=n->velocity*dt*4;}else HydraSwim::steer(r,b,*n,slot,dt,1.8,true);}n->strike_pos=n->free_pos;r.state.enemies[n->actor.slot].pos=n->free_pos;if (n->free_pos.distance_to(slot)<=p.tolerance) g.arrived[i]=true;if (!g.arrived[i]) ready=false;}
    if (b.hydra.bearer.free_pos.distance_to(g.plan.bearer)>p.tolerance) ready=false;if (!ready) return false;for (auto actor:v.participants) {auto *n=HydraNormalAttack::neck(b,actor);if (n && HydraRegrow::alive(r,*n) && !godot::Rect2(r.state.view_center-r.state.view_half,r.state.view_half*2).grow(-r.state.enemies[actor.slot].radius).has_point(n->strike_pos)) {finish(r,t,true);return false;}}
    g.positioning=false;for (auto actor:v.participants) if (auto *n=HydraNormalAttack::neck(b,actor)) n->strike_from=n->strike_pos;return true;
}
void HydraTechnique::grid(RunRuntime &r,TechniqueState &t) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);auto &g=std::get<HydraGridState>(v.move);const auto &p=grid_rule(r,t.definition);for (size_t i=0;i<v.participants.size();++i) {auto *n=HydraNormalAttack::neck(b,v.participants[i]);if (!n || !HydraRegrow::alive(r,*n) || n->emission.generation) continue;const std::vector<V> points{n->strike_pos,g.plan.ends[i]};n->angle=(points[1]-points[0]).angle();n->emission=emit(r,t,n->actor,points,p.width,p.delay,p.time);HydraNormalAttack::cue(r,b,*n,"attack_started",t.definition);}
}
}
