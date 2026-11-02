#include "rocket.h"
#include "pursuit.h"
#include "../../systems/attack_budget.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attacks/blast.h"
namespace speed {
void RocketBehavior::step(RunRuntime &run,uint32_t row,double dt) {
    auto &state=run.state;auto &enemy=state.enemies[row];const auto &def=run.content->definitions[enemy.definition];
    const auto &rocket=run.content->rockets[def.rocket_definition-1];const auto handle=state.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group);AttackBudgetSystem budget(run);
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    if (enemy.attack_managed && !(budget.owns(owner,enemy.id) && EnemySystem::attack_active(state,handle))) {
        const BudgetRequest request{owner,{AttackCategory::Dash,AttackCategory::Zone},handle,rocket.admission_duration,enemy.attack_priority,state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {enemy.vel=PursuitBehavior::velocity(enemy,state.ship_pos,def.turn,dt,tracking);return;}
    }
    if (enemy.mode==EnemyMode::Move) {
        if (!tracking.locked()) enemy.facing=(state.enemy_aim-enemy.pos).angle();
        enemy.vel=godot::Vector2::from_angle(enemy.facing)*enemy.speed;enemy.mode=EnemyMode::Dash;enemy.timer=rocket.life;return;
    }
    enemy.timer=remaining_time(enemy.timer,dt);
    if (enemy.pos.distance_squared_to(state.ship_pos)<=rocket.fuse*rocket.fuse) {
        BlastParams blast;blast.position=enemy.pos;blast.color=def.color;blast.source=handle;blast.budget.value=budget.token(owner);
        blast.radius=rocket.blast_radius;blast.damage=rocket.blast_damage;blast.duration=rocket.blast_duration;blast.contact=rocket.contact;
        BlastSystem::emit(run,blast);
    } else if (enemy.timer>0) return;
    enemy.dead=true;state.dead_rows.push_back(row);
}
}
