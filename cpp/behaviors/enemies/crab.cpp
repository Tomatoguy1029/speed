#include "crab.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attack_system.h"
#include "../../systems/attacks/zone.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
godot::Vector2 walk(const Enemy &e) {return godot::Vector2::from_angle(e.facing+1.5707963267948966)*(std::get<CrabState>(e.behavior_state).buds<0?-1.0:1.0);}
}
void CrabBehavior::steer(RunRuntime &r,uint32_t row) {
    auto &e=r.state.enemies[row];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};if (tracking.locked()) return;
    const auto to=r.state.ship_pos-e.pos;const auto &p=r.content->crabs[r.content->definitions[e.definition].crab_definition-1];if (to.length_squared()<1 || std::abs(walk(e).angle_to(to))<p.turn_angle*0.017453292519943295) return;
    const double right=to.angle()-1.5707963267948966,left=to.angle()+1.5707963267948966;auto &v=std::get<CrabState>(e.behavior_state);
    if (std::abs(angle_difference(right-e.facing))<=std::abs(angle_difference(left-e.facing))) {e.facing=right;v.buds=1;}else {e.facing=left;v.buds=-1;}
}
void CrabBehavior::clear(RunRuntime &r,EnemyHandle self) {
    if (!r.state.enemy_handles.contains(self)) return;auto *v=std::get_if<CrabState>(&r.state.enemies[self.slot].behavior_state);if (!v) return;
    if (const auto *record=AttackSystem::get(r.state,v->sweep)) if (same_handle(record->spec.owner.live_source,self)) AttackSystem::end(r.state,v->sweep,AttackEndReason::ParticipantEnd);v->sweep={};
}
void CrabBehavior::died(RunRuntime &r,const DeathContext &death) {
    if (!r.state.enemy_handles.contains(death.target) || !std::holds_alternative<CrabState>(r.state.enemies[death.target.slot].behavior_state)) return;clear(r,death.target);const auto &e=r.state.enemies[death.target.slot];AttackBudgetSystem(r).cancel(AttackBudgetSystem::owner(r.state,e.id,e.attack_group),e.id);
}
void CrabBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->crabs[d.crab_definition-1];const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    const auto admit=[&] {return !e.attack_managed || (budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) || budget.request({owner,{AttackCategory::Zone},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight});};
    if (e.mode!=EnemyMode::Move) admit();
    switch (e.mode) {
    case EnemyMode::Move: {
        const auto to=s.ship_pos-e.pos;const double distance=to.length(),min_distance=e.radius*std::abs(p.fx_reach_r-p.fx_hit_r),max_distance=e.radius*(p.fx_reach_r+p.fx_hit_r);
        const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
        if (!tracking.locked() && distance>0 && distance>=min_distance && distance<=max_distance && distance<=p.approach) {
            const auto center=e.pos+godot::Vector2::from_angle(e.facing)*(e.radius*p.fx_reach_r);
            if (center.distance_squared_to(s.ship_pos)>e.radius*e.radius*p.fx_hit_r*p.fx_hit_r) e.facing=to.angle();
        } else steer(r,row);
        const auto center=e.pos+godot::Vector2::from_angle(e.facing)*(e.radius*p.fx_reach_r);const double radius=e.radius*p.fx_hit_r;
        if (center.distance_squared_to(s.ship_pos)<=radius*radius && e.pos.distance_squared_to(s.ship_pos)<=p.approach*p.approach) {e.vel={};if (admit()) {e.mode=EnemyMode::Windup;e.timer=std::max(0.01,p.telegraph);e.charge=0;}}
        else {e.vel=walk(e)*e.speed;budget.cancel_wait(owner,e.id);}break;
    }
    case EnemyMode::Windup:
        e.vel={};e.timer=std::max(0.0,e.timer-dt);e.charge=std::clamp(1.0-e.timer/std::max(0.01,p.telegraph),0.0,1.0);
        if (e.timer<=0) {ZoneParams zone;zone.position=e.pos+godot::Vector2::from_angle(e.facing)*(e.radius*p.fx_reach_r);zone.radius=e.radius*p.fx_hit_r;zone.damage=p.damage;zone.color=d.color.lightened(0.3);zone.owner=self;zone.attached=true;if (e.attack_managed) zone.budget.value=budget.token(owner);std::get<CrabState>(e.behavior_state).sweep=ZoneSystem::emit(r,zone);e.mode=EnemyMode::Recover;e.timer=std::max(0.01,p.open_time);e.charge=0;}break;
    case EnemyMode::Recover:
        e.vel={};e.timer-=dt;if (e.timer<=0) {clear(r,self);e.mode=EnemyMode::Move;}break;
    default:break;
    }
}
}
