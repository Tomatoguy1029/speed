#include "../systems/heroes.h"
#include "checkpoint.h"
#include "../bosses/flow/technique_runner.h"
#include "../bosses/flow/flow_runner.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/monoceros/finish.h"
#include "../bosses/canis_major/flames.h"
#include "../bosses/canis_major/hound_lunge.h"
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
    for (auto &a:state.observations.actions) a.boundary=a.boundary.duplicate(true);
    for (auto &e:state.observations.pending) e.action.boundary=e.action.boundary.duplicate(true);
    for (auto &e:state.observations.effects) e.action.boundary=e.action.boundary.duplicate(true);
    for (auto &e:state.observations.pending_effects) e.effect.action.boundary=e.effect.action.boundary.duplicate(true);
    return state;
}
bool rebuild_state_indexes(godot::RunState &state,const ContentBundle &content) {
    if (!HeroesSystem::validate(state,content)) return false;
    if (state.loadout.scatter.ready && (!std::isfinite(state.loadout.scatter.elapsed) || state.loadout.scatter.elapsed<0)) return false;
    if (state.ship.shield_source_definition>content.definitions.size()) return false;
    if (!state.started || state.closed || state.next_id<=0 ||
        !std::isfinite(state.time) || !std::isfinite(state.world_time) || !std::isfinite(state.sim_time) ||
        !std::isfinite(state.grid.cell) || state.grid.cell<=0 || state.enemies.size()>=UINT32_MAX ||
        state.behavior_kinds.size()!=state.behavior_rows.size()) return false;
    const auto &ram=state.control.boss_ram;
    if (!std::isfinite(state.control.boss_ram_hitstop) || state.control.boss_ram_hitstop<0 || state.control.next_boss_ram_serial<1 ||
        !std::isfinite(ram.remaining) || ram.remaining<0 || !std::isfinite(ram.started_at) || !std::isfinite(ram.released_at) || ram.started_at< -1 || ram.released_at< -1 || !ram.entry.is_finite() || !ram.exit.is_finite() || !ram.direction.is_finite()) return false;
    if (ram.pending && (!ram.target.generation || ram.target_id<=0 || ram.serial<=0 || ram.serial>=state.control.next_boss_ram_serial)) return false;
    if (!std::isfinite(state.control.boss_at) || state.control.boss_at<-1 || !std::isfinite(state.control.world_real_accum) || !std::isfinite(state.control.world_dt_accum) ||
        state.control.world_real_accum<0 || state.control.world_dt_accum<0 || state.control.world_tick_div<1 ||
        state.control.world_steps<0 || state.control.world_steps>=state.control.world_tick_div) return false;
    for (const auto &v:state.loadout.kill_sonic.waves) if (!v.pos.is_finite() || !std::isfinite(v.age) || v.age<0 || !std::isfinite(v.born) || !std::isfinite(v.life) || v.life<=0) return false;
    auto &slash=state.loadout.flash_slash;if (!std::isfinite(slash.clock) || slash.clock<0 || !std::isfinite(slash.released)) return false;slash.marked_ids.clear();
    for (const auto &m:slash.marks) {if (m.id<=0 || !m.total || !m.left || m.left>m.total || !std::isfinite(m.time) || !std::isfinite(m.delay) || m.delay<0 || !std::isfinite(m.age) || m.age<0 || !std::isfinite(m.damage) || m.damage<0 || !std::isfinite(m.distance) || m.distance<0 || (state.enemy_handles.contains(m.target) && state.enemy_handles.entity_id(m.target)!=m.id) || !slash.marked_ids[m.dash].insert(m.id).second) return false;}
    const auto &afterimage=state.loadout.afterimage;if (!std::isfinite(afterimage.clock) || afterimage.clock<0 || afterimage.echoes.size()>8) return false;
    bool current_found=afterimage.current==0;
    for (const auto &echo:afterimage.echoes) {if (!echo.id || echo.id>=afterimage.next_id || !std::isfinite(echo.start) || !std::isfinite(echo.until) || !std::isfinite(echo.share) || echo.share<0 || echo.legs.size()>2048 || echo.copies.empty() || echo.copies.size()>8) return false;if (echo.id==afterimage.current) {if (echo.ended) return false;current_found=true;}
        for (const auto &leg:echo.legs) if (!leg.a.is_finite() || !leg.b.is_finite() || !std::isfinite(leg.start) || !std::isfinite(leg.finish) || leg.finish<leg.start || !std::isfinite(leg.power) || !std::isfinite(leg.radius) || leg.radius<0) return false;
        for (const auto &copy:echo.copies) if (!copy.pos.is_finite() || !copy.dir.is_finite() || !std::isfinite(copy.delay) || copy.delay<=0 || !std::isfinite(copy.progress) || copy.progress<0 || copy.progress>1 || !std::isfinite(copy.alpha) || copy.alpha<0 || copy.alpha>1 || copy.cursor>echo.legs.size()) return false;
    }
    if (!current_found) return false;
    const auto &escort=state.loadout.escort;if (!std::isfinite(escort.distance) || escort.distance<0) return false;
    for (const auto &v:escort.normals) if (!v.is_finite()) return false;
    for (const auto &v:escort.drones) {if (!v.pos.is_finite() || !v.dir.is_finite() || v.trail.size()>96) return false;for (const auto &p:v.trail) if (!p.pos.is_finite() || !std::isfinite(p.life) || p.life<0) return false;}
    const auto &interceptor=state.loadout.interceptor;if (!std::isfinite(interceptor.clock) || interceptor.clock<0) return false;
    for (const auto &[id,deadline]:interceptor.target_after) if (id<=0 || !std::isfinite(deadline)) return false;
    for (const auto &v:interceptor.drones) if (!v.pos.is_finite() || !std::isfinite(v.angle) || !std::isfinite(v.flash) || !std::isfinite(v.kick) || !std::isfinite(v.next) || v.flash<0 || v.kick<0 || (state.enemy_handles.contains(v.target) && state.enemy_handles.entity_id(v.target)!=v.target_id)) return false;
    const auto &bipolar=state.loadout.bipolar;if (!bipolar.origin.is_finite() || !std::isfinite(bipolar.started)) return false;
    for (const auto &v:bipolar.pending) if (!v.from.is_finite() || !v.to.is_finite() || !std::isfinite(v.delay) || v.delay<=0 || !v.id || v.id>=bipolar.next_id) return false;
    for (const auto &v:bipolar.beams) if (!v.from.is_finite() || !v.to.is_finite() || !std::isfinite(v.age) || v.age<0 || !v.id || v.id>=bipolar.next_id || !std::isfinite(v.width_scale) || v.width_scale<=0) return false;
    if (!std::isfinite(state.loadout.mass_tow.fire.remaining)) return false;
    for (const auto &c:state.loadout.mass_tow.cargo) if (!c.pos.is_finite() || !c.relative.is_finite() || !std::isfinite(c.angle) || c.radius<=0 || !std::isfinite(c.radius) || c.source_id<=0 || !c.definition || c.definition>content.definitions.size()) return false;
    if (!std::isfinite(state.loadout.contact_arc.ready_at)) return false;
    for (const auto &v:state.loadout.contact_arc.visuals) {if (!std::isfinite(v.age) || v.age<0 || v.segments.size()%2) return false;for (auto p:v.segments) if (!p.is_finite()) return false;}
    for (const auto &f:state.loadout.sonic.frames) if (!f.pos.is_finite() || !std::isfinite(f.age) || f.age<0) return false;
    for (const auto &h:state.loadout.sonic.pending) if (!h.velocity.is_finite() || !std::isfinite(h.age) || !std::isfinite(h.damage) || h.id<=0 || (state.enemy_handles.contains(h.target) && state.enemy_handles.entity_id(h.target)!=h.id)) return false;
    if (state.loadout.contact_wave.ripples.size()>8) return false;
    for (const auto &v:state.loadout.contact_wave.ripples) if (!v.pos.is_finite() || !std::isfinite(v.age) || !std::isfinite(v.radius) || v.age<0 || v.radius<0) return false;
    for (const auto &w:state.loadout.contact_wave.waves) {
        if (!w.pos.is_finite() || !std::isfinite(w.age) || !std::isfinite(w.visual_age) || w.visual_age<0 || !std::isfinite(w.radius) || !std::isfinite(w.damage) || w.age<0 || w.radius<0 || w.damage<0) return false;
        for (const auto &h:w.caught) if (h.id<=0 || !std::isfinite(h.age) || h.age<0 || (state.enemy_handles.contains(h.target) && state.enemy_handles.entity_id(h.target)!=h.id)) return false;
    }
    if (state.clips_ready) for (const auto &clip:state.clips) {
        if (!std::isfinite(clip.next) || !std::isfinite(clip.start) || std::isnan(clip.end) || clip.end<clip.start || !std::isfinite(clip.interval) || clip.interval<0 || clip.maximum<0) return false;
        for (auto formation:clip.formations) if (formation>=state.formations.size()) return false;
        for (const auto &group:clip.groups) for (const auto &[row,id]:group.members) if (row>=state.enemies.size() || id<=0 || id>=state.next_id) return false;
    }
    if (!std::isfinite(state.encounter.next) || !std::isfinite(state.encounter.start) || !std::isfinite(state.encounter.window) || !std::isfinite(state.encounter.margin)) return false;
    for (auto point:state.encounter.route) if (!point.is_finite()) return false;
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
            !std::isfinite(enemy.fire_hit) || !std::isfinite(enemy.hp) || !std::isfinite(enemy.max_hp) || !std::isfinite(enemy.radius) || enemy.radius<=0 ||
            !state.rows_by_id.emplace(enemy.id,row).second) return false;
    }
    for (const auto &enemy:state.enemies) if (enemy.alive) {
        if (enemy.source_definition>content.definitions.size() || (enemy.picaro_owner.generation && !enemy.source_definition)) return false;
        if (enemy.origin>=SpawnOrigin::Count || enemy.role>=SpawnRole::Count) return false;
        if (state.enemy_handles.contains(enemy.parent) && state.enemy_handles.entity_id(enemy.parent)!=enemy.parent_id) return false;
        const auto *sniper=std::get_if<SniperState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Sniper)!=(sniper!=nullptr)) return false;
        if (sniper) {if (!sniper->rays.empty() && sniper->rays.size()!=48) return false;for (float v:sniper->rays) if (!std::isfinite(v) || v<0) return false;}
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Auriga)!=std::holds_alternative<AurigaState>(enemy.behavior_state)) return false;
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Clock)!=std::holds_alternative<ClockState>(enemy.behavior_state)) return false;
        if (const auto *clock=std::get_if<ClockState>(&enemy.behavior_state)) for (auto hand:clock->hands) if (const auto *record=AttackSystem::get(state,hand)) {if (!record->spec.owner.attached || !same_handle(record->spec.owner.live_source,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id))))) return false;}
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Crow)!=std::holds_alternative<CrowState>(enemy.behavior_state)) return false;
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Defender)!=std::holds_alternative<DefenderState>(enemy.behavior_state)) return false;
        if (const auto *defender=std::get_if<DefenderState>(&enemy.behavior_state)) for (double value:{defender->boost.speed,defender->boost.wobble,defender->boost.until,defender->boost.phase}) if (!std::isfinite(value)) return false;
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Split)!=std::holds_alternative<SplitState>(enemy.behavior_state)) return false;
        if (const auto *split=std::get_if<SplitState>(&enemy.behavior_state)) if (!std::isfinite(split->bud_t) || split->bud_t<0) return false;
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Reticle)!=std::holds_alternative<ReticleState>(enemy.behavior_state)) return false;
        if (const auto *reticle=std::get_if<ReticleState>(&enemy.behavior_state)) if (state.enemy_handles.contains(reticle->rock) && state.enemy_handles.entity_id(reticle->rock)!=reticle->rock_id) return false;
        const auto *triangle=std::get_if<TriangleState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Triangle)!=(triangle!=nullptr) || (triangle && (triangle->buds>2 || !std::isfinite(enemy.spin) || enemy.parts.size()!=3))) return false;
        const auto *ruler=std::get_if<RulerState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Ruler)!=(ruler!=nullptr) || (ruler && (ruler->side< -1 || ruler->side>1))) return false;
        const auto *cepheus=std::get_if<CepheusState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Cepheus)!=(cepheus!=nullptr) || (cepheus && (cepheus->tier>3 || !cepheus->anchor.is_finite() || !std::isfinite(cepheus->volley)))) return false;
        const auto *soldier=std::get_if<SoldierState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Soldier)!=(soldier!=nullptr)) return false;
        if (soldier && (!soldier->formation.anchor.is_finite() || soldier->formation.tier<1 || soldier->formation.tier>3 || (state.enemy_handles.contains(soldier->king) && state.enemy_handles.entity_id(soldier->king)!=soldier->king_id))) return false;
        const auto *lynx=std::get_if<LynxState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Lynx)!=(lynx!=nullptr) || (lynx && (!std::isfinite(lynx->last_fire) || (lynx->last_side!=1 && lynx->last_side!=-1)))) return false;
        const auto *corona=std::get_if<CoronaState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Corona)!=(corona!=nullptr)) return false;
        if (corona) {if (!std::isfinite(corona->wait) || !std::isfinite(corona->capture_t) || !corona->center.is_finite()) return false;uint32_t count=0;for (const auto &bucket:corona->types) {if (bucket.definition>=content.definitions.size() || bucket.items.empty()) return false;for (uint32_t slot=0;slot<bucket.items.size();++slot) {const auto h=bucket.items[slot];if (!state.enemy_handles.contains(h)) return false;const auto &member=state.enemies[h.slot].corona;if (!member || member->thrown || member->slot!=slot || member->definition!=bucket.definition || !same_handle(member->owner,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id))))) return false;++count;}}if (count!=corona->count) return false;}
        if (enemy.corona) {const auto &c=*enemy.corona;if (!enemy.held || !c.serial || c.serial>state.corona_serial || c.definition!=enemy.definition || !c.from.is_finite() || !c.ship_from.is_finite()) return false;if (state.enemy_handles.contains(c.owner)) {if (!std::holds_alternative<CoronaState>(state.enemies[c.owner.slot].behavior_state)) return false;} else if (!c.thrown || c.slot>=content.definitions.size() || content.definitions[c.slot].kind!=EnemyDefinition::Kind::Corona) return false;for (double x:{c.angle,c.radius,c.life,c.release_fraction,c.damage,c.effect}) if (!std::isfinite(x)) return false;if (c.radius<0 || c.release_fraction<0 || c.release_fraction>1 || c.damage<0 || c.effect<0 || c.attack_token<0) return false;}
        const auto *pump=std::get_if<PumpState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Pump)!=(pump!=nullptr)) return false;
        if (pump) {if (!std::isfinite(pump->bud_t) || pump->contents.size()>content.pumps[content.definitions[enemy.definition].pump_definition-1].store_max) return false;for (auto id:pump->contents) if (!id || id>content.definitions.size()) return false;}
        const auto *crab=std::get_if<CrabState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Crab)!=(crab!=nullptr) || (crab && crab->buds!=1 && crab->buds!=-1)) return false;
        if (crab) if (const auto *record=AttackSystem::get(state,crab->sweep)) if (!record->spec.owner.attached || !same_handle(record->spec.owner.live_source,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id))))) return false;
        const auto *aquila=std::get_if<AquilaState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Aquila)!=(aquila!=nullptr) || (aquila && (!aquila->anchor.is_finite() || !std::isfinite(aquila->bud_t)))) return false;
        if (aquila) for (const auto &point:aquila->trace) if (!point.pos.is_finite() || !std::isfinite(point.time)) return false;
        const auto *phoenix=std::get_if<PhoenixState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Phoenix)!=(phoenix!=nullptr) || (phoenix && !phoenix->anchor.is_finite())) return false;
        const auto *marlin=std::get_if<MarlinState>(&enemy.behavior_state);
        if ((content.definitions[enemy.definition].kind==EnemyDefinition::Kind::Marlin)!=(marlin!=nullptr) || (marlin && !marlin->anchor.is_finite())) return false;
        std::unordered_set<uint64_t> parts;
        for (auto part:enemy.parts) {
            if (!parts.insert(handle_key(part)).second) return false;
            if (state.enemy_handles.contains(part) && (state.enemies[part.slot].parent_id!=enemy.id || !same_handle(state.enemies[part.slot].parent,state.enemy_handles.at(uint32_t(state.rows_by_id.at(enemy.id)))))) return false;
        }
    }
    std::unordered_set<uint64_t> corona_live;
    state.corona_members.erase(std::remove_if(state.corona_members.begin(),state.corona_members.end(),[&](const auto &ref){return !state.enemy_handles.contains(ref.target) || !state.enemies[ref.target.slot].corona || state.enemies[ref.target.slot].corona->serial!=ref.serial;}),state.corona_members.end());
    for (const auto &ref:state.corona_members) if (!corona_live.insert(handle_key(ref.target)).second) return false;
    for (uint32_t row=0;row<state.enemies.size();++row) if (state.enemies[row].alive && state.enemies[row].corona && !corona_live.count(handle_key(state.enemy_handles.at(row)))) return false;
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
                !std::isfinite(shot.speed) || shot.speed<0 || !std::isfinite(shot.life) || !std::isfinite(shot.damage) || shot.damage<0 ||
                shot.slash.lynx_definition>content.lynxes.size() || !std::isfinite(shot.slash.initial_life) || shot.slash.initial_life<0 || !std::isfinite(shot.slash.age) || shot.slash.age<0 || !shot.slash.paw_offset.is_finite()) return false;
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
    if (!CanisHoundLunge::validate(state,content) || !CanisFlames::validate(state,content)) return false;
    for (const auto &hazard:state.hazards) if (hazard.alive) {
        if (!hazard.pos.is_finite() || !std::isfinite(hazard.time) || !std::isfinite(hazard.delay) || !std::isfinite(hazard.duration) || !std::isfinite(hazard.damage)) return false;
        if (hazard.zone_definition && (hazard.zone_definition>content.zones.size() || !std::holds_alternative<CircleHazard>(hazard.shape) || std::get<CircleHazard>(hazard.shape).kind!=CircleHazardKind::Blast || !std::isfinite(hazard.enemy_damage) || hazard.enemy_damage<0)) return false;
        if (const auto *v=std::get_if<HydraShapeHazard>(&hazard.shape)) {if (v->points.size()<2 || !std::isfinite(v->width) || v->width<0 || !v->velocity.is_finite() || !std::isfinite(v->age) || !std::isfinite(v->delay) || !std::isfinite(v->life) || !std::isfinite(v->wind_force) || v->age<0 || v->life<0 || v->wind_force<0) return false;for (const auto *points:{&v->points,&v->before,&v->last_points}) for (const auto point:*points) if (!point.is_finite()) return false;}
        if (const auto *beam=std::get_if<BeamHazard>(&hazard.shape)) {
            if ((beam->style==uint32_t(BeamStyle::Flood) && content.floods.empty()) || beam->flood_group<0 || beam->style>=uint32_t(BeamStyle::Count) || !beam->definition || beam->definition>content.beams.size() || !std::isfinite(beam->angle) || !std::isfinite(beam->length) || beam->length<0 ||
                !std::isfinite(beam->half_width) || beam->half_width<0 || !std::isfinite(beam->arc)) return false;
        }
        if (const auto *wall=std::get_if<WallHazard>(&hazard.shape)) {
            if (wall->trail_visual_owner<0 || (wall->trail_visual_owner==0 && wall->trail_visual_side!=0) || (wall->trail_visual_owner>0 && wall->trail_visual_side!=1 && wall->trail_visual_side!=-1)) return false;
            if (!wall->definition || wall->definition>content.walls.size() || wall->style>=uint32_t(WallStyle::Count) ||
                !std::isfinite(wall->angle) || !std::isfinite(wall->length) || wall->length<0 || !std::isfinite(wall->half_width) || wall->half_width<0) return false;
        }
        if (const auto *wave=std::get_if<MonocerosWaveHazard>(&hazard.shape)) {
            for (double value:{wave->radius,wave->maximum,wave->speed,wave->half_angle,wave->width,wave->reference_time,wave->visual_age}) if (!std::isfinite(value) || value<0) return false;
            if (!std::isfinite(wave->angle)) return false;
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
    for (const auto &pending:state.pending_enemies) if (!pending.definition || pending.definition>content.definitions.size() || !pending.position.is_finite() || !pending.velocity.is_finite() || !std::isfinite(pending.facing) || !std::isfinite(pending.hit_cd) || pending.hit_cd<0 || !std::isfinite(pending.guard) || pending.guard<0 || !std::isfinite(pending.knock) || pending.knock<0 || !std::isfinite(pending.priority)) return false;
    if (state.loadout.comet_weapon && (state.loadout.comet_weapon>content.equipment.size() || !content.equipment[state.loadout.comet_weapon-1].comet_only || state.loadout.candidates.empty())) return false;
    for (auto weapon:state.loadout.pending_comet_weapons) if (!weapon || weapon>content.equipment.size() || !content.equipment[weapon-1].comet_only) return false;
    for (const auto &capsule:pickups.capsules) if (!capsule.pos.is_finite() || !std::isfinite(capsule.age) || capsule.age<0 || (capsule.kind==CapsuleKind::CometWeapon && (!capsule.weapon || capsule.weapon>content.equipment.size() || !content.equipment[capsule.weapon-1].comet_only))) return false;
    for (const auto &a:state.attacks.records) if (a.alive && (a.spec.damage_source>content.definitions.size() || a.spec.damage_technique>content.boss_techniques.size())) return false;
    if (!BossFinish::validate(state) || !TechniqueRunner::validate(state,content) || !FlowRunner::validate(state,content) || !PhaseController::validate(state,content)) return false;
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
