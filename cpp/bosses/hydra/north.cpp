#include "technique.h"
#include "body.h"
#include "normal_attack.h"
#include "regrow.h"
#include "../flow/phase_controller.h"
#include "../../systems/attack_system.h"
#include "../../systems/motion_math.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
namespace speed {
namespace {
const HydraNorthDefinition &north_rule(const RunRuntime &r,uint32_t id) {return *std::find_if(r.content->hydra_north.begin(),r.content->hydra_north.end(),[&](const auto &p){return p.technique==id;});}
bool locked(const RunRuntime &r,const BossBodyState &b) {const auto &e=r.state.enemies[b.actor.slot];return TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();}
void targets(RunRuntime &r,BossBodyState &b,TechniqueState &t) {
    auto &v=std::get<HydraTechniqueState>(t.detail);auto &s=std::get<HydraNorthState>(v.move);const auto &body=r.state.enemies[b.actor.slot];const TrackingPolicy tracking{r.state.draw.tracing,body.held,r.state.enemy_handles.contains(body.pump_owner)};s.target=tracking.target(body.pos,body.facing,r.state.ship_pos);const auto at=body.pos,direction=(s.target-at).normalized(),side=direction.orthogonal(),center=at+direction*std::max(double(s.target.distance_to(at)),r.state.enemies[b.actor.slot].radius+HydraBody::rule(r,b).neck_rest);auto ordered=v.participants;ordered.erase(std::remove_if(ordered.begin(),ordered.end(),[&](auto h){return HydraNormalAttack::neck(b,h)==nullptr;}),ordered.end());
    std::stable_sort(ordered.begin(),ordered.end(),[&](auto a,auto c){return HydraBody::neck_base(r,b,*HydraNormalAttack::neck(b,a)).dot(side)<HydraBody::neck_base(r,b,*HydraNormalAttack::neck(b,c)).dot(side);});
    for (size_t i=0;i<ordered.size();++i) {auto &n=*HydraNormalAttack::neck(b,ordered[i]);n.target=tracking.target(HydraBody::head_position(r,b,n),n.angle,center+side*north_rule(r,t.definition).spread*(double(i)-1));}
}
void lunge(RunRuntime &r,BossBodyState &b,TechniqueState &t,HydraNeckState &n,double fraction,double dt) {
    const auto previous=n.strike_pos;n.strike_pos=n.strike_from.lerp(n.target,fraction);AttackSystem::end(r.state,n.emission,AttackEndReason::TechniqueEnd);n.glow=1;n.emission=HydraTechnique::emit(r,t,n.actor,{previous,n.strike_pos},north_rule(r,t.definition).radius*2,0,std::max(dt,0.001)+0.001,Cause::Bite);if (fraction>=1) n.step=2;
}
}
std::vector<EnemyHandle> HydraTechnique::front_heads(const RunRuntime &r,const BossBodyState &b,uint32_t definition) {
    if (b.hydra.necks.size()<5) return {};const auto &e=r.state.enemies[b.actor.slot];const double aim=(r.state.ship_pos-e.pos).angle();std::vector<const HydraNeckState*> ordered;for (const auto &n:b.hydra.necks) ordered.push_back(&n);
    std::stable_sort(ordered.begin(),ordered.end(),[&](auto a,auto c){return std::abs(angle_difference(a->base_angle+e.facing-aim))<std::abs(angle_difference(c->base_angle+e.facing-aim));});std::vector<EnemyHandle> result;
    for (const auto *n:ordered) {if (HydraRegrow::alive(r,*n) && std::abs(angle_difference(n->base_angle+e.facing-aim))<north_rule(r,definition).half_angle+3.141592653589793/b.hydra.necks.size()) result.push_back(n->actor);if (result.size()==3) break;}return result;
}
void HydraTechnique::north_prepare(RunRuntime &r,TechniqueState &t) {auto &b=*PhaseController::find(r,t.actor);targets(r,b,t);}
void HydraTechnique::north_body(RunRuntime &r,BossBodyState &b,double dt) {
    for (auto &t:r.state.bosses.techniques) if (same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished && r.content->boss_techniques[t.definition-1].kind==88) {
        auto &v=std::get<HydraTechniqueState>(t.detail);auto &s=std::get<HydraNorthState>(v.move);if (s.aiming) {auto &body=r.state.enemies[b.actor.slot];godot::Vector2 middle;for (auto h:v.participants) if (const auto *n=HydraNormalAttack::neck(b,h)) middle+=godot::Vector2::from_angle(n->base_angle);const double desired=(r.state.ship_pos-body.pos).angle()-middle.angle(),turn=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].turn*dt;if (!locked(r,b)) body.facing+=std::clamp(angle_difference(desired-body.facing),-turn,turn);targets(r,b,t);}
        for (auto h:v.participants) {auto *found=HydraNormalAttack::neck(b,h);if (!found) continue;auto &n=*found;if (!HydraRegrow::alive(r,n)) continue;n.elapsed+=dt;if (!s.burst) {const double direction=(n.target-HydraBody::neck_base(r,b,n)).angle();if (!locked(r,b)) n.angle+=angle_difference(direction-n.angle)*std::min(1.0,dt*6);const double rest=HydraBody::rule(r,b).neck_rest;n.length+=std::clamp(rest*0.35-n.length,-rest*dt*2,rest*dt*2);n.glow=std::min(1.0,n.glow+dt*1.5);}else if (n.step<2) lunge(r,b,t,n,std::min(1.0,n.elapsed/std::max(0.001,north_rule(r,t.definition).flight)),dt);}
    }
}
void HydraTechnique::north_timeline(RunRuntime &r,TechniqueState &t,double dt) {
    auto &b=*PhaseController::find(r,t.actor);auto &v=std::get<HydraTechniqueState>(t.detail);auto &s=std::get<HydraNorthState>(v.move);const auto &p=r.content->boss_techniques[t.definition-1];const auto &n=north_rule(r,t.definition);t.elapsed+=dt;
    if (s.aiming && t.elapsed>=n.lock_time) {targets(r,b,t);s.aiming=false;cue(r,b,"target_locked",t.definition);}
    if (!s.burst && t.elapsed>=p.warn) {s.aiming=false;s.burst=true;v.playing=true;t.stage=TechniqueStage::Active;cue(r,b,"attack_started",t.definition);for (auto h:v.participants) {auto *found=HydraNormalAttack::neck(b,h);if (!found) continue;auto &neck=*found;if (!HydraRegrow::alive(r,neck)) continue;neck.strike_from=HydraBody::head_position(r,b,neck);neck.strike_pos=neck.strike_from;if (locked(r,b)) neck.target=neck.strike_from+godot::Vector2::from_angle(neck.angle)*std::max(1.0,double(neck.strike_from.distance_to(neck.target)));neck.locked=true;neck.elapsed=0;neck.step=1;neck.angle=(neck.target-neck.strike_from).angle();HydraNormalAttack::cue(r,b,neck,"attack_started",t.definition);}}
    if (!s.followed && t.elapsed>=p.warn+n.flight) {s.followed=true;for (auto h:v.participants) {auto *found=HydraNormalAttack::neck(b,h);if (!found) continue;auto &neck=*found;if (HydraRegrow::alive(r,neck) && neck.step==1) lunge(r,b,t,neck,1,dt);}}
    if (t.elapsed>=p.warn+p.active) {finish(r,t,false);return;}
    if (b.hydra.separated || !all_participants_alive(r,v)) finish(r,t,true);
}
godot::Array HydraTechnique::north_targets(const RunRuntime &r,const BossBodyState &b) {
    godot::Array out;for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished && r.content->boss_techniques[t.definition-1].kind==88) {const auto &v=std::get<HydraTechniqueState>(t.detail);const auto &s=std::get<HydraNorthState>(v.move);if (s.burst) continue;for (auto h:v.participants) {const auto it=std::find_if(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &n){return same_handle(n.actor,h);});if (it==b.hydra.necks.end() || !HydraRegrow::alive(r,*it)) continue;godot::Dictionary x;x["from"]=HydraBody::head_position(r,b,*it);x["target"]=it->target;x["radius"]=north_rule(r,t.definition).radius;x["locked"]=!s.aiming;out.push_back(x);}}return out;
}
}
