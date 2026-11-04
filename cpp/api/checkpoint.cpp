#include "run_core.h"
#include "../runtime/checkpoint.h"
#include "../systems/progression.h"
#include <algorithm>
#include <cmath>
using namespace godot;

Ref<SpeedRunCore> SpeedRunCore::checkpoint() const {
    if (!runtime.state.started || runtime.state.closed) return Ref<SpeedRunCore>();
    Ref<SpeedRunCore> out; out.instantiate();
    out->runtime.state = speed::clone_state(runtime.state);
    out->runtime.content = runtime.content;
    return out;
}
bool SpeedRunCore::update_enemy_definition(StringName id, const Dictionary &data) {
    if (!runtime.state.started || runtime.state.closed) return false;
    auto found=std::find_if(runtime.content->definitions.begin(),runtime.content->definitions.end(),[&](const auto &d){return d.id==id;});
    if (found==runtime.content->definitions.end()) return false;
    Ref<SpeedRunCore> parsed; parsed.instantiate();
    if (!parsed->configure(data) || parsed->runtime.content->definitions.size()!=1 || parsed->runtime.content->definitions[0].id!=id || parsed->runtime.content->definitions[0].kind!=found->kind) return false;
    const auto previous=*found, replacement=parsed->runtime.content->definitions[0];
    const size_t index=found-runtime.content->definitions.begin();
    const double old_hp=previous.scaling.ready?previous.scaling.hp:previous.hp;
    const double new_hp=replacement.scaling.ready?replacement.scaling.hp:replacement.hp;
    const double old_armor=previous.scaling.ready?previous.scaling.armor:previous.armor;
    const double new_armor=replacement.scaling.ready?replacement.scaling.armor:replacement.armor;
    for (auto &e:runtime.state.enemies) {
        if (!e.alive || e.dead || e.definition!=index) continue;
        const double scale=std::sqrt(e.max_hp/std::max(old_hp*(previous.scaling.ready?previous.scaling.hp_mult:1.0)*(e.elite?3.0:1.0),0.001));
        if (new_hp!=old_hp) {
            const double health=e.hp/std::max(e.max_hp,0.001);
            e.max_hp*=new_hp/std::max(old_hp,0.001); e.hp=e.max_hp*health;
        }
        if (new_armor!=old_armor) e.armor=old_armor>0?e.armor*new_armor/old_armor:new_armor*scale*(replacement.scaling.ready?replacement.scaling.armor_mult:1.0)*(e.elite?1.3:1.0);
        if (replacement.speed!=previous.speed) e.speed=previous.speed>0?e.speed*replacement.speed/previous.speed:replacement.speed;
        if (previous.fire_interval>0 && replacement.fire_interval!=previous.fire_interval) e.fire_t*=replacement.fire_interval/previous.fire_interval;
    }
    auto definitions = runtime.content->definitions;
    definitions[index] = replacement;
    runtime.replace_definitions(std::move(definitions)); return true;
}

int64_t SpeedRunCore::hold_checkpoint() const { return speed::CheckpointStore::hold(runtime); }
bool SpeedRunCore::release_checkpoint(int64_t id) { return speed::CheckpointStore::release(id); }
int64_t SpeedRunCore::current_epoch() const { return runtime.epoch; }
bool SpeedRunCore::restore_checkpoint(int64_t id) {
    if (runtime.state.closed || runtime.epoch==INT64_MAX) return false;
    auto checkpoint=speed::CheckpointStore::find(id);
    if (!checkpoint || checkpoint->state_schema_version!=speed::STATE_SCHEMA_VERSION || !checkpoint->content ||
        checkpoint->payload_sha256!=checkpoint->content->payload_sha256) return false;
    Ref<SpeedRunCore> candidate;candidate.instantiate();
    candidate->runtime.state=speed::clone_state(checkpoint->state);
    candidate->runtime.content=checkpoint->content;
    const double grid_cell=candidate->runtime.state.grid.cell;
    // セル境界も候補順に影響するため、保存した範囲を保って索引だけを再構築する。
    if (!speed::rebuild_state_indexes(candidate->runtime.state,*candidate->runtime.content) ||
        !candidate->rebuild_enemy_grid(grid_cell)) return false;
    // 記録区間は保持点の外にあるファイルへ属する。復帰後は新しい途中録画として始める。
    candidate->runtime.state.observations={};
    candidate->runtime.state.recording={};
    candidate->runtime.epoch=runtime.epoch+1;
    candidate->runtime.api_configured=runtime.api_configured;
    candidate->runtime.api_run_id=runtime.api_run_id;
    candidate->runtime.api_development=runtime.api_development;
    candidate->runtime.frame_workspace.metrics=runtime.frame_workspace.metrics;
    candidate->runtime.resource_workspace.next_id=runtime.resource_workspace.next_id;
    if (candidate->runtime.state.loadout.ready) speed::ProgressionSystem::rebuild_requests(candidate->runtime);
    candidate->runtime.full_output_dirty=true;
    candidate->runtime.pending_resource_rebuild=true;
    runtime=std::move(candidate->runtime);
    return true;
}
