#include "run_core.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
using namespace godot;

StringName SpeedRunCore::enemy_attack_owner(const Enemy &enemy) const {
    return attack_formation_mode && enemy.attack_group > 0 ?
        String("formation:") + String::num_int64(enemy.attack_group) : String::num_int64(enemy.id);
}
bool SpeedRunCore::admit_bite(Enemy &enemy, double dt) {
    if (!enemy.attack_managed) return true;
    const auto &def = definitions[enemy.definition];
    const StringName owner = enemy_attack_owner(enemy);
    const bool active = owns_attack(owner, enemy.id) && (enemy.mode == EnemyMode::Windup || enemy.mode == EnemyMode::Dash);
    if (!active && enemy.fire_t <= def.attack_telegraph + dt) {
        PackedStringArray categories; categories.append("zone");
        if (!request_attack(owner, categories, enemy.id, def.bite.telegraph + 0.1, enemy.attack_priority,
                attack_formation_mode ? enemy.attack_value : def.attack_weight)) {
            enemy.charge = 0; return false;
        }
    }
    return true;
}
void SpeedRunCore::advance_biter(size_t row, double dt, bool far) {
    auto &enemy = enemies[row]; const auto &def = definitions[enemy.definition];
    const Vector2 from = enemy.pos;
    const int64_t token = enemy.attack_managed && enemy.mode == EnemyMode::Windup ? attack_token(enemy_attack_owner(enemy)) : 0;
    if (far && (enemy.id + ticks) % 3 != 0) { enemy.pos += enemy.vel * dt; return; }
    const double bdt = far ? dt * 3.0 : dt;
    if (enemy.mode == EnemyMode::Windup) {
        enemy.vel *= std::max(0.0, 1.0 - 8.0 * bdt);
        const double difference = double((ship_pos - from).angle()) - enemy.facing;
        const double wrapped = difference - (2.0 * Math_PI) * std::floor((difference + Math_PI) / (2.0 * Math_PI));
        const double turn = def.turn * 2.0 * bdt;
        enemy.facing += std::clamp(wrapped, -turn, turn);
        enemy.timer -= bdt;
        enemy.charge = 1.0 - std::max(0.0, enemy.timer) / def.bite.telegraph;
        if (enemy.timer <= 0) {
            const Vector2 at = from + Vector2::from_angle(enemy.facing) * (enemy.radius + def.bite.reach * 0.5);
            fire_bite_zone(at, def.bite.radius, 0.0, def.bite.damage, def.color.lightened(0.4), token);
            enemy.charge = 0; enemy.mode = EnemyMode::Recover; enemy.timer = def.bite.rest;
        }
    } else {
        const Vector2 toward = ship_pos - from;
        const double distance = toward.length();
        enemy.vel = toward.length_squared() >= 0.000001 ? toward.normalized() * enemy.speed : Vector2();
        if (enemy.vel.length_squared() > 0.000001) enemy.facing = enemy.vel.angle();
        if (enemy.mode == EnemyMode::Recover) {
            enemy.timer -= bdt;
            if (enemy.timer <= 0) enemy.mode = EnemyMode::Move;
        } else {
            const double reach = enemy.radius + (def.bite.reach + ship_config.ship_radius);
            if (distance * distance <= reach * reach && admit_bite(enemy, bdt)) {
                enemy.mode = EnemyMode::Windup; enemy.timer = def.bite.telegraph; enemy.flash = 0.1;
            }
        }
    }
    enemy.pos += enemy.vel * dt;
}
