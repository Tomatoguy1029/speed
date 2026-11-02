#include "group_system.h"
#include <unordered_set>
#include <cmath>
namespace speed {
void GroupSystem::join(godot::RunState &state,EnemyHandle actor,int64_t group) {
    if (!state.enemy_handles.contains(actor)) return;
    leave(state,actor);
    if (!state.groups.groups.getptr(group)) state.groups.groups.insert(group,{});
    state.groups.groups[group].members.insert(state.enemy_handles.entity_id(actor),{actor,{}});
    state.enemies[actor.slot].group_id=group;
}
void GroupSystem::leave(godot::RunState &state,EnemyHandle actor) {
    if (!state.enemy_handles.contains(actor)) return;
    auto &enemy=state.enemies[actor.slot];const auto group=enemy.group_id;
    if (auto *g=state.groups.groups.getptr(group)) {
        g->members.erase(enemy.id);
        if (g->members.is_empty()) state.groups.groups.erase(group);
    }
    enemy.group_id=0;enemy.pursuit_ready=false;
}
HoundOrder *GroupSystem::order(godot::RunState &state,EnemyHandle actor) {
    if (!state.enemy_handles.contains(actor) || state.enemies[actor.slot].dead) return nullptr;
    auto *group=state.groups.groups.getptr(state.enemies[actor.slot].group_id);if (!group) return nullptr;
    auto *member=group->members.getptr(state.enemy_handles.entity_id(actor));
    return member && same_handle(member->actor,actor)?&member->order:nullptr;
}
const HoundOrder *GroupSystem::order(const godot::RunState &state,EnemyHandle actor) {
    if (!state.enemy_handles.contains(actor) || state.enemies[actor.slot].dead) return nullptr;
    const auto *group=state.groups.groups.getptr(state.enemies[actor.slot].group_id);if (!group) return nullptr;
    const auto *member=group->members.getptr(state.enemy_handles.entity_id(actor));
    return member && same_handle(member->actor,actor)?&member->order:nullptr;
}
bool GroupSystem::follow(godot::RunState &state,EnemyHandle actor,godot::Vector2 goal,double until,double scale) {
    auto *o=order(state,actor);if (!o) return false;o->follow=true;o->follow_goal=goal;o->follow_until=until;o->follow_scale=scale;return true;
}
bool GroupSystem::steer(godot::RunState &state,EnemyHandle actor,godot::Vector2 goal,godot::Vector2 face,double until,const HoundSteering &config) {
    auto *o=order(state,actor);if (!o) return false;
    if (!o->steer) {o->heading=state.enemies[actor.slot].facing;o->speed=state.enemies[actor.slot].vel.length();}
    o->steer=true;o->steer_goal=goal;o->face_point=face;o->steer_until=until;o->steering=config;return true;
}
bool GroupSystem::quiet(godot::RunState &state,EnemyHandle actor,double until,bool has_velocity,godot::Vector2 velocity) {
    auto *o=order(state,actor);if (!o) return false;o->quiet=true;o->quiet_until=until;o->quiet_velocity_set=has_velocity;o->quiet_velocity=velocity;return true;
}
bool GroupSystem::mark(godot::RunState &state,EnemyHandle actor,double until) {
    auto *o=order(state,actor);if (!o) return false;o->warning=true;o->warning_until=until;return true;
}
bool GroupSystem::release_order(godot::RunState &state,EnemyHandle actor) {auto *o=order(state,actor);if (!o) return false;*o={};return true;}
bool GroupSystem::warning(const godot::RunState &state,EnemyHandle actor) {const auto *o=order(state,actor);return o && o->warning && o->warning_until>state.world_time;}
bool GroupSystem::validate(const godot::RunState &state) {
    std::unordered_set<int64_t> seen;
    for (const auto &g:state.groups.groups) {
        if (g.value.members.is_empty() || !g.value.target.is_finite()) return false;
        if (g.value.kind==Group::Kind::Cepheus && (!g.value.formation.anchor.is_finite() || g.value.formation.tier<1 || g.value.formation.tier>3)) return false;
        for (const auto &m:g.value.members) if (!state.enemy_handles.contains(m.value.actor) ||
            state.enemy_handles.entity_id(m.value.actor)!=m.key || !seen.insert(m.key).second ||
            state.enemies[m.value.actor.slot].group_id!=g.key) return false;
    }
    for (const auto &e:state.enemies) if (e.alive && e.group_id && !seen.count(e.id)) return false;
    for (const auto &m:state.groups.summon_marks) if (!m.pos.is_finite() || !m.king.is_finite() || !std::isfinite(m.age) || m.age<0 || !std::isfinite(m.life) || m.life<=0) return false;
    return true;
}
}
