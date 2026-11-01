#include "run_core.h"
#include "../cpp/systems/attack_system.h"
#include "../cpp/systems/attack_budget.h"
#include "../cpp/systems/enemy_system.h"
#include "geometry.h"
#include "../cpp/behaviors/enemies/pursuit.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

bool SpeedRunCore::admit_bite(size_t row,double dt) {
    auto &enemy=runtime.state.enemies[row];if (!enemy.attack_managed) return true;
    const auto &def=runtime.content->definitions[enemy.definition];
    const auto actor=runtime.state.enemy_handles.at(uint32_t(row));
    const auto owner=speed::AttackBudgetSystem::owner(runtime.state,enemy.id,enemy.attack_group);
    speed::AttackBudgetSystem budget(runtime);
    const bool active=budget.owns(owner,enemy.id) && speed::EnemySystem::attack_active(runtime.state,actor);
    if (!active && speed::EnemySystem::attack_due(runtime,actor,dt)) {
        const speed::BudgetRequest request{owner,{speed::AttackCategory::Zone},actor,def.bite.telegraph+0.1,enemy.attack_priority,
            runtime.state.world.attack_formation_mode?enemy.attack_value:def.attack_weight};
        if (!budget.request(request)) {enemy.charge=0;return false;}
    }return true;
}
void SpeedRunCore::advance_biter(size_t row, double dt, bool far) {
    auto &enemy = runtime.state.enemies[row]; const auto &def = runtime.content->definitions[enemy.definition];
    const Vector2 from = enemy.pos;
    const int64_t token = enemy.attack_managed && enemy.mode == EnemyMode::Windup ? speed::AttackBudgetSystem::token(runtime.state,speed::AttackBudgetSystem::owner(runtime.state,enemy.id,enemy.attack_group)) : 0;
    if (far && (enemy.id + runtime.state.ticks) % 3 != 0) { enemy.pos += enemy.vel * dt; return; }
    const double bdt = far ? dt * 3.0 : dt;
    const speed::TrackingPolicy policy{runtime.state.draw.tracing,enemy.held,runtime.state.enemy_handles.contains(enemy.pump_owner)};
    if (enemy.mode == EnemyMode::Windup) {
        enemy.vel *= std::max(0.0, 1.0 - 8.0 * bdt);
        speed::PursuitBehavior::turn(enemy,(runtime.state.ship_pos-from).angle(),def.turn*2.0,bdt,policy);
        enemy.timer = speed::remaining_time(enemy.timer,bdt);
        enemy.charge = 1.0 - std::max(0.0, enemy.timer) / def.bite.telegraph;
        if (enemy.timer <= 0) {
            const Vector2 at = from + Vector2::from_angle(enemy.facing) * (enemy.radius + def.bite.reach * 0.5);
            if (runtime.state.bite_zone_config.ready) {
                BiteZone zone;zone.pos=at;zone.radius=def.bite.radius;zone.damage=def.bite.damage;zone.color=def.color.lightened(0.4);
                speed::AttackSpec spec;spec.owner.budget.value=token;spec.owner.live_source=runtime.state.enemy_handles.at(uint32_t(row));
                spec.policies=speed::EndPolicy::NaturalLifetime|speed::EndPolicy::ClearWithBonus;spec.cause=speed::Cause::Blast;
                if (!runtime.content->contacts.empty()) speed::AttackSystem::configure_contact(*runtime.content,2,spec);
                speed::AttackSystem::emit_hazard(runtime.state,zone,spec);
            }
            enemy.charge = 0; enemy.mode = EnemyMode::Recover; enemy.timer = def.bite.rest;
        }
    } else {
        const Vector2 toward = runtime.state.ship_pos - from;
        const double distance = toward.length();
        const Vector2 previous_velocity = enemy.vel;
        enemy.vel=speed::PursuitBehavior::velocity(enemy,runtime.state.ship_pos,def.turn,bdt,policy);
        if (def.kind == speed::EnemyDefinition::Kind::Hound) {
            const Vector2 target = enemy.pursuit_ready ? enemy.pursuit : toward.normalized() * enemy.speed;
            // 下の共通追跡値ではなく、更新前の速度から補間する。
            enemy.vel = previous_velocity.lerp(policy.velocity(previous_velocity,enemy.facing,target), std::clamp(def.accel * bdt, 0.0, 1.0));
        }
        if (enemy.vel.length_squared() > 0.000001 && !policy.locked()) enemy.facing = enemy.vel.angle();
        if (enemy.mode == EnemyMode::Recover) {
            enemy.timer = speed::remaining_time(enemy.timer,bdt);
            if (enemy.timer <= 0) enemy.mode = EnemyMode::Move;
        } else {
            const double reach = enemy.radius + (def.bite.reach + runtime.state.ship_config.ship_radius);
            if (distance * distance <= reach * reach && admit_bite(row, bdt)) {
                enemy.mode = EnemyMode::Windup; enemy.timer = def.bite.telegraph;
                if (def.id!=StringName("biter")) enemy.flash = 0.1;
            }
        }
    }
    enemy.pos += enemy.vel * dt;
}
