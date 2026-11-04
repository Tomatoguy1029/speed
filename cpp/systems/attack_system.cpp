#include "attack_system.h"
#include "../behaviors/traits/duplicator.h"
#include "../runtime/run_runtime.h"
#include "attack_budget.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <unordered_set>
namespace speed {
bool AttackSystem::configure_contact(const ContentBundle &content,uint32_t definition,AttackSpec &spec) {
    const auto found=std::find_if(content.contacts.begin(),content.contacts.end(),[&](const auto &v){return v.id==definition;});
    if (found==content.contacts.end()) return false;
    spec.contact_definition=definition;spec.contact={DamageScale(found->scale),HitPolicy(found->hit_policy),found->add_ship_radius,found->ship_sweep};return true;
}
namespace {
using State=godot::RunState;
using Index=std::unordered_map<uint64_t,std::vector<AttackHandle>>;
void add_indexes(State &state,AttackHandle handle,const AttackRecord &record) {
    auto &all=state.attacks;const auto &s=record.spec;
    if (s.owner.source_id) all.by_source[s.owner.source_id].push_back(handle);
    if (s.technique.generation) all.by_technique[handle_key(s.technique)].push_back(handle);
    if (s.participant.generation) all.by_participant[handle_key(s.participant)].push_back(handle);
    if (s.boss.generation) all.by_boss[handle_key(s.boss)].push_back(handle);
    if (s.encounter.generation) all.by_encounter[handle_key(s.encounter)].push_back(handle);
}
template<class Map,class Key> void erase_index(Map &map,Key key,AttackHandle handle) {
    auto found=map.find(key);if (found==map.end()) return;
    auto &rows=found->second;
    rows.erase(std::remove_if(rows.begin(),rows.end(),[&](auto h){return same_handle(h,handle);}),rows.end());
    if (rows.empty()) map.erase(found);
}
AttackHandle register_attack(State &state,AttackPool pool,uint32_t row,AttackSpec spec) {
    auto &all=state.attacks;
    if (!spec.policies || (spec.policies&~63u) || spec.owner.budget.value<0 || all.next_id==INT64_MAX) return {};
    if (spec.owner.live_source.generation) {
        if (!state.enemy_handles.contains(spec.owner.live_source)) return {};
        const auto &enemy=state.enemies[spec.owner.live_source.slot];
        spec.owner.source_id=enemy.id;spec.owner.source_definition=uint32_t(enemy.definition+1);
        if (enemy.dead) {
            if (has_policy(spec.policies,EndPolicy::CancelWithParticipant)) return {};
            spec.owner.live_source={};
        }
    }
    if (!state.observations.recording || !state.observations.detail_level) spec.observation_id=0;
    else if (!spec.observation_id && state.bosses.handles.contains(spec.technique)) spec.observation_id=state.bosses.techniques[spec.technique.slot].observation_id;
    if (state.observations.recording && state.observations.detail_level && !spec.observation_id && spec.source_technique) for (const auto &t:state.bosses.techniques)
        if (t.stage<TechniqueStage::Finished && t.definition==spec.source_technique && state.enemy_handles.entity_id(t.actor)==spec.owner.source_id) {spec.observation_id=t.observation_id;break;}
    while (!all.free_records.empty() && !all.handles.reusable(all.free_records.back())) all.free_records.pop_back();
    if (all.free_records.empty() && all.records.size()>=UINT32_MAX) return {};
    if (!AttackBudgetSystem::retain(state,spec.owner.budget)) return {};
    uint32_t slot=uint32_t(all.records.size());
    if (all.free_records.empty()) all.records.emplace_back();else {slot=all.free_records.back();all.free_records.pop_back();}
    const auto handle=all.handles.attach(slot,all.next_id);
    if (!all.handles.contains(handle)) {AttackBudgetSystem::release(state,spec.owner.budget);return {};}
    all.records[slot]={spec,pool,row,all.next_id++,true,false,state.ship.pos,true};add_indexes(state,handle,all.records[slot]);state.observations.retain(spec.observation_id);return handle;
}
std::vector<AttackHandle> indexed(const Index &index,uint64_t key) {
    auto found=index.find(key);return found==index.end()?std::vector<AttackHandle>():found->second;
}
void filter_end(State &state,const std::vector<AttackHandle> &items,EndPolicies policies,AttackEndReason reason) {
    for (auto handle:items) if (const auto *record=AttackSystem::get(state,handle))
        if (record->spec.policies&policies) AttackSystem::end(state,handle,reason);
}
}
const AttackRecord *AttackSystem::get(const State &state,AttackHandle handle) {
    return state.attacks.handles.contains(handle) && handle.slot<state.attacks.records.size() && state.attacks.records[handle.slot].alive?&state.attacks.records[handle.slot]:nullptr;
}
bool AttackSystem::mark_ship_hit(State &state,AttackHandle handle) {
    if (!get(state,handle)) return false;
    state.attacks.records[handle.slot].ship_hit=true;return true;
}
bool AttackSystem::has_attached(const State &state,EnemyHandle source) {
    const auto found=state.attacks.by_source.find(state.enemy_handles.entity_id(source));
    if (found==state.attacks.by_source.end()) return false;
    for (auto handle:found->second) {
        const auto *record=get(state,handle);
        if (record && record->spec.owner.attached && same_handle(record->spec.owner.live_source,source)) return true;
    }return false;
}
void AttackSystem::record_ship_position(State &state,AttackHandle handle) {
    if (!get(state,handle)) return;
    auto &record=state.attacks.records[handle.slot];record.ship_previous=state.ship.pos;record.ship_previous_ready=true;
}
bool AttackSystem::reserve_friendly(State &state,uint64_t count) {
    if (count>UINT64_MAX-flying_count(state)) return false;
    state.attacks.friendly_reservations+=count;return true;
}
bool AttackSystem::release_friendly(State &state,uint64_t count) {
    if (count>state.attacks.friendly_reservations) return false;
    state.attacks.friendly_reservations-=count;return true;
}
uint64_t AttackSystem::flying_count(const State &state) {
    const uint64_t live=state.live_friends;if (state.attacks.lances.size()>UINT64_MAX-live) return UINT64_MAX;
    const uint64_t count=live+state.attacks.lances.size();return state.attacks.friendly_reservations>UINT64_MAX-count?UINT64_MAX:count+state.attacks.friendly_reservations;
}
AttackHandle AttackSystem::emit_friendly(RunRuntime &run,State::Friendly value,AttackSpec spec) {
    FriendlyBirthScope scope(run,run.workspace.friend_birth_batches.empty());
    const auto handle=emit_friendly(run.state,std::move(value),spec);
    if (get(run.state,handle)) run.workspace.friend_birth_batches.back().push_back(handle);
    return handle;
}
AttackHandle AttackSystem::emit_friendly(State &state,State::Friendly value,AttackSpec spec) {
    const size_t row=state.free_friends.empty()?state.friends.size():state.free_friends.back();if (row>=UINT32_MAX) return {};
    const auto handle=register_attack(state,AttackPool::Friendly,uint32_t(row),spec);if (!get(state,handle)) return {};
    value.attack=handle;value.id=get(state,handle)->id;value.alive=true;
    if (state.free_friends.empty()) state.friends.push_back(std::move(value));else {state.free_friends.pop_back();state.friends[row]=std::move(value);}
    ++state.live_friends;if (state.friends[row].kind==1) ++state.live_debris;return handle;
}
AttackHandle AttackSystem::emit_hostile(State &state,State::Hostile value,AttackSpec spec) {
    const size_t row=state.free_hostiles.empty()?state.hostiles.size():state.free_hostiles.back();if (row>=UINT32_MAX) return {};
    const auto handle=register_attack(state,AttackPool::Hostile,uint32_t(row),spec);if (!get(state,handle)) return {};
    value.attack=handle;value.alive=true;
    if (state.free_hostiles.empty()) state.hostiles.push_back(std::move(value));else {state.free_hostiles.pop_back();state.hostiles[row]=std::move(value);}
    state.observations.effect_begin(get(state,handle)->id,get(state,handle)->spec.observation_id,state.hostiles[row].pos);
    return handle;
}
AttackHandle AttackSystem::emit_hazard(State &state,State::Hazard value,AttackSpec spec) {
    const auto *circle=std::get_if<CircleHazard>(&value.shape);
    const bool bite=circle && circle->kind==CircleHazardKind::Bite;
    if (bite && !state.bite_zone_config.ready) return {};
    if (bite && value.duration<=0) value.duration=state.bite_zone_config.duration;
    if (!std::isfinite(value.duration) || value.duration<0 || (circle && value.duration==0)) return {};
    const size_t row=state.free_hazards.empty()?state.hazards.size():state.free_hazards.back();if (row>=UINT32_MAX) return {};
    const auto handle=register_attack(state,AttackPool::Hazard,uint32_t(row),spec);if (!get(state,handle)) return {};
    value.attack=handle;value.alive=true;
    if (state.free_hazards.empty()) state.hazards.push_back(std::move(value));else {state.free_hazards.pop_back();state.hazards[row]=std::move(value);}
    state.observations.effect_begin(get(state,handle)->id,get(state,handle)->spec.observation_id,state.hazards[row].pos);
    return handle;
}
bool AttackSystem::end(State &state,AttackHandle handle,AttackEndReason reason) {
    const auto *entry=get(state,handle);if (!entry) return false;
    const auto record=*entry;auto &all=state.attacks;
    all.records[handle.slot].alive=false;
    godot::Vector2 pos;bool circle=false;uint32_t zone_definition=0;FloodTailState flood;
    switch(record.pool) {
    case AttackPool::Friendly: {
        auto &value=state.friends[record.row];pos=value.pos;
        if (value.alive && same_handle(value.attack,handle)) {
            value.alive=false;--state.live_friends;if (value.kind==1) --state.live_debris;state.free_friends.push_back(record.row);
        }break;
    }
    case AttackPool::Hostile: {
        auto &value=state.hostiles[record.row];pos=value.pos;
        if (value.alive && same_handle(value.attack,handle)) {value.alive=false;value.shell={};state.free_hostiles.push_back(record.row);}break;
    }
    case AttackPool::Hazard: {
        auto &value=state.hazards[record.row];pos=value.pos;zone_definition=value.zone_definition;circle=std::holds_alternative<CircleHazard>(value.shape) && std::get<CircleHazard>(value.shape).kind!=CircleHazardKind::Blast;
        if (const auto *beam=std::get_if<BeamHazard>(&value.shape);beam && beam->style==uint32_t(BeamStyle::Flood) && value.time>=value.delay) {
            flood.ready=true;flood.row=record.row;flood.pos=value.pos;flood.angle=beam->angle;flood.length=beam->length;flood.width=beam->half_width*2.0;flood.spread=beam->arc;
            flood.reference_aquarius=beam->flood_reference;flood.index=beam->flood_index;
            flood.age=reason==AttackEndReason::Lifetime?std::max(0.0,double(value.time)-value.delay-value.duration):0.0;
        }
        if (value.alive && same_handle(value.attack,handle)) {value.alive=false;state.free_hazards.push_back(record.row);}break;
    }
    }
    const auto &s=record.spec;
    state.observations.effect_end(record.id,pos,reason);
    state.observations.release(s.observation_id);
    erase_index(all.by_source,s.owner.source_id,handle);erase_index(all.by_technique,handle_key(s.technique),handle);
    erase_index(all.by_participant,handle_key(s.participant),handle);erase_index(all.by_boss,handle_key(s.boss),handle);
    erase_index(all.by_encounter,handle_key(s.encounter),handle);
    AttackBudgetSystem::release(state,s.owner.budget);
    all.handles.release(handle);if (all.handles.reusable(handle.slot)) all.free_records.push_back(handle.slot);
    CombatEvent event;event.kind=CombatEventKind::AttackRetired;event.target_id=record.id;event.source_entity_id=s.owner.source_id;
    event.source=s.owner.source_definition;event.attack_pool=record.pool;event.attack_end_reason=reason;event.pos=pos;event.circle_hazard=circle;
    event.flood=flood;event.zone_definition=zone_definition;event.time=state.time;event.world_time=state.world_time;state.combat_events.push_back(event);return true;
}
void AttackSystem::source_ended(State &state,EnemyHandle source,AttackEndReason reason) {
    const auto id=state.enemy_handles.entity_id(source);
    if (reason==AttackEndReason::ParticipantEnd || reason==AttackEndReason::BossClear) state.observations.actor_ended(id);
    auto found=state.attacks.by_source.find(id);
    if (!id || found==state.attacks.by_source.end()) return;
    const auto handles=found->second;
    for (auto handle:handles) {
        const auto *record=get(state,handle);if (!record || !same_handle(record->spec.owner.live_source,source)) continue;
        if (reason==AttackEndReason::Relocate) {
            if (record->spec.owner.attached) end(state,handle,reason);
        } else if (has_policy(record->spec.policies,EndPolicy::CancelWithParticipant)) end(state,handle,reason);
        else state.attacks.records[handle.slot].spec.owner.live_source={};
    }
}
void AttackSystem::end_technique(State &state,TechniqueHandle technique,bool cancelled) {
    if (!technique.generation) return;
    if (state.bosses.handles.contains(technique)) state.observations.finish(state.bosses.techniques[technique.slot].observation_id);
    filter_end(state,indexed(state.attacks.by_technique,handle_key(technique)),policy(EndPolicy::EndWithTechnique)|(cancelled?policy(EndPolicy::CancelWithTechnique):0),cancelled?AttackEndReason::TechniqueCancel:AttackEndReason::TechniqueEnd);
}
void AttackSystem::end_participant(State &state,ParticipantHandle participant) {
    if (participant.generation) filter_end(state,indexed(state.attacks.by_participant,handle_key(participant)),policy(EndPolicy::CancelWithParticipant),AttackEndReason::ParticipantEnd);
}
void AttackSystem::end_boss(State &state,BossHandle boss) {
    if (boss.generation) filter_end(state,indexed(state.attacks.by_boss,handle_key(boss)),policy(EndPolicy::ClearWithBoss),AttackEndReason::BossClear);
}
void AttackSystem::end_encounter(State &state,EncounterHandle encounter) {
    if (encounter.generation) filter_end(state,indexed(state.attacks.by_encounter,handle_key(encounter)),policy(EndPolicy::ClearWithBoss),AttackEndReason::BossClear);
}
void AttackSystem::clear_bonus(State &state) {
    std::vector<AttackHandle> handles;
    for (uint32_t i=0;i<state.attacks.records.size();++i) if (state.attacks.records[i].alive && has_policy(state.attacks.records[i].spec.policies,EndPolicy::ClearWithBonus)) handles.push_back(state.attacks.handles.at(i));
    for (auto handle:handles) end(state,handle,AttackEndReason::BonusClear);
}
void AttackSystem::clear_hostile(State &state,AttackEndReason reason) {
    if (state.attacks.hostile_updating) {state.attacks.hostile_clear_pending=true;state.attacks.clear_reason=reason;}
    std::vector<AttackHandle> handles;
    for (uint32_t i=0;i<state.attacks.records.size();++i) {
        const auto &record=state.attacks.records[i];if (!record.alive || record.pool==AttackPool::Friendly) continue;
        if (record.pool==AttackPool::Hostile && state.attacks.hostile_updating) {state.attacks.hostile_clear_pending=true;state.attacks.clear_reason=reason;}
        else handles.push_back(state.attacks.handles.at(i));
    }
    for (auto handle:handles) end(state,handle,reason);
    state.hazards.clear();state.free_hazards.clear();
    if (!state.attacks.hostile_updating) {state.hostiles.clear();state.free_hostiles.clear();}
}
bool AttackSystem::begin_hostile_update(State &state) {
    if (state.attacks.hostile_updating) return false;state.attacks.hostile_updating=true;return true;
}
void AttackSystem::finish_hostile_update(State &state) {
    state.attacks.hostile_updating=false;
    if (state.attacks.hostile_clear_pending) {
        state.attacks.hostile_clear_pending=false;clear_hostile(state,state.attacks.clear_reason);
    }
}
bool AttackSystem::hazard_act(const State &state,AttackHandle handle,double) {return get(state,handle) && state.phase==State::Phase::Play;}
bool AttackSystem::hazard_before_touch(const State &state,AttackHandle handle) {return get(state,handle) && state.phase==State::Phase::Play;}
void AttackSystem::sync_observation_positions(State &state) {
    auto &o=state.observations;if (!o.recording || !o.detail_level) return;
    for (const auto &a:state.attacks.records) if (a.alive && a.spec.observation_id) {
        switch (a.pool) {
        case AttackPool::Hostile: if (a.row<state.hostiles.size()) o.effect_position(a.id,state.hostiles[a.row].pos);break;
        case AttackPool::Hazard: if (a.row<state.hazards.size()) o.effect_position(a.id,state.hazards[a.row].pos);break;
        case AttackPool::Friendly: break;
        }
    }
    for (const auto &b:state.bosses.bodies) for (const auto &v:b.canis.burning)
        if (state.enemy_handles.contains(v.actor)) o.effect_position(v.effect_id,state.enemies[v.actor.slot].pos);
}
bool AttackSystem::rebuild(State &state) {
    auto &all=state.attacks;if (all.next_id<=0 || all.records.size()>=UINT32_MAX || all.hostile_updating || all.hostile_clear_pending) return false;
    all.by_source.clear();all.by_technique.clear();all.by_participant.clear();all.by_boss.clear();all.by_encounter.clear();
    AttackBudgetSystem::reset_residuals(state);
    std::unordered_set<int64_t> ids;std::unordered_set<uint32_t> free;
    for (uint32_t i=0;i<all.records.size();++i) {
        const auto &record=all.records[i];const auto h=all.handles.at(i);
        if (!record.alive) {if (all.handles.contains(h)) return false;continue;}
        if (!all.handles.contains(h) || all.handles.entity_id(h)!=record.id || record.id<=0 || record.id>=all.next_id || !ids.insert(record.id).second || !record.spec.policies || (record.spec.policies&~63u)) return false;
        if (record.spec.owner.live_source.generation && !state.enemy_handles.contains(record.spec.owner.live_source)) return false;
        bool valid=false;
        switch(record.pool) {
        case AttackPool::Friendly:valid=record.row<state.friends.size() && state.friends[record.row].alive && same_handle(state.friends[record.row].attack,h) && state.friends[record.row].id==record.id;break;
        case AttackPool::Hostile:valid=record.row<state.hostiles.size() && state.hostiles[record.row].alive && same_handle(state.hostiles[record.row].attack,h);break;
        case AttackPool::Hazard:valid=record.row<state.hazards.size() && state.hazards[record.row].alive && same_handle(state.hazards[record.row].attack,h);break;
        }
        if (!valid || !AttackBudgetSystem::retain(state,record.spec.owner.budget)) return false;
        add_indexes(state,h,record);
    }
    for (auto slot:all.free_records) if (slot>=all.records.size() || all.records[slot].alive || !all.handles.reusable(slot) || !free.insert(slot).second) return false;
    for (const auto &value:state.friends) if (value.alive && !get(state,value.attack)) return false;
    for (const auto &value:state.hostiles) if (value.alive && !get(state,value.attack)) return false;
    for (const auto &value:state.hazards) if (value.alive && !get(state,value.attack)) return false;
    return true;
}
}
