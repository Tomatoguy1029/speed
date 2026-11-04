#include "finish.h"
#include "../flow/phase_controller.h"
#include "../flow/flow_runner.h"
#include "../flow/technique_runner.h"
#include "../../systems/attack_budget.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusBodyDefinition &rule(const RunRuntime &r,const BossBodyState &b) {return *std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &p){return p.body==b.definition;});}
uint32_t technique(const RunRuntime &r,const BossBodyState &b,const char *name) {const auto boss=r.content->boss_bodies[b.definition-1].boss;for (const auto &t:r.content->boss_techniques) if (t.boss==boss && t.phase==b.phase && t.external_id==name) return t.id;return 0;}
void cue(RunRuntime &r,const BossBodyState &b,const char *name) {const auto &e=r.state.enemies[b.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=0;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);}
bool conditional(const RunRuntime &r,const BossBodyState &b,const BossFlowState &f,const char *name) {const auto id=technique(r,b,name);if (!id || !PhaseController::can_start(r,b.actor) || !TechniqueRunner::ready(r,b.actor,id)) return false;for (auto it=r.content->flow_nodes.rbegin();it!=r.content->flow_nodes.rend();++it) if (it->kind==1 && r.content->boss_techniques[it->technique-1].external_id==name && it->flow==f.definition) return FlowRunner::condition(r,f,it->condition,std::string(name)!="stomp");return false;}
bool start(RunRuntime &r,BossBodyState &b,uint32_t id) {if (!id) return false;bool admitted=true;if (!r.state.world.attack_formation_mode && r.state.world.attack_budget.enabled) admitted=AttackBudgetSystem(r).request({"boss:"+std::to_string(r.state.enemy_handles.entity_id(b.actor)),{AttackCategory::Aimed},b.actor,TechniqueRunner::attack_length(r.content->boss_techniques[id-1]),1.5,1});if (!admitted) return false;return r.state.bosses->handles.contains(TechniqueRunner::begin(r,b.actor,id,"natural_ai"));}
void begin_leap(RunRuntime &r,BossBodyState &b) {auto &v=b.centaurus;auto &e=r.state.enemies[b.actor.slot];const auto &p=rule(r,b);const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};e.facing=tracking.angle(e.facing,(r.state.ship_pos-e.pos).angle());v.leaping=true;v.leap_elapsed=0;v.leap_from=e.pos;auto away=(e.pos-tracking.target(e.pos,e.facing,r.state.ship_pos)).normalized();if (away==godot::Vector2()) away=-godot::Vector2::from_angle(e.facing);v.leap_to=e.pos+away*p.leap_distance;v.leap_ready_at=b.clock+p.leap_cd;cue(r,b,"leap");}
bool rear_ready(const RunRuntime &r,const BossBodyState &b,const BossFlowState &f) {if (f.rest_remaining>0) return false;for (const auto &a:r.content->flow_actions) {if (a.flow!=f.definition || a.external_id!="rear_attack" || f.stamina<a.cost) continue;const auto id=technique(r,b,"rear_attack");if (id && TechniqueRunner::ready(r,b.actor,id) && FlowRunner::condition(r,f,a.condition,false)) return true;}return false;}
}
void CentaurusFinish::leap(RunRuntime &r,BossBodyState &b) {begin_leap(r,b);}
bool CentaurusFinish::idle(RunRuntime &r,BossBodyState &b) {
    const auto flow=std::find_if(r.state.bosses->flows.begin(),r.state.bosses->flows.end(),[&](const auto &f){return same_handle(f.actor,b.actor);});if (flow==r.state.bosses->flows.end() || !flow->selection_enabled || b.initial_wait>0 || b.phase_pending) return false;
    auto &v=b.centaurus;const auto &p=rule(r,b);const auto &e=r.state.enemies[b.actor.slot];const auto wall=technique(r,b,"shower_wall");const bool wall_ready=wall && TechniqueRunner::ready(r,b.actor,wall);const double distance=e.pos.distance_to(r.state.ship_pos);
    if (wall_ready && b.clock>=v.leap_ready_at && distance<p.leap_trigger) {begin_leap(r,b);return true;}
    if (rear_ready(r,b,*flow)) return false;
    if (conditional(r,b,*flow,"stomp")) {start(r,b,technique(r,b,"stomp"));return true;}
    if (v.path_hold>=p.path_hold && conditional(r,b,*flow,"shower_path")) {if (start(r,b,technique(r,b,"shower_path"))) v.path_hold=0;return true;}
    if (wall_ready && b.clock>=v.retreat_ready_at && distance<p.retreat_trigger) {v.retreat_ready_at=b.clock+p.leap_time+p.retreat_cd;begin_leap(r,b);return true;}
    return false;
}
void CentaurusFinish::leap_tick(RunRuntime &r,BossBodyState &b,double dt) {auto &v=b.centaurus;auto &e=r.state.enemies[b.actor.slot];const auto &p=rule(r,b);const double duration=std::max(p.leap_time,0.001),before=std::clamp(v.leap_elapsed/duration,0.0,1.0);v.leap_elapsed+=dt;const double k=std::clamp(v.leap_elapsed/duration,0.0,1.0);const auto step=(v.leap_to-v.leap_from)*(std::pow(1.0-before,2)-std::pow(1.0-k,2));const auto from=e.pos;e.vel=step/std::max(dt,0.001);e.pos+=step;FieldSystem::collide_enemy(r,b.actor.slot,from,dt);const auto &d=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1];if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing),-d.turn*3*dt,d.turn*3*dt);if (k>=1) {v.leaping=false;cue(r,b,"leap_landed");start(r,b,technique(r,b,"shower_wall"));}}
}
