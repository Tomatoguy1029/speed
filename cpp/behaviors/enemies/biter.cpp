#include "../../api/run_core.h"
#include "../../systems/field.h"
#include "../../systems/attack_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/enemy_system.h"
#include "../../systems/geometry.h"
#include "pursuit.h"
#include "hound.h"
#include "defender.h"
#include "../../systems/attacks/zone.h"
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
    const bool stop_for_bite = def.id == StringName("biter");
    if (stop_for_bite && enemy.mode == EnemyMode::Windup) enemy.vel = Vector2();
    if (far && (enemy.id + runtime.state.ticks) % 3 != 0) { enemy.pos += enemy.vel * dt; return; }
    const double bdt = far ? dt * 3.0 : dt;
    const speed::TrackingPolicy policy{runtime.state.draw.tracing,enemy.held,runtime.state.enemy_handles.contains(enemy.pump_owner)};
    if (def.kind==speed::EnemyDefinition::Kind::Defender && speed::DefenderBehavior::move(runtime,runtime.state.enemy_handles.at(uint32_t(row)),bdt,policy)) {enemy.pos+=enemy.vel*dt;speed::FieldSystem::collide_enemy(runtime,uint32_t(row),from,dt);return;}
    if (def.kind==speed::EnemyDefinition::Kind::Hound && speed::HoundBehavior::ordered_move(runtime,uint32_t(row),bdt,policy)) {enemy.pos+=enemy.vel*dt;speed::FieldSystem::collide_enemy(runtime,uint32_t(row),from,dt);return;}
    if (enemy.mode == EnemyMode::Windup) {
        enemy.vel *= std::max(0.0, 1.0 - 8.0 * bdt);
        speed::PursuitBehavior::turn(enemy,(runtime.state.ship_pos-from).angle(),def.turn*2.0,bdt,policy);
        enemy.timer = speed::remaining_time(enemy.timer,bdt);
        enemy.charge = 1.0 - std::max(0.0, enemy.timer) / def.bite.telegraph;
        if (enemy.timer <= 0) {
            const Vector2 at = from + Vector2::from_angle(enemy.facing) * (enemy.radius + def.bite.reach * 0.5);
            if (def.kind==speed::EnemyDefinition::Kind::Defender) {
                speed::ZoneParams zone;zone.position=at;zone.radius=def.bite.radius;zone.damage=def.bite.damage;zone.style=speed::ZoneStyle::Bite;zone.color=def.color.lightened(0.4);zone.owner=runtime.state.enemy_handles.at(uint32_t(row));zone.budget.value=token;speed::ZoneSystem::emit(runtime,zone);
            } else if (runtime.state.bite_zone_config.ready) {
                BiteZone zone;zone.pos=at;zone.shape=speed::CircleHazard{float(def.bite.radius)};zone.damage=def.bite.damage;zone.color=def.color.lightened(0.4);
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
        enemy.vel=def.kind==speed::EnemyDefinition::Kind::Hound?speed::HoundBehavior::pursuit(runtime,uint32_t(row),bdt,policy):speed::PursuitBehavior::velocity(enemy,runtime.state.ship_pos,def.turn,bdt,policy);
        if (enemy.vel.length_squared() > 0.000001 && !policy.locked()) enemy.facing = enemy.vel.angle();
        if (enemy.mode == EnemyMode::Recover) {
            enemy.timer = speed::remaining_time(enemy.timer,bdt);
            if (enemy.timer <= 0) enemy.mode = EnemyMode::Move;
        } else {
            const double reach = enemy.radius + (def.bite.reach + runtime.state.ship_config.ship_radius);
            if (distance * distance <= reach * reach && admit_bite(row, bdt)) {
                enemy.mode = EnemyMode::Windup; enemy.timer = def.bite.telegraph;
                if (stop_for_bite) enemy.vel = Vector2();
                if (def.id!=StringName("biter")) enemy.flash = 0.1;
            }
        }
    }
    enemy.pos += enemy.vel * dt;
    speed::FieldSystem::collide_enemy(runtime,uint32_t(row),from,dt);
}
