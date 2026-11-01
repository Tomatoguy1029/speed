#include "checkpoint.h"
#include <cmath>
#include <limits>
#include <unordered_set>
namespace speed {
namespace {
int64_t next_checkpoint_id=1;
std::unordered_map<int64_t,std::shared_ptr<const RunCheckpoint>> checkpoints;
bool value_only(const godot::Variant &value,unsigned depth=0) {
    if (depth>64 || value.get_type()==godot::Variant::OBJECT || value.get_type()==godot::Variant::CALLABLE || value.get_type()==godot::Variant::SIGNAL) return false;
    if (value.get_type()==godot::Variant::DICTIONARY) {
        const godot::Dictionary data=value;const auto keys=data.keys();
        for (int64_t i=0;i<keys.size();++i) if (!value_only(keys[i],depth+1) || !value_only(data[keys[i]],depth+1)) return false;
    } else if (value.get_type()==godot::Variant::ARRAY) {
        const godot::Array data=value;
        for (int64_t i=0;i<data.size();++i) if (!value_only(data[i],depth+1)) return false;
    }
    return true;
}
}
godot::RunState clone_state(const godot::RunState &source) {
    auto state=source;
    state.events=source.events.duplicate(true);
    state.collections=source.collections.duplicate(true);
    state.progression.data=source.progression.data.duplicate(true);
    state.progression.stats=source.progression.stats.duplicate(true);
    state.progression.weapons=source.progression.weapons.duplicate(true);
    state.progression.traits=source.progression.traits.duplicate(true);
    state.progression.cards=source.progression.cards.duplicate(true);
    state.progression.resource_requests=source.progression.resource_requests.duplicate(true);
    state.forward_parameters=source.forward_parameters.duplicate(true);
    return state;
}
bool rebuild_state_indexes(godot::RunState &state,const ContentBundle &content) {
    if (!state.started || state.closed || state.next_id<=0 ||
        !std::isfinite(state.time) || !std::isfinite(state.world_time) || !std::isfinite(state.sim_time) ||
        !std::isfinite(state.grid.cell) || state.grid.cell<=0 || state.enemies.size()>=UINT32_MAX ||
        state.behavior_kinds.size()!=state.behavior_rows.size()) return false;
    if (!std::isfinite(state.control.world_real_accum) || !std::isfinite(state.control.world_dt_accum) ||
        state.control.world_real_accum<0 || state.control.world_dt_accum<0 || state.control.world_tick_div<1 ||
        state.control.world_steps<0 || state.control.world_steps>=state.control.world_tick_div) return false;
    state.rows_by_id.clear();
    std::unordered_set<size_t> visited,free;
    for (size_t group=0;group<state.behavior_rows.size();++group) {
        const auto &rows=state.behavior_rows[group];
        for (size_t slot=0;slot<rows.size();++slot) {
            const auto row=rows[slot];
            if (row>=state.enemies.size() || !visited.insert(row).second) return false;
            auto &enemy=state.enemies[row];
            if (!enemy.alive || enemy.definition>=content.definitions.size() ||
                content.definitions[enemy.definition].kind!=state.behavior_kinds[group]) return false;
            enemy.behavior_group=group;enemy.behavior_slot=slot;
        }
    }
    for (size_t row=0;row<state.enemies.size();++row) {
        const auto &enemy=state.enemies[row];
        const auto handle=state.enemy_handles.at(uint32_t(row));
        if (!enemy.alive) { if (state.enemy_handles.contains(handle)) return false;continue; }
        if (!visited.count(row) || enemy.id<=0 || enemy.id>=state.next_id ||
            state.enemy_handles.entity_id(handle)!=enemy.id || !enemy.pos.is_finite() || !enemy.vel.is_finite() ||
            !std::isfinite(enemy.hp) || !std::isfinite(enemy.max_hp) || !std::isfinite(enemy.radius) || enemy.radius<=0 ||
            !state.rows_by_id.emplace(enemy.id,row).second) return false;
    }
    for (auto row:state.free_rows) {
        if (row>=state.enemies.size() || state.enemies[row].alive || !free.insert(row).second ||
            !state.enemy_handles.reusable(uint32_t(row))) return false;
    }
    for (auto row:state.dead_rows) if (row>=state.enemies.size() || !state.enemies[row].alive || !state.enemies[row].dead) return false;
    for (const auto &pack:state.hound_packs) for (auto row:pack.value)
        if (row>=state.enemies.size() || !state.enemies[row].alive || !state.enemies[row].in_pack || state.enemies[row].pack!=pack.key) return false;
    return true;
}
int64_t CheckpointStore::hold(const RunRuntime &runtime) {
    if (!runtime.content || next_checkpoint_id==INT64_MAX) return 0;
    const auto &progression=runtime.state.progression;
    if (!value_only(progression.data) || !value_only(progression.stats) || !value_only(progression.weapons) ||
        !value_only(progression.traits) || !value_only(progression.cards) || !value_only(runtime.state.forward_parameters)) return 0;
    auto checkpoint=std::make_shared<RunCheckpoint>();
    checkpoint->content=runtime.content;
    checkpoint->payload_sha256=runtime.content->payload_sha256;
    checkpoint->state=clone_state(runtime.state);
    if (!rebuild_state_indexes(checkpoint->state,*checkpoint->content)) return 0;
    // 配信済みの音・結果や、外部の要求を再発行しない。
    checkpoint->state.events.clear();checkpoint->state.combat_events.clear();checkpoint->state.collections.clear();
    checkpoint->state.progression.resource_requests.clear();
    const int64_t id=next_checkpoint_id++;
    checkpoints.emplace(id,std::move(checkpoint));return id;
}
std::shared_ptr<const RunCheckpoint> CheckpointStore::find(int64_t id) {
    auto found=checkpoints.find(id);return found==checkpoints.end()?nullptr:found->second;
}
bool CheckpointStore::release(int64_t id) {return checkpoints.erase(id)!=0;}
}
