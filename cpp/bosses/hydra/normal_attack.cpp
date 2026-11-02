#include "normal_attack.h"
#include "squad.h"
#include "body.h"
#include "regrow.h"
#include "swim.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/motion_math.h"
#include "../../systems/tracking_policy.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
BossBodyState *HydraNormalAttack::body(RunRuntime &r,EnemyHandle actor) {if (!actor.generation) return nullptr;for (auto &b:r.state.bosses.bodies) {if (!b.hydra.necks.empty() && same_handle(b.actor,actor)) return &b;if (same_handle(b.hydra.bearer.actor,actor)) return &b;for (auto &n:b.hydra.necks) if (same_handle(n.actor,actor)) return &b;}return nullptr;}
HydraNeckState *HydraNormalAttack::neck(BossBodyState &b,EnemyHandle actor) {if (same_handle(b.hydra.bearer.actor,actor)) return &b.hydra.bearer;for (auto &n:b.hydra.necks) if (same_handle(n.actor,actor)) return &n;return nullptr;}
void HydraNormalAttack::cue(RunRuntime &r,const BossBodyState &b,const HydraNeckState &n,const char *name,uint32_t definition,double damage,double duration) {godot::Dictionary e;e["id"]=r.state.enemy_handles.entity_id(b.actor);e["cue"]=name;e["technique"]=definition?godot::String(r.content->boss_techniques[definition-1].external_id.c_str()):godot::String("");e["neck"]=&n==&b.hydra.bearer?-2:int32_t(&n-b.hydra.necks.data());e["position"]=HydraBody::head_position(r,b,n);e["duration"]=duration;e["damage"]=damage;e["next_count"]=0;e["target"]="hydra";FrameBuilder::append(r,"hydra_cue",e);}
void HydraNormalAttack::aim(RunRuntime &r,BossBodyState &b,HydraNeckState &n,double desired,double dt) {
    const auto &e=r.state.enemies[b.actor.slot];if (dt<=0 || TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) return;
    if (b.hydra.separated && &n!=&b.hydra.bearer) {n.look_angle+=std::clamp(angle_difference(desired-n.look_angle),-HydraSwim::rule(r,b).look_player_turn*dt,HydraSwim::rule(r,b).look_player_turn*dt);return;}
    const auto &p=HydraBody::rule(r,b);const double diff=angle_difference(desired-n.angle),speed=std::min(p.aim_turn,std::sqrt(2*p.aim_accel*std::abs(diff)));n.aim_velocity+=std::clamp((diff>0?speed:diff<0?-speed:0)-n.aim_velocity,-p.aim_accel*dt,p.aim_accel*dt);double move=n.aim_velocity*dt;if (move*diff>=0 && std::abs(move)>std::abs(diff)) move=diff;n.angle+=move;n.aim_velocity=move/dt;
}
bool HydraNormalAttack::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;
    const auto it=std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==definition;});if (it==r.content->hydra_normals.end()) return false;
    for (const auto &b:r.state.bosses.bodies) {const HydraNeckState *n=nullptr;if (same_handle(b.hydra.bearer.actor,actor)) n=&b.hydra.bearer;for (const auto &v:b.hydra.necks) if (same_handle(v.actor,actor)) n=&v;if (!n) continue;
        if (b.hydra.separated && n==&b.hydra.bearer && b.hydra.separation_left<=0 && n->cd<=0 && !n->normal && std::none_of(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &v){return r.state.enemy_handles.contains(v.actor) && !r.state.enemies[v.actor.slot].dead;})) return true;
        if (b.mode!=BossMode::Idle || b.hydra.growth_left>0 || b.hydra.chance_left>0 || b.hydra.recovery_left>0 || b.hydra.separation_pending || b.hydra.separation_left>0 || n->cd>0 || n->normal || (n!=&b.hydra.bearer && uint32_t(n->kind)!=it->head_kind)) return false;

        const auto head=HydraBody::head_position(r,b,*n),base=HydraBody::neck_base(r,b,*n),center=r.state.enemies[b.actor.slot].pos;if (!godot::Rect2(r.state.view_center-r.state.view_half,r.state.view_half*2).grow(-r.state.enemies[actor.slot].radius).has_point(head)) return false;
        for (const auto &gate:r.content->hydra_normal_gates) if (gate.technique==definition) {const auto origin=gate.distance_origin==1?head:gate.distance_origin==2?base:center;const double distance=r.state.ship_pos.distance_to(origin);const auto angular_origin=gate.angle_origin==1?base:center;const double facing=r.state.enemies[b.actor.slot].facing+(gate.angle_origin==1?n->base_angle:0);if (distance>=gate.minimum && distance<=gate.maximum && (b.hydra.separated && gate.ignore_when_separated || std::abs(angle_difference((r.state.ship_pos-angular_origin).angle()-facing-gate.angle))<=gate.half_angle+0.00001)) return true;}return false;
    }return false;
}
bool HydraNormalAttack::reserve(RunRuntime &r,EnemyHandle actor,uint32_t definition) {if (const auto *b=body(r,actor)) if (b->hydra.separated && same_handle(b->hydra.bearer.actor,actor)) return true;if (r.state.world.attack_formation_mode) return true;const auto &v=*std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==definition;});const auto &e=r.state.enemies[actor.slot];BudgetRequest request;request.owner="neck:"+std::to_string(e.id);request.categories={AttackCategory::Dash};request.source=actor;request.duration=4;request.priority=e.attack_priority;request.cost=v.cost*std::max(0.0,e.attack_value);return AttackBudgetSystem(r).request(request);}
void HydraNormalAttack::begin(RunRuntime &r,TechniqueState &t) {auto *b=body(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}auto &n=*neck(*b,t.actor);n.normal=t.definition;n.elapsed=n.glow=0;n.locked=n.extension=n.lunge_done=false;n.normal_phase=0;n.target=r.state.ship_pos;const auto &e=r.state.enemies[b->actor.slot];if (TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) {const auto at=HydraBody::head_position(r,*b,n);n.target=at+godot::Vector2::from_angle(b->hydra.separated?n.look_angle:n.angle)*std::max(1.0,double(at.distance_to(n.target)));}t.aim=n.target;t.started_at=r.state.world_time;t.previous_ship=r.state.ship_pos;cue(r,*b,n,"warning_started",t.definition);}
void HydraNormalAttack::cancel(RunRuntime &r,TechniqueState &t) {auto *b=body(r,t.actor);if (!b) return;auto *n=neck(*b,t.actor);if (!n || !n->normal) return;const auto at=HydraBody::head_position(r,*b,*n);n->strike_pos=n->free_pos=at;n->normal=0;n->locked=n->extension=false;n->glow=0;cue(r,*b,*n,"interrupted",t.definition);}
godot::Array HydraNormalAttack::shapes(const RunRuntime &r,const BossBodyState &b) {godot::Array out;for (const auto &h:r.state.hazards) {const auto *v=std::get_if<HydraShapeHazard>(&h.shape);const auto *a=AttackSystem::get(r.state,h.attack);if (!h.alive || !v || !a || !same_handle(a->spec.boss,r.state.bosses.body_handles.at(uint32_t(&b-r.state.bosses.bodies.data())))) continue;godot::Dictionary x;x["id"]=a->id;x["kind"]="bite";godot::PackedVector2Array points;for (const auto p:v->points) points.push_back(p);x["points"]=points;x["width"]=v->width;x["age"]=h.time;x["delay"]=h.delay;x["life"]=h.duration;out.push_back(x);}return out;}
}
