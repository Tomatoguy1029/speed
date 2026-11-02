#include "cepheus.h"
#include "soldier.h"
#include "../../systems/enemy_system.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/group_system.h"
#include "../../systems/attack_budget.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <array>
namespace speed {
namespace {
constexpr std::array<uint32_t,3> tiers{3,5,7};
std::vector<EnemyHandle> soldiers(const RunRuntime &r,EnemyHandle king) {
    std::vector<EnemyHandle> out;const auto &s=r.state;if (!s.enemy_handles.contains(king)) return out;
    const auto id=s.enemies[king.slot].id;const auto *group=s.groups.groups.getptr(id);if (!group || group->kind!=Group::Kind::Cepheus) return out;
    for (size_t g=0;g<s.behavior_kinds.size();++g) if (s.behavior_kinds[g]==EnemyDefinition::Kind::Soldier) for (auto row:s.behavior_rows[g]) {
        const auto &e=s.enemies[row];const auto *v=std::get_if<SoldierState>(&e.behavior_state);const auto h=s.enemy_handles.at(uint32_t(row));
        if (!e.dead && e.mode!=EnemyMode::Recover && v && same_handle(v->king,king) && v->king_id==id && group->members.getptr(e.id)) out.push_back(h);
    }
    return out;
}
std::pair<godot::Vector2,double> slot(const Enemy &king,const SoldierFormation &f,uint32_t k) {
    double angle=king.facing;const auto u=godot::Vector2::from_angle(angle),n=godot::Vector2(-u.y,u.x);
    if (f.tier==1) return {f.anchor+u*f.row_near+n*(double(k)-1)*f.spacing,angle};
    if (f.tier==2) {angle+=(double(k)-2)*f.fan_step;return {f.anchor+godot::Vector2::from_angle(angle)*f.fan_radius,angle};}
    if (k<4) return {f.anchor+u*f.row_far+n*(double(k)-1.5)*f.spacing,angle};
    return {f.anchor+u*f.row_near+n*(double(k)-5)*f.spacing,angle};
}
void reform(RunRuntime &r,EnemyHandle king,const CepheusDefinition &p) {
    auto &s=r.state;auto &e=s.enemies[king.slot];auto &v=std::get<CepheusState>(e.behavior_state);v.tier=std::min(v.tier+1,3u);v.anchor=e.pos;v.volley=0;
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};e.facing=tracking.angle(e.facing,(s.ship_pos-e.pos).angle());
    const SoldierFormation f{v.anchor,p.spacing,p.row_near,p.row_far,p.fan_radius,p.fan_step,v.tier};
    if (!s.groups.groups.getptr(e.id)) GroupSystem::join(s,king,e.id);
    auto &group=s.groups.groups[e.id];group.kind=Group::Kind::Cepheus;group.leader=king;group.formation=f;
    auto members=soldiers(r,king);uint32_t k=0;
    for (auto member:members) {if (k>=tiers[v.tier-1]) break;SoldierBehavior::configure(r,member,king,k++,f,true);}
    auto &marks=s.groups.summon_marks;marks.erase(std::remove_if(marks.begin(),marks.end(),[&](const auto &m){return m.age>=m.life;}),marks.end());
    for (;k<tiers[v.tier-1];++k) {const auto at=slot(e,f,k).first;marks.push_back({at,e.pos,r.content->definitions[e.definition].color,0,p.summon_time});godot::Dictionary event;event["pos"]=at;event["king"]=e.pos;event["life"]=p.summon_time;event["color"]=r.content->definitions[e.definition].color;FrameBuilder::append(r,"summon_mark",event);}
    e.mode=EnemyMode::Windup;e.timer=p.summon_time;
}
}
void CepheusBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<CepheusState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->cepheus[d.cepheus_definition-1];const auto self=s.enemy_handles.at(row);
    const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};const auto away=(e.pos-s.enemy_aim).normalized();
    EnemyMotion::steer(e,s.enemy_aim+away*p.keep,e.speed,p.accel,dt,tracking);
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Aimed},self,0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) return;
    }
    if (!v.tier) {reform(r,self,p);return;}
    e.fire_t-=dt;
    if (e.mode==EnemyMode::Windup) {
        e.timer-=dt;e.charge=1-std::clamp(e.timer/p.summon_time,0.0,1.0);if (e.timer>0) return;
        const auto f=s.groups.groups[e.id].formation;
        if (e.timer>-dt*1.5) {
            std::array<bool,7> taken{};for (auto h:soldiers(r,self)) taken[std::get<SoldierState>(s.enemies[h.slot].behavior_state).slot]=true;
            for (uint32_t k=0;k<tiers[v.tier-1];++k) if (!taken[k]) {
                const auto at=slot(s.enemies[row],f,k);EnemySpawn spawn;spawn.position=at.first;spawn.facing=at.second;spawn.has_facing=true;spawn.group=e.attack_group;spawn.value=e.attack_value;spawn.has_value=true;spawn.priority=e.attack_priority;spawn.has_priority=true;
                const auto id=EnemySystem::spawn_base(r,p.soldier-1,spawn);if (id<0) continue;
                const auto child=s.enemy_handles.at(uint32_t(s.rows_by_id.at(id)));SoldierBehavior::configure(r,child,self,k,f,false);
            }
            godot::Dictionary event;event["pos"]=s.enemies[row].pos;event["color"]=d.color;FrameBuilder::append(r,"cepheus_summon",event);
        }
        for (auto h:soldiers(r,self)) if (s.enemies[h.slot].mode!=EnemyMode::Move) return;
        s.enemies[row].mode=EnemyMode::Move;s.enemies[row].charge=0;s.enemies[row].timer=p.fire_interval;s.enemies[row].fire_t=p.reinforce_interval;return;
    }
    e.timer-=dt;const bool back=int64_t(v.volley)%2==1;const godot::Rect2 view(s.view_center-s.view_half,s.view_half*2);
    const auto members=soldiers(r,self);
    for (auto h:members) {auto &child=s.enemies[h.slot];const auto k=std::get<SoldierState>(child.behavior_state).slot;
        if (child.mode!=EnemyMode::Move || !view.has_point(child.pos) || e.timer>0.4 || (v.tier==3 && (k>=4)!=back)) child.charge=0;
        else child.charge=std::min(1.0,child.charge+std::min(dt,0.05)/0.4);
    }
    if (e.timer<=0) {
        ++v.volley;const BudgetToken token{e.attack_managed?budget.token(owner):0};
        for (auto h:members) {const auto &child=s.enemies[h.slot];const auto k=std::get<SoldierState>(child.behavior_state).slot;
            if (child.mode==EnemyMode::Move && child.charge>=1 && view.has_point(child.pos) && (v.tier!=3 || (k>=4)==back)) SoldierBehavior::fire(r,h,token);
        }
        e.timer=p.fire_interval*(v.tier==3?0.5:1.0);for (auto h:members) s.enemies[h.slot].charge=0;
    }
    if (e.fire_t<=0) reform(r,self,p);
}
void CepheusBehavior::died(RunRuntime &r,const DeathContext &death) {
    if (!r.state.enemy_handles.contains(death.target)) return;const auto &king=r.state.enemies[death.target.slot];const auto &d=r.content->definitions[king.definition];if (d.kind!=EnemyDefinition::Kind::Cepheus) return;
    const auto &p=r.content->cepheus[d.cepheus_definition-1];for (auto h:soldiers(r,death.target)) {const double seconds=p.mutiny_time+r.state.control.rng.randf()*0.6;SoldierBehavior::start_mutiny(r,h,seconds);}
}
}
