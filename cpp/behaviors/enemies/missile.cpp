#include "missile.h"
#include "gunner.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/missile.h"
namespace speed {
void MissileBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &missile=run.content->missile_enemies[def.missile_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);AttackBudgetSystem budget(run);
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle)) && EnemySystem::attack_due(run,handle,dt)) {
        const BudgetRequest request{owner,{AttackCategory::Homing},handle,missile.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {
            enemy.charge=0;
            const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
            enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);return;
        }
    }
    EnemyMotion::keep_distance(run,row,missile.keep,missile.accel,dt);
    const bool fire=GunnerTiming::advance(enemy.fire_t,enemy.charge,dt,missile.warn,def.fire_interval);

    if (!fire) return;
    BulletValues values;values.damage=missile.damage;values.slow=missile.slow;values.turn=missile.missile_turn;
    MissileSystem::fire_enemy(run,handle,enemy.facing,missile.missile_speed,values);
}
}
