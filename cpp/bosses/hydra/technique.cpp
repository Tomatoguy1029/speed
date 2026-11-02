#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "regrow.h"
#include "../flow/phase_controller.h"
#include "../flow/technique_runner.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
const HydraMajorDefinition &HydraTechnique::rule(const RunRuntime &r,uint32_t definition) {return *std::find_if(r.content->hydra_majors.begin(),r.content->hydra_majors.end(),[&](const auto &v){return v.technique==definition;});}
void HydraTechnique::cue(RunRuntime &r,const BossBodyState &b,const char *name,uint32_t definition,double duration) {godot::Dictionary e;e["id"]=r.state.enemy_handles.entity_id(b.actor);e["cue"]=name;e["technique"]=godot::String(r.content->boss_techniques[definition-1].external_id.c_str());e["neck"]=-1;e["position"]=r.state.enemies[b.actor.slot].pos;e["duration"]=duration;e["damage"]=0;e["next_count"]=0;e["target"]="hydra";FrameBuilder::append(r,"hydra_cue",e);}
bool HydraTechnique::busy(const RunRuntime &r,const BossBodyState &b) {return std::any_of(r.state.bosses.techniques.begin(),r.state.bosses.techniques.end(),[&](const auto &t){return same_handle(t.actor,b.actor) && t.stage<TechniqueStage::Finished && supports(r.content->boss_techniques[t.definition-1].kind);});}
bool HydraTechnique::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    const auto *b=PhaseController::find(r,actor);if (!b || !r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || b->hydra.necks.empty() || b->mode!=BossMode::Idle || busy(r,*b) || b->hydra.growth_left>0 || b->hydra.chance_left>0 || b->hydra.recovery_left>0 || b->hydra.major_padding_left>0 || (rule(r,definition).combo?b->hydra.combo_left:b->hydra.major_cd)>0 || !rule(r,definition).timeline_available || b->hydra.separation_pending || b->hydra.separation_left>0) return false;
    if (auto it=b->hydra.major_until.find(definition);it!=b->hydra.major_until.end() && r.state.world_time<it->second) return false;
    if (r.content->boss_techniques[definition-1].kind==73) return b->hydra.separated && grid_plan(r,*b,definition).has_value();
    return !b->hydra.separated && b->hydra.necks.size()>=5 && std::count_if(b->hydra.necks.begin(),b->hydra.necks.end(),[&](const auto &n){return HydraRegrow::alive(r,n);})>=3;
}
bool HydraTechnique::reserve(RunRuntime &r,EnemyHandle actor,uint32_t definition) {if (r.state.world.attack_formation_mode) return true;const auto &p=rule(r,definition);BudgetRequest request;request.owner="boss:"+std::to_string(r.state.enemy_handles.entity_id(actor));request.categories={AttackCategory::Dash,AttackCategory::Beam,AttackCategory::Zone,AttackCategory::Aimed};request.source=actor;request.duration=12;request.priority=1.5;request.cost=p.cost;return AttackBudgetSystem(r).request(request);}
AttackHandle HydraTechnique::emit(RunRuntime &r,TechniqueState &t,EnemyHandle actor,const std::vector<godot::Vector2> &points,double width,double delay,double life,Cause cause) {
    auto *b=PhaseController::find(r,t.actor);HazardState h;h.pos=points.front();h.delay=delay;h.duration=life;h.damage=r.content->boss_techniques[t.definition-1].damage;h.shape=HydraShapeHazard{points,width};auto &shape=std::get<HydraShapeHazard>(h.shape);shape.delay=delay;shape.life=life;
    AttackSpec spec;spec.owner.budget.value=AttackBudgetSystem(r).token("boss:"+std::to_string(r.state.enemy_handles.entity_id(t.actor)));spec.owner.live_source=actor;spec.owner.attached=true;spec.technique=r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data()));spec.boss=r.state.bosses.body_handles.at(uint32_t(b-r.state.bosses.bodies.data()));spec.source_technique=t.definition;spec.cause=cause;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::CancelWithTechnique;spec.policies|=policy(EndPolicy::CancelWithParticipant)|policy(EndPolicy::ClearWithBoss);spec.contact={DamageScale::AtkScale,HitPolicy::EveryTick,true,true};const auto handle=AttackSystem::emit_hazard(r.state,h,spec);if (AttackSystem::get(r.state,handle)) r.state.attacks.records[handle.slot].ship_previous=t.previous_ship;return handle;
}
void HydraTechnique::begin(RunRuntime &r,TechniqueState &t) {
    auto *b=PhaseController::find(r,t.actor);t.detail=HydraTechniqueState{};t.previous_ship=r.state.ship_pos;if (rule(r,t.definition).combo) b->hydra.combo_left=rule(r,t.definition).combo_cd;auto &v=std::get<HydraTechniqueState>(t.detail);
    for (uint32_t i=0;i<r.state.bosses.techniques.size();++i) if (&r.state.bosses.techniques[i]!=&t && HydraNormalAttack::body(r,r.state.bosses.techniques[i].actor)==b) TechniqueRunner::cancel(r,r.state.bosses.handles.at(i));
    for (auto &n:b->hydra.necks) if (HydraRegrow::alive(r,n)) {v.participants.push_back(n.actor);n.strike_pos=n.strike_from=HydraBody::head_position(r,*b,n);n.major=t.definition;n.locked=false;n.step=0;n.emission={};n.target=r.state.ship_pos;}
    cue(r,*b,"warning_started",t.definition,r.content->boss_techniques[t.definition-1].warn);if (r.content->boss_techniques[t.definition-1].kind==73) grid_prepare(r,t);else curve(r,t,0);
}
void HydraTechnique::finish(RunRuntime &r,TechniqueState &t,bool cancelled) {
    auto *b=PhaseController::find(r,t.actor);if (!b) return;const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=rule(r,t.definition);
    b->hydra.major_padding_left=v.major_recovery_padding;b->hydra.recovery_left=p.recover;b->hydra.major_cd=v.global_cd;b->hydra.major_until[t.definition]=r.state.world_time+p.cd;
    for (auto &n:b->hydra.necks) if (n.major==t.definition) {const auto at=HydraBody::head_position(r,*b,n);n.length=at.distance_to(HydraBody::neck_base(r,*b,n));n.free_pos=n.strike_pos=at;n.major=0;n.locked=n.extension=false;n.emission={};n.glow=0;}
    if (cancelled) AttackBudgetSystem(r).cancel("boss:"+std::to_string(r.state.enemy_handles.entity_id(t.actor)),r.state.enemy_handles.entity_id(t.actor));
    t.stage=cancelled?TechniqueStage::Cancelled:TechniqueStage::Finished;cue(r,*b,cancelled?"interrupted":"finished",t.definition);cue(r,*b,"recovery_started",t.definition,p.recover);AttackSystem::end_technique(r.state,r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data())),cancelled);
}
void HydraTechnique::cancel(RunRuntime &r,TechniqueState &t) {finish(r,t,true);}
void HydraTechnique::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto *b=PhaseController::find(r,t.actor);if (!b || !b->hydra.attack_field_advance || b->hydra.growth_left>0 || b->hydra.separation_left>0 || b->mode>=BossMode::Defeated) return;auto &v=std::get<HydraTechniqueState>(t.detail);const auto &p=r.content->boss_techniques[t.definition-1];
    if (std::none_of(v.participants.begin(),v.participants.end(),[&](auto actor){return r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;})) {finish(r,t,true);return;}
    if (p.kind==73 && std::get<HydraGridState>(v.move).positioning && !grid_position(r,t,dt)) return;
    t.elapsed+=dt;if (t.elapsed>=p.warn+p.active) {finish(r,t,false);return;}
    if (t.elapsed>=p.warn) {if (!v.playing) {v.playing=true;cue(r,*b,"attack_started",t.definition);}v.time+=dt;t.stage=TechniqueStage::Active;if (p.kind==73) grid(r,t);else curve(r,t,dt);}
    t.previous_ship=r.state.ship_pos;
}
// Sourceのflow選択→timeline→首姿勢→attack_fieldの順で一度だけ進める。
void HydraTechnique::tick(RunRuntime &r,double dt) {for (auto &t:r.state.bosses.techniques) if (t.stage<TechniqueStage::Finished && supports(r.content->boss_techniques[t.definition-1].kind)) step(r,t,dt);}
bool HydraTechnique::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=std::get_if<HydraTechniqueState>(&t.detail);if (!v || !std::isfinite(v->time) || v->time<0 || v->participants.empty() || v->participants.size()>8) return false;if (c.boss_techniques[t.definition-1].kind==72) return std::holds_alternative<HydraCurveState>(v->move);const auto *g=std::get_if<HydraGridState>(&v->move);if (!g || !std::isfinite(g->position_elapsed) || g->position_elapsed<0 || !g->plan.layout || g->plan.layout>c.hydra_grid_layouts.size() || g->plan.starts.size()!=v->participants.size() || g->plan.ends.size()!=v->participants.size() || g->arrived.size()!=v->participants.size() || !g->plan.bearer.is_finite() || !std::isfinite(g->plan.length)) return false;for (const auto *points:{&g->plan.starts,&g->plan.ends,&g->plan.path}) for (auto p:*points) if (!p.is_finite()) return false;return true;}
godot::Dictionary HydraTechnique::snapshot(const TechniqueState &t,const ContentBundle &c) {const auto &v=std::get<HydraTechniqueState>(t.detail);godot::Dictionary out;out["performance_time"]=v.time;godot::Array participants;for (auto actor:v.participants) participants.push_back(int64_t(handle_key(actor)));out["participants"]=participants;if (const auto *g=std::get_if<HydraGridState>(&v.move)) {out["positioning"]=g->positioning;out["position_elapsed"]=g->position_elapsed;out["grid_name"]=godot::String(c.hydra_grid_layouts[g->plan.layout-1].name.c_str());out["grid_bearer"]=g->plan.bearer;out["grid_length"]=g->plan.length;godot::PackedVector2Array path,starts,ends;for (auto p:g->plan.path) path.push_back(p);for (auto p:g->plan.starts) starts.push_back(p);for (auto p:g->plan.ends) ends.push_back(p);out["grid_path"]=path;out["grid_starts"]=starts;out["grid_ends"]=ends;}return out;}
}
