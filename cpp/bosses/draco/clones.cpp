#include "clones.h"
#include "../../systems/motion_math.h"
#include "picaro_wall.h"
#include "pose.h"
#include "tail_motion.h"
#include "body.h"
#include "pose.h"
#include "picaro.h"
#include "../flow/phase_controller.h"
#include "../hydra/normal_attack.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <array>
#include <cmath>
namespace speed {
namespace {
constexpr double tau=6.283185307179586,BACK=1.25;
bool alive(const RunRuntime &r,EnemyHandle h) {return r.state.enemy_handles.contains(h) && !r.state.enemies[h.slot].dead;}
const DracoClonesDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->draco_clones.begin(),r.content->draco_clones.end(),[&](const auto &v){return v.technique==t.definition;});}
void shape(RunRuntime &r,BossBodyState &b,DracoCloneUnit &u) {
    auto &e=r.state.enemies[u.inner.actor.slot];const auto &body=DracoBody::rule(r,b);if (u.trail.empty()) u.trail=DracoTechnique::neutral(r,b,e.pos,u.neck.angle);DracoPose::follow(u.trail,u.points,e.pos,body.body_length,body.body_segments+1);
    if (!u.index) e.facing=u.face;
    double total=0;for (size_t i=1;i<u.points.size();++i) total+=u.points[i-1].distance_to(u.points[i]);
    size_t at=0;double traversed=0;for (size_t j=0;j<u.parts.size();++j) {const double fraction=double(j+1)/u.parts.size(),target=total*fraction;while (at+2<u.points.size() && target>traversed+u.points[at].distance_to(u.points[at+1])) {traversed+=u.points[at].distance_to(u.points[at+1]);++at;}if (!alive(r,u.parts[j])) continue;auto &part=r.state.enemies[u.parts[j].slot];part.pos=u.points[at].lerp(u.points[at+1],(target-traversed)/std::max(0.001,double(u.points[at].distance_to(u.points[at+1]))));part.radius=b.draco->width*0.5*(1-0.77*std::pow(std::clamp((fraction-0.55)/0.45,0.0,1.0),1.35));}
}
EnemyHandle spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at) {EnemySpawn options;options.position=at;options.origin=SpawnOrigin::BossPart;const auto id=EnemySystem::spawn_base(r,definition-1,options);if (id<0) return {};auto h=r.state.enemy_handles.at(r.state.rows_by_id.at(id));r.state.enemies[h.slot].held=true;r.state.enemies[h.slot].clone_visual=true;return h;}
}
void DracoClones::begin(RunRuntime &r,TechniqueState &t) {
    auto *b=PhaseController::find(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}DracoPicaro::pause(r,*b,false);auto &v=t.detail.get<DracoTechniqueState>();v.move=DracoClonesState{};auto &s=std::get<DracoClonesState>(v.move);const auto &p=rule(r,t);s.center=DracoTechnique::predict(r,t.actor,0,0);t.aim=s.center;v.warning_width=r.content->boss_techniques[t.definition-1].width;s.axis=(s.center-r.state.enemies[t.actor.slot].pos).angle();
    std::array<uint32_t,5> order{p.bite,p.wind,p.rubble,p.beam,p.thunder};for (int j=4;j>0;--j) std::swap(order[j],order[*r.state.control.rng.randi_range(0,j)]);
    const double radius=r.state.enemies[t.actor.slot].radius;
    for (uint32_t j=0;j<3;++j) {
        const auto actor=j?spawn(r,p.clone_enemy,s.center+godot::Vector2::from_angle(j*tau/3)*650):t.actor;if (!alive(r,actor)) {t.stage=TechniqueStage::Failed;break;}
        DracoCloneUnit u;u.index=j;u.inner.actor=actor;u.inner.definition=order[j];u.inner.previous_ship=r.state.ship_pos;u.origin=r.state.enemies[actor.slot].pos;u.neck.actor=actor;u.neck.target=s.center;u.neck.angle=(s.center-u.origin).angle();u.neck.length=100;u.neck.head_hp=r.state.enemies[actor.slot].hp;u.neck.normal=order[j];u.face=u.neck.angle;
        if (j) {r.state.enemies[actor.slot].radius=radius;r.state.enemies[actor.slot].hp=r.state.enemies[actor.slot].max_hp=p.clone_hp;for (uint32_t k=0;k<DracoBody::rule(r,*b).body_segments;++k) {const auto part=spawn(r,p.part_enemy,u.origin);if (!alive(r,part)) continue;auto &e=r.state.enemies[part.slot];e.parent=t.actor;e.parent_id=r.state.enemy_handles.entity_id(t.actor);e.damage_target=actor;e.hp=e.max_hp=999999;u.parts.push_back(part);}}
        shape(r,*b,u);s.units.push_back(std::move(u));
    }
}
// 上を向いて咆哮し、飛び込む直前に一体目の持ち場の向きへ戻る。
void DracoClones::windup(RunRuntime &r,TechniqueState &t) {auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoClonesState>(v.move);const double warn=r.content->boss_techniques[t.definition-1].warn,home=s.units.empty()?s.axis:s.units[0].neck.angle;double facing=DracoPicaroWall::shout_facing(s.axis,v.stage_time);facing+=angle_difference(home-facing)*DracoTailMotion::smooth(warn-0.35,warn,v.stage_time);r.state.enemies[t.actor.slot].facing=facing;if (!s.roared && v.stage_time>=0.5) {s.roared=true;DracoPicaroWall::roar(r,t);}}
void DracoClones::active(RunRuntime &r,TechniqueState &t,double dt) {
    auto *b=PhaseController::find(r,t.actor);if (!b) return;auto &v=t.detail.get<DracoTechniqueState>();auto &s=std::get<DracoClonesState>(v.move);const auto &p=rule(r,t);const auto &move=r.content->boss_techniques[t.definition-1];const auto parent=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    for (auto &u:s.units) {
        if (!alive(r,u.inner.actor)) {for (auto part:u.parts) EnemySystem::mark_dead(r,part);continue;}
        const double entry=u.index*0.7;if (v.stage_time<entry) continue;
        const auto forward=godot::Vector2::from_angle(u.neck.angle);const double offset=120*b->draco->head_scale;const auto landing=s.center-forward*offset;
        if (v.stage_time<entry+0.5) {
            const auto before=r.state.enemies[u.inner.actor.slot].pos+forward*offset;r.state.enemies[u.inner.actor.slot].pos=u.origin.lerp(landing,DracoTechnique::burst((v.stage_time-entry)/0.5));const auto after=r.state.enemies[u.inner.actor.slot].pos+forward*offset;
            if (!u.entry_hit) {r.state.observations.execute(t.observation_id);if (auto *o=r.state.observations.find(t.observation_id)) ++o->checks;const auto delta=after-before;const double f=delta.length_squared()>0?std::clamp(double((r.state.ship_pos-before).dot(delta))/delta.length_squared(),0.0,1.0):0;if (r.state.ship_pos.distance_to(before+delta*f)<=move.width+r.state.ship_config.ship_radius) {if (auto *o=r.state.observations.find(t.observation_id)) ++o->contacts;ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=move.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::CloneLeap;request.source=r.state.enemies[t.actor.slot].definition+1;request.technique=t.definition;request.hit_policy=HitPolicy::MarkIfAccepted;u.entry_hit=CombatResolver::ship_damage(r,request).accepted;}}
        } else if (v.stage_time<entry+BACK) {
            // 飛び込んだら大きく弧を描いて回り込み、向きを戻しながら持ち場へ帰る。
            auto &head=r.state.enemies[u.inner.actor.slot].pos;const auto before=head;const double k=DracoTechnique::smooth((v.stage_time-entry-0.5)/(BACK-0.5));const auto bend=landing.lerp(u.origin,0.5)+godot::Vector2(-forward.y,forward.x)*(u.index%2?1:-1)*340;head=landing.lerp(bend,k).lerp(bend.lerp(u.origin,k),k);if (head.distance_squared_to(before)>0.0001) {const double way=(head-before).angle();u.face=k<0.7?way:way+angle_difference(u.neck.angle-way)*DracoTailMotion::smooth(0.7,1,k);}
        }
        else if (u.face=u.neck.angle,u.inner.stage<TechniqueStage::Finished) {HydraNormalContext context{b,&u.neck,parent,p.neck_rest,uint32_t(r.state.enemies[t.actor.slot].definition+1)};HydraNormalAttack::step_inner(r,u.inner,dt,context);if (r.content->boss_techniques[u.inner.definition-1].kind==64 && u.neck.locked) r.state.enemies[u.inner.actor.slot].pos=u.neck.strike_pos;}
        if (v.stage_time>move.active-1 && u.index) r.state.enemies[u.inner.actor.slot].pos=r.state.enemies[u.inner.actor.slot].pos.lerp(r.state.enemies[t.actor.slot].pos,std::min(1.0,dt*5));shape(r,*b,u);
    }
}
void DracoClones::clear(RunRuntime &r,BossBodyState &b) {
    // 所有者の終了では、後から取消フックが呼ばれてもPicaroを新しく残さない。
    for (auto &t:r.state.bosses->techniques) if (same_handle(t.actor,b.actor) && r.content->boss_techniques[t.definition-1].kind==105) end(r,t,false);
}
void DracoClones::end(RunRuntime &r,TechniqueState &t,bool cancelled) {
    auto &v=t.detail.get<DracoTechniqueState>();auto *s=std::get_if<DracoClonesState>(&v.move);if (!s || s->ended) return;s->ended=true;auto *b=PhaseController::find(r,t.actor);const auto &p=rule(r,t);const auto ticket=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
    // SourceのHost終了は非persistentだけを消し、投石などの持続攻撃を残す。
    std::vector<AttackHandle> stop;for (uint32_t i=0;i<r.state.attacks.records.size();++i) {const auto &a=r.state.attacks.records[i];if (a.alive && same_handle(a.spec.technique,ticket) && has_policy(a.spec.policies,EndPolicy::CancelWithTechnique)) stop.push_back(r.state.attacks.handles.at(i));}for (auto h:stop) AttackSystem::end(r.state,h,AttackEndReason::TechniqueCancel);
    for (auto &u:s->units) {if (!u.index) continue;if (cancelled && b && alive(r,t.actor) && DracoPicaro::adopt_clone(r,*b,u.inner.actor,u.parts,u.neck.angle,p.clone_stars)) continue;EnemySystem::mark_dead(r,u.inner.actor);for (auto h:u.parts) EnemySystem::mark_dead(r,h);}
    v.warning_paths.clear();v.attack.clear();
}
bool DracoClones::validate(const DracoClonesState &s,const ContentBundle &c) {if (!s.center.is_finite() || s.units.size()!=3) return false;for (size_t j=0;j<s.units.size();++j) {const auto &u=s.units[j];if (u.index!=j || !u.origin.is_finite() || !u.inner.actor.generation || !u.inner.definition || u.inner.definition>c.boss_techniques.size() || !u.neck.target.is_finite() || !u.neck.strike_pos.is_finite() || !std::isfinite(u.neck.elapsed) || u.neck.elapsed<0 || !std::isfinite(u.neck.angle) || !std::isfinite(u.neck.length) || u.inner.stage>TechniqueStage::Cancelled) return false;for (auto q:u.points) if (!q.is_finite()) return false;}return true;}
godot::Dictionary DracoClones::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &s=std::get<DracoClonesState>(t.detail.get<DracoTechniqueState>().move);godot::Dictionary out;godot::Array units;for (const auto &u:s.units) {godot::Dictionary x;x["id"]=r.state.enemy_handles.entity_id(u.inner.actor);x["alive"]=alive(r,u.inner.actor);x["index"]=u.index;x["mode"]=godot::String(r.content->boss_techniques[u.inner.definition-1].external_id.c_str());x["position"]=r.state.enemy_handles.contains(u.inner.actor)?r.state.enemies[u.inner.actor.slot].pos:u.origin;x["hp"]=r.state.enemy_handles.contains(u.inner.actor)?r.state.enemies[u.inner.actor.slot].hp:0.0;x["angle"]=u.face;x["time"]=u.neck.elapsed;x["locked"]=u.neck.locked;x["done"]=u.inner.stage>=TechniqueStage::Finished;x["entry_hit"]=u.entry_hit;godot::PackedVector2Array points;for (auto q:u.points) points.push_back(q);x["points"]=points;godot::PackedInt64Array parts;for (auto h:u.parts) parts.push_back(r.state.enemy_handles.entity_id(h));x["parts"]=parts;units.push_back(x);}out["clones"]=units;out["clone_center"]=s.center;out["clone_ended"]=s.ended;return out;}
}

