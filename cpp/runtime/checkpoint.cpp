#include "checkpoint.h"
#include "../systems/attack_system.h"
#include "../systems/group_system.h"
#include "../systems/field.h"
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
    state.legacy_progression.data=source.legacy_progression.data.duplicate(true);
    state.legacy_progression.stats=source.legacy_progression.stats.duplicate(true);
    state.legacy_progression.weapons=source.legacy_progression.weapons.duplicate(true);
    state.legacy_progression.traits=source.legacy_progression.traits.duplicate(true);
    state.legacy_progression.cards=source.legacy_progression.cards.duplicate(true);
    state.legacy_progression.resource_requests=source.legacy_progression.resource_requests.duplicate(true);
    state.forward_parameters=source.forward_parameters.duplicate(true);
    return state;
}
bool rebuild_state_indexes(godot::RunState &state,const ContentBundle &content) {
    if (state.ship.shield_source_definition>content.definitions.size()) return false;
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
    for (const auto &enemy:state.enemies) if (enemy.alive) {
        if (state.enemy_handles.contains(enemy.parent) && state.enemy_handles.entity_id(enemy.parent)!=enemy.parent_id) return false;
        const auto *sniper=std::get_if<SniperState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Sniper)!=(sniper!=nullptr)) return false;
        if (sniper) {if (!sniper->rays.empty() && sniper->rays.size()!=48) return false;for (float v:sniper->rays) if (!std::isfinite(v) || v<0) return false;}
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Auriga)!=std::holds_alternative<AurigaState>(enemy.behavior_state)) return false;
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Clock)!=std::holds_alternative<ClockState>(enemy.behavior_state)) return false;
        if (const auto *clock=std::get_if<ClockState>(&enemy.behavior_state)) for (auto hand:clock->hands) if (const auto *record=AttackSystem::get(state,hand)) {if (!record->spec.owner.attached || !same_handle(record->spec.owner.live_source,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id))))) return false;}
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Reticle)!=std::holds_alternative<ReticleState>(enemy.behavior_state)) return false;
        if (const auto *reticle=std::get_if<ReticleState>(&enemy.behavior_state)) if (state.enemy_handles.contains(reticle->rock) && state.enemy_handles.entity_id(reticle->rock)!=reticle->rock_id) return false;
        const auto *soldier=std::get_if<SoldierState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Soldier)!=(soldier!=nullptr)) return false;
        if (soldier && (!soldier->formation.anchor.is_finite() || soldier->formation.tier<1 || soldier->formation.tier>3 || (state.enemy_handles.contains(soldier->king) && state.enemy_handles.entity_id(soldier->king)!=soldier->king_id))) return false;
        const auto *lynx=std::get_if<LynxState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Lynx)!=(lynx!=nullptr)) return false;
        const auto *marlin=std::get_if<MarlinState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Marlin)!=(marlin!=nullptr) || (marlin && !marlin->anchor.is_finite())) return false;
        std::unordered_set<uint64_t> parts;
        for (auto part:enemy.parts) {
            if (!parts.insert(handle_key(part)).second) return false;
            if (state.enemy_handles.contains(part) && (state.enemies[part.slot].parent_id!=enemy.id || !same_handle(state.enemies[part.slot].parent,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id)))))) return false;
        }
    }
    for (auto row:state.free_rows) {
        if (row>=state.enemies.size() || state.enemies[row].alive || !free.insert(row).second ||
            !state.enemy_handles.reusable(uint32_t(row))) return false;
    }
    for (auto row:state.dead_rows) if (row>=state.enemies.size() || !state.enemies[row].alive || !state.enemies[row].dead) return false;
    for (const auto &shot:state.friends) if (shot.alive) {
        if (shot.definition>content.friend_shots.size()) return false;
        if (shot.kind==int64_t(FriendKind::Hull)) {
            if (!shot.hull.definition || shot.hull.definition>content.friend_hulls.size() || (!shot.hull.saw && (!shot.hull.source_definition || shot.hull.source_definition>content.definitions.size())) ||
                shot.hull.source_id< -1 || !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.angle) || !std::isfinite(shot.spin)) return false;
        }
        if (shot.kind==int64_t(FriendKind::Debris)) {
            if (!shot.debris.definition || shot.debris.definition>content.friend_debris.size() || shot.debris.style>=DebrisStyle::Count || shot.shatter_depth<0 ||
                !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.angle) || !std::isfinite(shot.spin)) return false;
            for (auto point:shot.trail) if (!point.is_finite()) return false;
        }
    }
    for (const auto &shot:state.hostiles) if (shot.alive) {
        if (shot.definition>content.hostile_definitions.size()) return false;
        if (shot.kind==int64_t(HostileKind::Shell)) {
            if (!shot.shell.definition || shot.shell.definition>content.shells.size() || !shot.pos.is_finite() || !shot.vel.is_finite() || !shot.shell.mouth.is_finite() || !std::isfinite(shot.shell.burst) || shot.shell.burst<0 || !std::isfinite(shot.shell.full) || shot.shell.full<0 || shot.shell.full>1 || !std::isfinite(shot.radius) || shot.radius<0 || !std::isfinite(shot.life) || !std::isfinite(shot.damage) || shot.damage<0) return false;
            for (auto definition:shot.shell.contents) if (!definition || definition>content.definitions.size()) return false;
        } else if (shot.shell.definition) return false;
        if (shot.kind==int64_t(HostileKind::Slash)) {
            if (shot.slash.definition!=1 || content.slashes.empty() || (shot.slash.side!=1 && shot.slash.side!=-1) ||
                !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.radius) || shot.radius<=0 ||
                !std::isfinite(shot.speed) || shot.speed<0 || !std::isfinite(shot.life) || !std::isfinite(shot.damage) || shot.damage<0) return false;
        } else if (shot.slash.definition) return false;
        if (shot.kind==int64_t(HostileKind::Bolt)) {
            if (!shot.bolt.definition || shot.bolt.definition>content.bolts.size() || !shot.pos.is_finite() || !shot.vel.is_finite() ||
                !std::isfinite(shot.radius) || shot.radius<=0 || !std::isfinite(shot.speed) || shot.speed<0 || !std::isfinite(shot.life) ||
                !std::isfinite(shot.damage) || shot.damage<0) return false;
        } else if (shot.bolt.definition) return false;
        if (shot.kind==int64_t(HostileKind::StarBolt)) {
            if (!shot.star_bolt.definition || shot.star_bolt.definition>content.star_bolts.size() || !shot.pos.is_finite() || !shot.vel.is_finite() ||
                !std::isfinite(shot.radius) || shot.radius<=0 || !std::isfinite(shot.speed) || shot.speed<0 || !std::isfinite(shot.life) || !std::isfinite(shot.damage) || shot.damage<0) return false;
        } else if (shot.star_bolt.definition) return false;
        if (shot.kind==int64_t(HostileKind::LightArrow) || shot.kind==int64_t(HostileKind::CosmicArrow)) {
            if (!shot.arrow.definition || shot.arrow.definition>content.light_arrows.size() || !std::isfinite(shot.arrow.length) || shot.arrow.length<0 ||
                content.light_arrows[shot.arrow.definition-1].cosmic!=(shot.kind==int64_t(HostileKind::CosmicArrow)) ||
                !shot.pos.is_finite() || !shot.vel.is_finite() || !std::isfinite(shot.radius) || shot.radius<=0 || !std::isfinite(shot.speed) || shot.speed<=0 ||
                !std::isfinite(shot.life) || !std::isfinite(shot.damage) || shot.damage<0) return false;
        } else if (shot.arrow.definition) return false;
    }
    std::unordered_set<uint64_t> lance_ids;
    for (const auto &lance:state.attacks.lances) {
        if (!lance.id || lance.id>=state.attacks.next_lance_id || !lance_ids.insert(lance.id).second || !lance.definition || lance.definition>content.light_lances.size() || !lance.from.is_finite() || !lance.velocity.is_finite()) return false;
        for (double value:{lance.length,lance.width,lance.damage,lance.knock,lance.life}) if (!std::isfinite(value) || value<0) return false;
        for (auto id:lance.hits) if (id<=0) return false;
    }
    for (const auto &hazard:state.hazards) if (hazard.alive) {
        if (!hazard.pos.is_finite() || !std::isfinite(hazard.time) || !std::isfinite(hazard.delay) || !std::isfinite(hazard.duration) || !std::isfinite(hazard.damage)) return false;
        if (hazard.zone_definition && (hazard.zone_definition>content.zones.size() || !std::holds_alternative<CircleHazard>(hazard.shape) || std::get<CircleHazard>(hazard.shape).kind!=CircleHazardKind::Blast || !std::isfinite(hazard.enemy_damage) || hazard.enemy_damage<0)) return false;
        if (const auto *beam=std::get_if<BeamHazard>(&hazard.shape)) {
            if ((beam->style==uint32_t(BeamStyle::Flood) && content.floods.empty()) || beam->flood_group<0 || beam->style>=uint32_t(BeamStyle::Count) || !beam->definition || beam->definition>content.beams.size() || !std::isfinite(beam->angle) || !std::isfinite(beam->length) || beam->length<0 ||
                !std::isfinite(beam->half_width) || beam->half_width<0 || !std::isfinite(beam->arc)) return false;
        }
        if (const auto *wall=std::get_if<WallHazard>(&hazard.shape)) {
            if (!wall->definition || wall->definition>content.walls.size() || wall->style>=uint32_t(WallStyle::Count) ||
                !std::isfinite(wall->angle) || !std::isfinite(wall->length) || wall->length<0 || !std::isfinite(wall->half_width) || wall->half_width<0) return false;
        }
        if (const auto *wave=std::get_if<WaveHazard>(&hazard.shape)) {
            if (!wave->definition || wave->definition>content.waves.size() || wave->style>=uint32_t(WaveStyle::Count) || !std::isfinite(wave->enemy_damage) || wave->enemy_damage<0) return false;
            for (double value:{wave->radius,wave->start_radius,wave->speed,wave->half_width,wave->gap_arc,wave->arc}) if (!std::isfinite(value) || value<0) return false;
            if (wave->start_radius>wave->radius || !std::isfinite(wave->angle) || !std::isfinite(wave->gap)) return false;
            std::unordered_set<int64_t> hits;for (auto id:wave->enemy_hits) if (id<=0 || !hits.insert(id).second) return false;
        }
    }
    std::unordered_set<uint64_t> crystal_ids,ground_orders;
    int64_t live_crystals=0;
    for (const auto &gem:state.pickups.gems) if (gem.alive) {
        ++live_crystals;
        if (!gem.id || gem.id>=state.pickups.next_id || gem.order>=state.pickups.next_ground_order || gem.kind>2 || !std::isfinite(gem.value) || gem.value<0 ||
            !crystal_ids.insert(gem.id).second || !ground_orders.insert(gem.order).second || !gem.pos.is_finite() || !gem.velocity.is_finite() || !std::isfinite(gem.wait) || gem.wait<0 ||
            gem.origin.definition>content.definitions.size()) return false;
    }
    std::unordered_set<int64_t> carriers;
    for (const auto &cargo:state.pickups.cargo) {
        if (!carriers.insert(cargo.enemy_id).second || !state.enemy_handles.contains(cargo.owner) || state.enemy_handles.entity_id(cargo.owner)!=cargo.enemy_id || cargo.crystals.empty()) return false;
        for (const auto &gem:cargo.crystals) if (!gem.id || gem.id>=state.pickups.next_id || gem.kind>2 || !std::isfinite(gem.value) || gem.value<0 || !crystal_ids.insert(gem.id).second ||
            gem.origin.definition>content.definitions.size() || !std::isfinite(gem.origin.run_time) || !std::isfinite(gem.origin.world_time)) return false;
    }
    auto &pickups=state.pickups;
    if (live_crystals!=pickups.live_gems || (state.pickup_config.fixed_rewards && live_crystals>state.pickup_config.gem_max)) return false;
    // 行番号は索引。保持した集約先のIDから再構築する。
    pickups.gem_absorber=-1;
    for (size_t row=0;row<pickups.gems.size();++row) {
        const auto &gem=pickups.gems[row];
        if (gem.alive && gem.kind==2 && gem.id==pickups.gem_absorber_id) {pickups.gem_absorber=int64_t(row);break;}
    }
    if (pickups.gem_absorber<0) pickups.gem_absorber_id=0;
    for (auto weapon:state.loadout.pending_comet_weapons) if (!weapon || weapon>content.equipment.size() || !content.equipment[weapon-1].comet_only) return false;
    for (const auto &capsule:pickups.capsules) if (!capsule.pos.is_finite() || !std::isfinite(capsule.age) || capsule.age<0 || (capsule.kind==CapsuleKind::CometWeapon && (!capsule.weapon || capsule.weapon>content.equipment.size() || !content.equipment[capsule.weapon-1].comet_only))) return false;
    if (!FieldSystem::validate(state,content)) return false;
    if (!GroupSystem::validate(state)) return false;
    return AttackSystem::rebuild(state);
}
int64_t CheckpointStore::hold(const RunRuntime &runtime) {
    if (!runtime.workspace.friend_birth_batches.empty()) return 0;
    if (runtime.state.attacks.hostile_updating || runtime.state.attacks.hostile_clear_pending || !runtime.content || next_checkpoint_id==INT64_MAX) return 0;
    const auto &progression=runtime.state.legacy_progression;
    if (!value_only(progression.data) || !value_only(progression.stats) || !value_only(progression.weapons) ||
        !value_only(progression.traits) || !value_only(progression.cards) || !value_only(runtime.state.forward_parameters)) return 0;
    auto checkpoint=std::make_shared<RunCheckpoint>();
    checkpoint->content=runtime.content;
    checkpoint->payload_sha256=runtime.content->payload_sha256;
    checkpoint->state=clone_state(runtime.state);
    if (!rebuild_state_indexes(checkpoint->state,*checkpoint->content)) return 0;
    // 配信済みの音・結果や、外部の要求を再発行しない。
    checkpoint->state.events.clear();checkpoint->state.combat_events.clear();checkpoint->state.collections.clear();
    checkpoint->state.legacy_progression.resource_requests.clear();
    const int64_t id=next_checkpoint_id++;
    checkpoints.emplace(id,std::move(checkpoint));return id;
}
std::shared_ptr<const RunCheckpoint> CheckpointStore::find(int64_t id) {
    auto found=checkpoints.find(id);return found==checkpoints.end()?nullptr:found->second;
}
bool CheckpointStore::release(int64_t id) {return checkpoints.erase(id)!=0;}
}
