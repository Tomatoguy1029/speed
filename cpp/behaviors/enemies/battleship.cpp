#include "battleship.h"
#include "gunner.h"
#include "pursuit.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/bullet.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
void BattleshipBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &gun=run.content->battleships[def.battleship_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);AttackBudgetSystem budget(run);
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle)) && EnemySystem::attack_due(run,handle,dt)) {
        const BudgetRequest request{owner,{AttackCategory::Aimed},handle,gun.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {enemy.charge=0;return;}
    }
    const bool fire=GunnerTiming::advance(enemy.fire_t,enemy.charge,dt,gun.warn,def.fire_interval);
    if (!fire) return;
    BulletValues values;values.damage=gun.damage;values.slow=gun.slow;
    const double base=enemy.facing,denominator=std::max(int64_t(1),int64_t(gun.volley)-1);
    for (uint32_t i=0;i<gun.volley;++i) BulletSystem::fire_enemy(run,handle,base+(double(i)/denominator-0.5)*gun.spread,gun.bullet_speed,values);
}
}