namespace speed {
void DracoClones::snapshot_body(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &out) {
    godot::Array units;
    for (const auto &t:r.state.bosses->techniques) if (same_handle(t.actor,b.actor) && r.content->boss_techniques[t.definition-1].kind==105 && t.stage==TechniqueStage::Active) {const auto &state=std::get<DracoClonesState>(t.detail.get<DracoTechniqueState>().move);if (!state.ended) for (const auto &u:state.units) if (u.index && alive(r,u.inner.actor)) {godot::Dictionary x;x["id"]=r.state.enemy_handles.entity_id(u.inner.actor);x["position"]=r.state.enemies[u.inner.actor.slot].pos;x["angle"]=u.face;godot::PackedVector2Array points;for (auto p:u.points) points.push_back(p);x["points"]=points;units.push_back(x);}}
    for (const auto &m:b.draco->picaro) if (!m.clone_parts.empty() && alive(r,m.actor)) {godot::Dictionary x;x["id"]=r.state.enemy_handles.entity_id(m.actor);x["position"]=r.state.enemies[m.actor.slot].pos;x["angle"]=m.angle;godot::PackedVector2Array points;for (auto p:DracoTechnique::neutral(r,b,r.state.enemies[m.actor.slot].pos,m.angle)) points.push_back(p);x["points"]=points;units.push_back(x);}
    out["clones"]=units;out["effects"]=HydraNormalAttack::shapes(r,b);
}
}

