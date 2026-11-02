#include "dash.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
namespace speed {
void DashBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &dash=run.content->dashes[def.dash_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);AttackBudgetSystem budget(run);
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle)) && EnemySystem::attack_due(run,handle,dt)) {
        const BudgetRequest request{owner,{AttackCategory::Dash},handle,dash.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);return;}
    }
    const double distance=state.enemy_aim.distance_to(enemy.pos);enemy.timer=float(enemy.timer-dt);
    switch (enemy.mode) {
    case EnemyMode::Move:
        enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);
        if (distance<dash.range) {enemy.mode=EnemyMode::Windup;enemy.timer=float(dash.warn);}break;
    case EnemyMode::Windup:
        enemy.vel*=1.0-4.0*dt;EnemyMotion::turn(enemy,(state.enemy_aim-enemy.pos).angle(),6.0,dt,tracking);
        if (enemy.timer<=0) {enemy.mode=EnemyMode::Dash;enemy.timer=float(dash.dash_time);enemy.vel=godot::Vector2::from_angle(enemy.facing)*dash.dash_speed;}break;
    case EnemyMode::Dash:
        if (enemy.timer<=0) {enemy.mode=EnemyMode::Recover;enemy.timer=float(dash.recover);}break;
    case EnemyMode::Recover:
        enemy.vel*=1.0-2.0*dt;if (enemy.timer<=0) enemy.mode=EnemyMode::Move;break;
    }
}
}
