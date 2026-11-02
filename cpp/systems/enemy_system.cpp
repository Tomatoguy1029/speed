#include "enemy_system.h"
#include "attack_system.h"
#include "group_system.h"
#include "pickup_system.h"
#include "tracking_policy.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
#include <cmath>
namespace speed {
int64_t EnemySystem::spawn_base(RunRuntime &run,size_t definition,const EnemySpawn &p) {
    auto &state=run.state;
    if (!state.started || state.closed || definition>=run.content->definitions.size() || state.next_id==INT64_MAX || !p.position.is_finite() || !p.velocity.is_finite() ||
        !std::isfinite(p.size) || p.size<0 || !std::isfinite(p.spin) || !std::isfinite(p.guard) || !std::isfinite(p.hit_cd) || !std::isfinite(float(p.spin)) || !std::isfinite(p.facing) || !std::isfinite(p.knock) || !std::isfinite(p.value) || !std::isfinite(p.priority) || p.group<0) return -1;
    const auto &def=run.content->definitions[definition];godot::RunState::Enemy enemy;
    enemy.definition=definition;enemy.pos=p.position;enemy.vel=p.velocity;enemy.facing=p.facing;enemy.elite=p.elite;enemy.is_boss=p.is_boss;enemy.knock_t=p.knock;enemy.rock=p.rock;
    enemy.spin=float(p.spin);enemy.guard=p.guard;enemy.hit_cd=p.hit_cd;
    enemy.attack_group=p.group;enemy.attack_priority=p.has_priority?p.priority:def.attack_priority;
    enemy.attack_value=p.group>0?(p.has_value?p.value:1.0):def.attack_value;
    enemy.attack_managed=!state.world.attack_formation_mode?def.attack_weight>0:(p.group>0?(p.has_managed?p.managed:enemy.attack_value>0):def.attack_managed);
    enemy.hp=enemy.max_hp=def.hp;enemy.radius=def.radius;enemy.armor=def.armor;enemy.xp=def.xp;enemy.speed=def.speed;
    if ((p.size>0 || p.elite) && !def.scaling.ready) return -1;
    if (def.scaling.ready) {
        const auto &s=def.scaling;const double size=p.size>0?p.size:s.radius,z=size/s.radius;
        double radius=size*(p.elite?1.25:1.0);if (s.fixed_sprite) radius=s.radius;radius*=s.character;
        enemy.radius=radius*s.visual*s.collision;enemy.hp=enemy.max_hp=s.hp*z*z*s.hp_mult*(p.elite?3.0:1.0);
        enemy.armor=s.armor*z*s.armor_mult*(p.elite?1.3:1.0);enemy.xp=def.xp*z*(p.elite?4.0:1.0);
        for (double value:{enemy.radius,enemy.hp,enemy.armor,enemy.xp}) if (!std::isfinite(value)) return -1;
    }
    while (!state.free_rows.empty() && !state.enemy_handles.reusable(state.free_rows.back())) state.free_rows.pop_back();
    if (state.free_rows.empty() && state.enemies.size()>=UINT32_MAX) return -1;
    size_t row=state.enemies.size();if (state.free_rows.empty()) state.enemies.emplace_back();else {row=state.free_rows.back();state.free_rows.pop_back();}
    const auto found=std::find(state.behavior_kinds.begin(),state.behavior_kinds.end(),def.kind);enemy.behavior_group=found-state.behavior_kinds.begin();
    if (found==state.behavior_kinds.end()) {state.behavior_kinds.push_back(def.kind);state.behavior_rows.emplace_back();}
    auto &rows=state.behavior_rows[enemy.behavior_group];enemy.behavior_slot=rows.size();rows.push_back(row);enemy.id=state.next_id++;
    enemy.fire_t=def.fire_interval*(0.5+state.control.rng.randf()*0.5);enemy.alive=true;
    insert(state,uint32_t(row),enemy);state.rows_by_id[enemy.id]=row;
    return enemy.id;
}
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
    GroupSystem::leave(state,state.enemy_handles.at(uint32_t(row)));
}
bool EnemySystem::retire(RunRuntime &run,EnemyHandle handle,RetireReason reason) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(handle)) return false;
    const size_t row=handle.slot;auto &enemy=state.enemies[row];
    if (!enemy.alive) return false;
    PickupSystem::lose(run,enemy.id,reason==RetireReason::Outside?CargoLoss::Retreat:reason==RetireReason::BonusClear?CargoLoss::Cleared:CargoLoss::Released);
    AttackSystem::source_ended(state,handle,AttackEndReason::ParticipantEnd);
    leave_hound(state,row);
    auto &rows=state.behavior_rows[enemy.behavior_group];
    const size_t last=rows.back();rows[enemy.behavior_slot]=last;
    state.enemies[last].behavior_slot=enemy.behavior_slot;rows.pop_back();
    CombatEvent event;event.kind=CombatEventKind::Retire;event.retire_reason=reason;
    event.target_id=enemy.id;event.definition=uint32_t(enemy.definition+1);event.pos=enemy.pos;
    event.time=state.time;event.world_time=state.world_time;state.combat_events.push_back(event);
    state.dead_rows.erase(std::remove(state.dead_rows.begin(),state.dead_rows.end(),row),state.dead_rows.end());
    enemy.alive=false;release(state,uint32_t(row));
    if (state.enemy_handles.reusable(uint32_t(row))) state.free_rows.push_back(row);
    state.rows_by_id.erase(enemy.id);return true;
}
void EnemySystem::release(godot::RunState &state, uint32_t slot) {
    state.enemy_handles.release(state.enemy_handles.at(slot));
}
}