namespace speed {
bool DracoClones::validate_handles(const godot::RunState &s,const ContentBundle &c,const TechniqueState &t) {
    const auto &v=std::get<DracoClonesState>(t.detail.get<DracoTechniqueState>().move);const auto found=std::find_if(c.draco_clones.begin(),c.draco_clones.end(),[&](const auto &p){return p.technique==t.definition;});if (found==c.draco_clones.end()) return false;const auto &p=*found;std::unordered_set<uint64_t> actors;
    for (const auto &u:v.units) {if (!actors.insert(uint64_t(u.inner.actor.slot)<<32|u.inner.actor.generation).second || (u.index==0 && !same_handle(u.inner.actor,t.actor)) || (u.index>0 && same_handle(u.inner.actor,t.actor)) || (u.inner.definition!=p.bite && u.inner.definition!=p.wind && u.inner.definition!=p.rubble && u.inner.definition!=p.beam && u.inner.definition!=p.thunder)) return false;
        if (s.enemy_handles.contains(u.inner.actor) && !s.enemies[u.inner.actor.slot].dead && !v.ended) for (auto h:u.parts) if (!s.enemy_handles.contains(h) || s.enemies[h.slot].dead || !same_handle(s.enemies[h.slot].damage_target,u.inner.actor)) return false;
        for (double value:{u.inner.elapsed,u.inner.remaining,u.neck.glow,u.neck.sweep}) if (!std::isfinite(value)) return false;
    }return true;
}
}
