#include "enemy_system.h"
namespace speed {
EnemyHandle EnemySystem::insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy) {
    auto handle = state.enemy_handles.attach(slot, enemy.id);
    if (state.enemy_handles.contains(handle)) state.enemies[slot] = enemy;
    return handle;
}
void EnemySystem::release(godot::RunState &state, uint32_t slot) {
    state.enemy_handles.release(state.enemy_handles.at(slot));
}
void EnemySystem::aim_chase(godot::RunState::Enemy &enemy, godot::Vector2 ship) {
    const auto toward = ship - enemy.pos;
    const double distance = toward.length();
    enemy.vel = godot::Vector2();
    if (distance > 0.001) {
        const auto unit = toward / distance;
        enemy.vel = unit * enemy.speed;
        enemy.facing = unit.angle();
    }
}
}
