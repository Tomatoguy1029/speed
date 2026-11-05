#include "gunner.h"
#include "../../systems/timing.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/bullet.h"
#include "pursuit.h"
#include "../../content/content_bundle.h"
namespace speed {
bool GunnerTiming::advance(double &remaining,double &charge,double dt,double warn,double interval) {
    RemainingTimer timer{remaining};timer.advance(dt);remaining=timer.remaining;
    charge=remaining<warn?1.0-remaining/warn:0;
    if (!timer.due()) return false;
    remaining=interval;return true;
}
void GunnerBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &gun=run.content->gunners[def.gunner_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);
    AttackBudgetSystem budget(run);
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle)) && EnemySystem::attack_due(run,handle,dt)) {
        const BudgetRequest request{owner,{AttackCategory::Aimed},handle,gun.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {
            enemy.charge=0;
            const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
            enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);return;
        }
    }
    EnemyMotion::keep_distance(run,row,gun.keep,gun.accel,dt);
    const bool fire=GunnerTiming::advance(enemy.fire_t,enemy.charge,dt,gun.telegraph,def.fire_interval);

    if (!fire) return;
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    const double angle=tracking.angle(enemy.facing,(state.enemy_aim-enemy.pos).angle());
    BulletValues values;values.damage=gun.bullet_damage;values.slow=gun.slow;
    BulletSystem::fire_enemy(run,handle,angle,gun.bullet_speed,values);
}
}
