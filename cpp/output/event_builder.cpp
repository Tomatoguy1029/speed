#include "event_builder.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
namespace speed {
const char *combat_reason_name(CombatReason reason) {
    switch(reason) {
    case CombatReason::Applied:return "applied";
    case CombatReason::Invalid:return "invalid";
    case CombatReason::Dead:return "dead";
    case CombatReason::Nonpositive:return "nonpositive";
    case CombatReason::RunPhase:return "run_phase";
    case CombatReason::Guard:return "guard";
    case CombatReason::ControlsLocked:return "controls_locked";
    case CombatReason::EncounterProtected:return "encounter_protected";
    case CombatReason::DamageGate:return "damage_gate";
    case CombatReason::PhaseFloor:return "phase_floor";
    case CombatReason::BossDefeated:return "boss_defeated";
    case CombatReason::Shield:return "shield";
    case CombatReason::Invulnerability:return "invulnerability";
    case CombatReason::DebugInvincible:return "debug_invincible";
    case CombatReason::Barrier:return "barrier";
    }return "invalid";
}
namespace {
godot::StringName definition_name(const RunRuntime &run,DefinitionId id) {
    return id && id<=run.content->definitions.size()?run.content->definitions[id-1].id:godot::StringName();
}
CombatEvent event_for(RunRuntime &run,const DamageRequest &request,EnemyHandle target) {
    CombatEvent event;const auto &state=run.state;
    event.cause=request.cause;event.weapon_id=request.weapon_id;event.shatter_depth=request.shatter_depth;
    event.struck_id=state.enemy_handles.entity_id(request.struck);event.target_id=state.enemy_handles.entity_id(target);
    event.crit=request.crit;event.direction=request.direction;event.time=state.time;event.world_time=state.world_time;
    if (state.enemy_handles.contains(target)) {
        const auto &enemy=state.enemies[target.slot];event.definition=uint32_t(enemy.definition+1);
        event.pos=enemy.pos;event.radius=enemy.radius;event.facing=enemy.facing;event.elite=enemy.elite;
    }
    event.impact=request.has_impact?request.impact:event.pos;return event;
}
void append(RunRuntime &run,const char *type,godot::Dictionary data) {FrameBuilder::append(run,godot::StringName(type),data);}
}
void EventBuilder::budget_started(RunRuntime &run,const std::string &owner,int64_t id,uint32_t row,const std::vector<AttackCategory> &categories,int64_t token) {
    flush_combat(run);godot::Dictionary data;godot::Array cats;
    for (auto category:categories) cats.append(godot::String(symbol_name(category)));
    data["owner"]=godot::String::utf8(owner.c_str());data["row"]=int64_t(row);data["id"]=id;data["categories"]=cats;data["token"]=token;
    FrameBuilder::append(run,"attack_start",data);
}
void EventBuilder::budget_ended(RunRuntime &run,const std::string &owner,int64_t token) {
    flush_combat(run);godot::Dictionary data;data["owner"]=godot::String::utf8(owner.c_str());data["token"]=token;FrameBuilder::append(run,"attack_end",data);
}
void EventBuilder::enemy_damage(RunRuntime &run,const DamageRequest &request,const DamageResult &result) {
    auto event=event_for(run,request,result.target);event.kind=CombatEventKind::EnemyDamage;event.reason=result.reason;
    event.requested=result.requested;event.resolved=result.resolved;event.applied=result.applied;event.overkill=result.overkill;
    event.hp_before=result.hp_before;event.hp_after=result.hp_after;run.state.combat_events.push_back(event);
}
void EventBuilder::enemy_hit(RunRuntime &run,const DamageRequest &request,EnemyHandle target) {
    auto event=event_for(run,request,target);event.kind=CombatEventKind::Hit;event.resolved=request.amount;run.state.combat_events.push_back(event);
    if (request.crit) {event.kind=CombatEventKind::CriticalHit;run.state.combat_events.push_back(event);}
}
void EventBuilder::enemy_kill(RunRuntime &run,const DeathContext &death) {
    auto event=event_for(run,death.request,death.target);event.kind=CombatEventKind::Kill;
    event.target_id=death.corpse.id;event.definition=death.corpse.definition;event.pos=death.corpse.pos;
    event.radius=death.corpse.radius;event.facing=death.corpse.facing;event.elite=death.corpse.elite;run.state.combat_events.push_back(event);
}
void EventBuilder::player_damage(RunRuntime &run,const ShipDamageRequest &request,const ShipDamageResult &result) {
    CombatEvent event;event.kind=CombatEventKind::ShipDamage;event.cause=request.cause;event.source=request.source;event.technique=request.technique;
    event.pos=run.state.ship.pos;event.time=run.state.time;event.world_time=run.state.world_time;event.reason=result.reason;
    event.requested=request.amount;event.resolved=result.amount;event.hp_before=result.hp_before;event.hp_after=result.hp_after;event.accepted=result.accepted;
    if (result.accepted) {event.kind=CombatEventKind::Hurt;run.state.combat_events.push_back(event);event.kind=CombatEventKind::ShipDamage;}
    run.state.combat_events.push_back(event);
}
void EventBuilder::flush_combat(RunRuntime &run) {
    for (const auto &e:run.state.combat_events) {
        godot::Dictionary d;d["pos"]=e.pos;
        if (run.api_configured) {d["t"]=e.time;d["world_t"]=e.world_time;}
        const godot::StringName cause(symbol_name(e.cause));
        switch(e.kind) {
        case CombatEventKind::AttackRetired: {
            static const char *reasons[]={"lifetime","technique_cancel","technique_end","participant_end","boss_clear","bonus_clear","hit","relocate"};
            d["id"]=e.target_id;d["source_id"]=e.source_entity_id;d["reason"]=reasons[uint8_t(e.attack_end_reason)];
            d["t"]=e.time;d["world_t"]=e.world_time;append(run,"attack_retired",d);
            if (e.attack_pool==AttackPool::Hazard && run.state.bite_zone_config.fade &&
                (e.attack_end_reason==AttackEndReason::Lifetime || e.attack_end_reason==AttackEndReason::ParticipantEnd || e.attack_end_reason==AttackEndReason::TechniqueCancel || e.attack_end_reason==AttackEndReason::TechniqueEnd)) {
                godot::Dictionary visual;visual["scene"]=run.state.bite_zone_config.scene;visual["phase"]="Fade";visual["pos"]=e.pos;append(run,"attack_visual_end",visual);
            }break;
        }
        case CombatEventKind::EnemyDamage:
            d["target"]="enemy";d["struck_id"]=e.struck_id;d["target_id"]=e.target_id;d["cause"]=cause;d["weapon_id"]=e.weapon_id;
            d["requested"]=e.requested;d["resolved"]=e.resolved;d["applied"]=e.applied;d["overkill"]=e.overkill;
            d["discarded"]=std::max(0.0,e.resolved-e.applied);d["hp_before"]=e.hp_before;d["hp_after"]=e.hp_after;
            d["reason"]=combat_reason_name(e.reason);d["impact"]=e.impact;d["shatter_depth"]=e.shatter_depth;append(run,"combat_damage",d);break;
        case CombatEventKind::Hit:
            d["crit"]=e.crit;d["dmg"]=e.resolved;d["cause"]=cause;d["id"]=e.target_id;append(run,"hit",d);break;
        case CombatEventKind::CriticalHit:
            d["pos"]=e.impact;d["enemy_pos"]=e.pos;d["r"]=e.radius;d["dir"]=e.direction;append(run,"critical_hit",d);break;
        case CombatEventKind::Kill:
            d["id"]=e.target_id;d["r"]=e.radius;d["crit"]=e.crit;d["t"]=e.time;d["world_t"]=e.world_time;
            d["enemy_type"]=definition_name(run,e.definition);d["meteor_index"]=-1;d["facing"]=e.facing;
            d["elite"]=e.elite;d["cause"]=cause;d["dir"]=e.direction;
            if (e.definition && e.definition<=run.content->definitions.size()) d["color"]=run.content->definitions[e.definition-1].color;
            append(run,"kill",d);break;
        case CombatEventKind::ShieldBlock:append(run,"shield_block",d);break;
        case CombatEventKind::Hurt:
            d["amount"]=e.resolved;d["cause"]=cause;d["source"]=definition_name(run,e.source);d["t"]=e.time;
            d["world_t"]=e.world_time;d["hp_after"]=e.hp_after;append(run,"hurt",d);break;
        case CombatEventKind::ShipDamage:
            d["cause"]=cause;d["source"]=definition_name(run,e.source);d["technique"]=e.technique;d["requested"]=e.requested;
            d["amount"]=e.resolved;d["accepted"]=e.accepted;d["reason"]=combat_reason_name(e.reason);d["hp_before"]=e.hp_before;
            d["hp_after"]=e.hp_after;d["t"]=e.time;d["world_t"]=e.world_time;append(run,"combat_player_damage",d);break;
        case CombatEventKind::Retire:
            d["id"]=e.target_id;d["reason"]=int(e.retire_reason);d["enemy_type"]=definition_name(run,e.definition);append(run,"enemy_retire",d);break;
        }
    }
    run.state.combat_events.clear();
}
godot::Dictionary EventBuilder::damage_result(const RunRuntime &run,const DamageResult &result) {
    godot::Dictionary out;out["requested"]=result.requested;out["resolved"]=result.resolved;out["applied"]=result.applied;
    out["overkill"]=result.overkill;out["hp_before"]=result.hp_before;out["hp_after"]=result.hp_after;out["killed"]=result.killed;
    out["struck_id"]=run.state.enemy_handles.entity_id(result.struck);out["target_id"]=run.state.enemy_handles.entity_id(result.target);
    out["reason"]=combat_reason_name(result.reason);return out;
}
godot::Dictionary EventBuilder::ship_result(const ShipDamageResult &result) {
    godot::Dictionary out;out["accepted"]=result.accepted;out["reason"]=combat_reason_name(result.reason);
    out["hp_before"]=result.hp_before;out["hp_after"]=result.hp_after;out["amount"]=result.amount;return out;
}
}
