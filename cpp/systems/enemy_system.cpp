#include "enemy_system.h"
#include "attack_system.h"
#include "tracking_policy.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
namespace speed {
bool EnemySystem::attack_active(const godot::RunState &state,EnemyHandle handle) {
    if (!state.enemy_handles.contains(handle)) return false;
    const auto &enemy=state.enemies[handle.slot];
    return enemy.mode==godot::RunState::EnemyMode::Windup || enemy.mode==godot::RunState::EnemyMode::Dash || AttackSystem::has_attached(state,handle);
}
bool EnemySystem::attack_due(const RunRuntime &run,EnemyHandle handle,double dt) {
    if (!run.state.enemy_handles.contains(handle)) return false;
    const auto &enemy=run.state.enemies[handle.slot];
    return enemy.fire_t<=run.content->definitions[enemy.definition].attack_telegraph+dt;
}
bool EnemySystem::relocate(RunRuntime &run,EnemyHandle handle,godot::Vector2 position) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(handle) || !position.is_finite()) return false;
    auto &enemy=state.enemies[handle.slot];if (enemy.dead || enemy.held) return false;
    AttackSystem::source_ended(state,handle,AttackEndReason::Relocate);
    enemy.pos=position;
    const auto toward=(state.ship_pos-position).normalized();
    const TrackingPolicy tracking{state.draw.tracing,enemy.held,state.enemy_handles.contains(enemy.pump_owner)};
    enemy.vel=tracking.velocity(enemy.vel,enemy.facing,toward*enemy.speed);
    if (!tracking.locked()) enemy.facing=toward.angle();
    enemy.mode=godot::RunState::EnemyMode::Move;enemy.timer=enemy.charge=0;
    enemy.fire_t=run.content->definitions[enemy.definition].fire_interval;return true;
}
EnemyHandle EnemySystem::insert(godot::RunState &state, uint32_t slot, const godot::RunState::Enemy &enemy) {
    auto handle = state.enemy_handles.attach(slot, enemy.id);
    if (state.enemy_handles.contains(handle)) state.enemies[slot] = enemy;
    return handle;
}
void EnemySystem::leave_hound(godot::RunState &state,size_t row) {
    auto &enemy=state.enemies[row];if (!enemy.in_pack) return;
    auto *members=state.hound_packs.getptr(enemy.pack);
    if (members) {
        members->erase(std::remove(members->begin(),members->end(),row),members->end());
        if (members->empty()) state.hound_packs.erase(enemy.pack);
    }
    enemy.in_pack=false;enemy.pursuit_ready=false;enemy.follow_ready=false;
}
bool EnemySystem::retire(godot::RunState &state,EnemyHandle handle,RetireReason reason) {
    if (!state.enemy_handles.contains(handle)) return false;
    const size_t row=handle.slot;auto &enemy=state.enemies[row];
    if (!enemy.alive) return false;
    AttackSystem::source_ended(state,handle,AttackEndReason::ParticipantEnd);
    leave_hound(state,row);
    auto &rows=state.behavior_rows[enemy.behavior_group];
    const size_t last=rows.back();rows[enemy.behavior_slot]=last;
    state.enemies[last].behavior_slot=enemy.behavior_slot;rows.pop_back();
    CombatEvent event;event.kind=CombatEventKind::Retire;event.retire_reason=reason;
    event.target_id=enemy.id;event.definition=uint32_t(enemy.definition+1);event.pos=enemy.pos;
    event.time=state.time;event.world_time=state.world_time;state.combat_events.push_back(event);
    enemy.alive=false;release(state,uint32_t(row));
    if (state.enemy_handles.reusable(uint32_t(row))) state.free_rows.push_back(row);
    state.rows_by_id.erase(enemy.id);return true;
}
void EnemySystem::release(godot::RunState &state, uint32_t slot) {
    state.enemy_handles.release(state.enemy_handles.at(slot));
}
}
