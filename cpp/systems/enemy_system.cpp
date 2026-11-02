#include "enemy_system.h"
#include "../bosses/flow/phase_controller.h"
#include "../behaviors/enemies/phoenix.h"
#include "../behaviors/enemies/defender.h"
#include "../behaviors/enemies/crab.h"
#include "../behaviors/enemies/crow.h"
#include "../behaviors/enemies/pump.h"
#include "../behaviors/enemies/corona_vortex.h"
#include "attack_system.h"
#include "attack_budget.h"
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
        !std::isfinite(p.size) || p.size<0 || !std::isfinite(p.spin) || !std::isfinite(p.guard) || !std::isfinite(p.hit_cd) || !std::isfinite(p.facing) || !std::isfinite(p.knock) || !std::isfinite(p.value) || !std::isfinite(p.priority) || p.group<0) return -1;
    const auto &def=run.content->definitions[definition];godot::RunState::Enemy enemy;
    if (def.kind==EnemyDefinition::Kind::Sniper) enemy.behavior_state=SniperState{};
    if (def.kind==EnemyDefinition::Kind::Marlin) enemy.behavior_state=MarlinState{};
    if (def.kind==EnemyDefinition::Kind::Phoenix) enemy.behavior_state=PhoenixState{};
    if (def.kind==EnemyDefinition::Kind::Aquila) enemy.behavior_state=AquilaState{};
    if (def.kind==EnemyDefinition::Kind::Crab) enemy.behavior_state=CrabState{};
    if (def.kind==EnemyDefinition::Kind::Pump) enemy.behavior_state=PumpState{};
    if (def.kind==EnemyDefinition::Kind::Corona) enemy.behavior_state=CoronaState{};
    if (def.kind==EnemyDefinition::Kind::Lynx) enemy.behavior_state=LynxState{};
    if (def.kind==EnemyDefinition::Kind::Ruler) enemy.behavior_state=RulerState{};
    if (def.kind==EnemyDefinition::Kind::Cepheus) enemy.behavior_state=CepheusState{};
    if (def.kind==EnemyDefinition::Kind::Soldier) enemy.behavior_state=SoldierState{};
    if (def.kind==EnemyDefinition::Kind::Auriga) enemy.behavior_state=AurigaState{};
    if (def.kind==EnemyDefinition::Kind::Clock) enemy.behavior_state=ClockState{};
    if (def.kind==EnemyDefinition::Kind::Reticle) enemy.behavior_state=ReticleState{};
    if (def.kind==EnemyDefinition::Kind::Split) enemy.behavior_state=SplitState{};
    if (def.kind==EnemyDefinition::Kind::Crow) enemy.behavior_state=CrowState{};
    if (def.kind==EnemyDefinition::Kind::Defender) {enemy.behavior_state=DefenderState{};run.workspace.defender_posts_tick=-1;}
    enemy.definition=definition;enemy.pos=p.position;enemy.vel=p.velocity;enemy.facing=p.facing;enemy.elite=p.elite;enemy.is_boss=p.is_boss;enemy.knock_t=p.knock;enemy.rock=p.rock;
    if (def.kind==EnemyDefinition::Kind::Marlin && !p.has_facing && enemy.vel.length_squared()>0.001) enemy.facing=enemy.vel.angle();
    enemy.spin=p.spin;enemy.guard=p.guard;enemy.hit_cd=p.hit_cd;
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
    enemy.fire_t=p.is_boss?0:def.fire_interval*(0.5+state.control.rng.randf()*0.5);enemy.alive=true;
    insert(state,uint32_t(row),enemy);state.rows_by_id[enemy.id]=row;
    if (def.kind==EnemyDefinition::Kind::Crab && !p.has_facing) CrabBehavior::steer(run,uint32_t(row));
    if (def.kind==EnemyDefinition::Kind::Crow) CrowBehavior::spawned(run,state.enemy_handles.at(uint32_t(row)),p.flock_member);
    return enemy.id;
}
void EnemySystem::flush_spawns(RunRuntime &run) {
    auto pending=std::move(run.state.pending_enemies);run.state.pending_enemies.clear();
    for (const auto &entry:pending) {
        EnemySpawn p;p.position=entry.position;p.velocity=entry.velocity;p.facing=entry.facing;p.has_facing=true;
        p.hit_cd=entry.hit_cd;p.guard=entry.guard;p.knock=entry.knock;p.priority=entry.priority;p.has_priority=true;
        spawn_base(run,entry.definition-1,p);
    }
}
int64_t EnemySystem::spawn_part(RunRuntime &run,EnemyHandle parent,size_t definition,godot::Vector2 position) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(parent) || state.enemies[parent.slot].dead || definition>=run.content->definitions.size() || (run.content->definitions[definition].kind!=EnemyDefinition::Kind::Part && run.content->definitions[definition].kind!=EnemyDefinition::Kind::TriangleStar)) return -1;
    const auto parent_id=state.enemies[parent.slot].id;const bool held=state.enemies[parent.slot].held;
    EnemySpawn options;options.position=position;options.group=state.enemies[parent.slot].attack_group;
    options.value=state.enemies[parent.slot].attack_value;options.priority=state.enemies[parent.slot].attack_priority;options.has_value=options.has_priority=true;
    const auto id=spawn_base(run,definition,options);if (id<0) return id;
    const auto row=state.rows_by_id.at(id);auto &part=state.enemies[row];part.parent=parent;part.parent_id=parent_id;part.held=held;
    state.enemies[parent.slot].parts.push_back(state.enemy_handles.at(uint32_t(row)));return id;
}
bool EnemySystem::move_part(RunRuntime &run,EnemyHandle part,EnemyHandle parent,godot::Vector2 position,double facing) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(part) || !state.enemy_handles.contains(parent) || state.enemies[part.slot].dead || state.enemies[parent.slot].dead ||
        !same_handle(state.enemies[part.slot].parent,parent) || !position.is_finite() || !std::isfinite(facing)) return false;
    auto &enemy=state.enemies[part.slot];enemy.pos=position;enemy.facing=facing;return true;
}
size_t EnemySystem::parts_alive(const godot::RunState &state,EnemyHandle parent) {
    if (!state.enemy_handles.contains(parent)) return 0;
    size_t count=0;for (auto part:state.enemies[parent.slot].parts) if (state.enemy_handles.contains(part) && !state.enemies[part.slot].dead) ++count;
    return count;
}
bool EnemySystem::attack_active(const godot::RunState &state,EnemyHandle handle) {
    if (!state.enemy_handles.contains(handle)) return false;
    const auto &enemy=state.enemies[handle.slot];
    if (std::holds_alternative<PhoenixState>(enemy.behavior_state) && enemy.mode==godot::RunState::EnemyMode::Move && enemy.timer>0) return true;
    if (const auto *clock=std::get_if<ClockState>(&enemy.behavior_state)) return clock->hands[0].generation!=0;
    if (std::holds_alternative<AurigaState>(enemy.behavior_state)) return true;
    if (const auto *ruler=std::get_if<RulerState>(&enemy.behavior_state)) return enemy.mode==EnemyMode::Windup || enemy.mode==EnemyMode::Recover || ruler->beam.generation!=0;
    if (std::holds_alternative<SniperState>(enemy.behavior_state)) return enemy.mode==EnemyMode::Windup || enemy.charge>0;
    return enemy.mode==godot::RunState::EnemyMode::Windup || enemy.mode==godot::RunState::EnemyMode::Dash || AttackSystem::has_attached(state,handle);
}
bool EnemySystem::attack_due(const RunRuntime &run,EnemyHandle handle,double dt) {
    if (!run.state.enemy_handles.contains(handle)) return false;
    const auto &enemy=run.state.enemies[handle.slot];
    const auto &definition=run.content->definitions[enemy.definition];
    if (definition.kind==EnemyDefinition::Kind::Sniper || definition.kind==EnemyDefinition::Kind::Clock || definition.kind==EnemyDefinition::Kind::Reticle || definition.kind==EnemyDefinition::Kind::Phoenix || definition.kind==EnemyDefinition::Kind::Crab) return true;
    if (definition.kind==EnemyDefinition::Kind::Dolphin || definition.kind==EnemyDefinition::Kind::Aquarius || definition.kind==EnemyDefinition::Kind::Cross) return enemy.fire_t<=dt;
    if (definition.kind==EnemyDefinition::Kind::Ruler) return std::get<RulerState>(enemy.behavior_state).side!=0 && enemy.mode==EnemyMode::Dash && enemy.timer<=dt;
    if (definition.kind==EnemyDefinition::Kind::Cepheus) return std::get<CepheusState>(enemy.behavior_state).tier>0 && enemy.mode==EnemyMode::Move && enemy.timer<=dt;
    if (definition.kind==EnemyDefinition::Kind::Corona) return enemy.fire_t<=dt;
    if (definition.kind==EnemyDefinition::Kind::Pump) return std::get<PumpState>(enemy.behavior_state).contents.size()>=run.content->pumps[definition.pump_definition-1].store_max;
    if (definition.kind==EnemyDefinition::Kind::Bomber) return enemy.pos.distance_to(run.state.ship_pos)<=run.content->bombers[definition.bomber_definition-1].trigger;
    if (definition.kind==EnemyDefinition::Kind::Dash) return enemy.pos.distance_to(run.state.enemy_aim)<=run.content->dashes[definition.dash_definition-1].range;
    return enemy.fire_t<=definition.attack_telegraph+dt;
}
bool EnemySystem::relocate(RunRuntime &run,EnemyHandle handle,godot::Vector2 position) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(handle) || !position.is_finite()) return false;
    auto &enemy=state.enemies[handle.slot];if (enemy.dead || enemy.held) return false;
    CoronaVortex::release(run,handle);PumpBehavior::gone(run,handle,false);
    PhaseController::cancel(run,handle);
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
void EnemySystem::clear_regular(RunRuntime &run) {
    auto &state=run.state;AttackBudgetSystem budget(run);
    for (uint32_t row=0;row<state.enemies.size();++row) {
        const auto &e=state.enemies[row];if (!e.alive || e.dead || e.is_boss || state.field.rock_handles.contains(e.rock) || (state.enemy_handles.contains(e.parent) && state.enemies[e.parent.slot].is_boss && !state.enemies[e.parent.slot].dead)) continue;
        const auto owner=AttackBudgetSystem::owner(state,e.id,e.attack_group);budget.cancel(owner,e.id);mark_dead(run,state.enemy_handles.at(row));
    }
}
bool EnemySystem::mark_dead(RunRuntime &run,EnemyHandle handle) {
    auto &state=run.state;if (!state.enemy_handles.contains(handle) || state.enemies[handle.slot].dead) return false;
    PhoenixBehavior::cancel(run,handle);DefenderBehavior::gone(run,handle);state.enemies[handle.slot].dead=true;state.dead_rows.push_back(handle.slot);CoronaVortex::release(run,handle);PumpBehavior::gone(run,handle,true);AttackSystem::source_ended(state,handle,AttackEndReason::ParticipantEnd);leave_hound(state,handle.slot);return true;
}
bool EnemySystem::retire(RunRuntime &run,EnemyHandle handle,RetireReason reason) {
    auto &state=run.state;
    if (!state.enemy_handles.contains(handle)) return false;
    const size_t row=handle.slot;auto &enemy=state.enemies[row];
    if (!enemy.alive) return false;
    PhoenixBehavior::cancel(run,handle);
    DefenderBehavior::gone(run,handle);
    CrabBehavior::clear(run,handle);
    PumpBehavior::gone(run,handle,true);
    CoronaVortex::release(run,handle);
    PickupSystem::lose(run,enemy.id,reason==RetireReason::Outside?CargoLoss::Retreat:reason==RetireReason::BonusClear?CargoLoss::Cleared:CargoLoss::Released);
    PhaseController::cancel(run,handle);
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
