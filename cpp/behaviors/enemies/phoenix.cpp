#include "phoenix.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attack_system.h"
#include "../../systems/attacks/zone.h"
#include "../../state/combat_types.h"
#include <algorithm>
namespace speed {
void PhoenixBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];auto &v=std::get<PhoenixState>(e.behavior_state);const auto &d=r.content->definitions[e.definition];const auto &p=r.content->phoenixes[d.phoenix_definition-1];
    const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};e.vel={};
    if (e.mode!=EnemyMode::Recover && e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self))) {
        if (!budget.request({owner,{AttackCategory::Dash,AttackCategory::Zone},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) return;
    }
    const auto advance=[&] {
        const auto delta=v.anchor-e.pos;if (!delta.is_zero_approx() && !tracking.locked()) e.facing=delta.angle();
        e.pos=e.pos.lerp(v.anchor,std::clamp(dt/std::max(0.001,e.timer),0.0,1.0));e.timer=std::max(0.0,e.timer-dt);
    };
    switch (e.mode) {
    case EnemyMode::Move:
        if (e.timer<=0) {auto away=(e.pos-s.enemy_aim).normalized();if (tracking.locked()) away=-godot::Vector2::from_angle(e.facing);if (away==godot::Vector2()) away=godot::Vector2::from_angle(e.facing);v.anchor=e.pos+away*p.retreat_distance;e.timer=p.retreat_time;}
        advance();if (e.timer<=0) {v.anchor=tracking.target(e.pos,e.facing,s.enemy_aim);e.mode=EnemyMode::Windup;e.timer=p.telegraph;e.facing=tracking.angle(e.facing,(v.anchor-e.pos).angle());}break;
    case EnemyMode::Windup:
        e.timer=std::max(0.0,e.timer-dt);e.charge=1.0-e.timer/p.telegraph;if (e.timer<=0) {e.mode=EnemyMode::Dash;e.timer=p.dive_time;e.charge=0;}break;
    case EnemyMode::Dash:
        advance();if (e.timer<=0) {
            ZoneParams zone;zone.position=v.anchor;zone.radius=std::max(e.radius*1.1,p.impact_radius);zone.damage=p.impact_damage;zone.style=ZoneStyle::Phoenix;zone.color=d.color;zone.owner=self;if (e.attack_managed) zone.budget.value=budget.token(owner);
            const auto attack=ZoneSystem::emit(r,zone);if (const auto *record=AttackSystem::get(s,attack)) s.hazards[record->row].duration=p.impact_time;
            e.mode=EnemyMode::Recover;e.timer=p.recover_time;
        }break;
    case EnemyMode::Recover:
        e.timer=std::max(0.0,e.timer-dt);if (e.timer<=0) e.mode=EnemyMode::Move;break;
    }
}
void PhoenixBehavior::cancel(RunRuntime &r,EnemyHandle h) {
    auto &s=r.state;if (!s.enemy_handles.contains(h)) return;auto &e=s.enemies[h.slot];if (r.content->definitions[e.definition].kind!=EnemyDefinition::Kind::Phoenix) return;
    e.charge=0;AttackBudgetSystem(r).cancel(AttackBudgetSystem::owner(s,e.id,e.attack_group),e.id);
}
void PhoenixBehavior::died(RunRuntime &r,const DeathContext &death) {cancel(r,death.target);}
}
