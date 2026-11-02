#include "combat_resolver.h"
#include "combat_hooks.h"
#include "attack_system.h"
#include "enemy_system.h"
#include "pickup_system.h"
#include "../output/event_builder.h"
#include "../runtime/run_runtime.h"
#include <algorithm>
#include <cmath>
namespace speed {
double CombatResolver::attack_power(const RunRuntime &run) {
    const auto &c=run.state.combat_config;const auto &effects=run.state.loadout.effects;
    return c.base_attack*c.attack_mult*c.atk_scale*effects.burst_power*effects.damage_multiplier;
}
ShipContactResult CombatResolver::attack_ship_damage(RunRuntime &run,AttackHandle handle,const ContactShape &shape,double amount,double slow) {
    ShipContactResult result;const auto *attack=AttackSystem::get(run.state,handle);
    if (!attack) return result;
    const auto spec=attack->spec;const auto &policy=spec.contact;
    const auto before=attack->ship_previous_ready?attack->ship_previous:run.state.ship.pos;
    const ShipMotion ship{before,run.state.ship.pos,run.state.ship_config.ship_radius};
    result.touching=CollisionQuery::touches(shape,ship,{policy.add_ship_radius,policy.ship_sweep});
    AttackSystem::record_ship_position(run.state,handle);
    if (!result.touching || (attack->ship_hit && policy.hit_policy!=HitPolicy::EveryTick)) return result;
    if (policy.hit_policy==HitPolicy::MarkBefore) AttackSystem::mark_ship_hit(run.state,handle);
    ShipDamageRequest request;request.amount=amount;request.slow=slow;request.cause=spec.cause;
    request.source=spec.owner.source_definition;request.technique=spec.source_technique;
    request.scale=policy.scale;request.hit_policy=policy.hit_policy;
    result.attempted=true;result.damage=ship_damage(run,request);
    if (policy.hit_policy==HitPolicy::MarkAfter || (policy.hit_policy==HitPolicy::MarkIfAccepted && result.damage.accepted)) AttackSystem::mark_ship_hit(run.state,handle);
    return result;
}
namespace {
CombatReason protection(const RunRuntime &run,EnemyHandle target) {
    const auto &state=run.state;
    if (!state.enemy_handles.contains(target) || !state.enemies[target.slot].alive) return CombatReason::Invalid;
    const auto &enemy=state.enemies[target.slot];
    if (enemy.dead) return CombatReason::Dead;
    if (state.phase!=godot::RunState::Phase::Play) return CombatReason::RunPhase;
    if (enemy.guard>0) return CombatReason::Guard;
    if (state.controls_locked) return CombatReason::ControlsLocked;
    if (state.encounter_protected) return CombatReason::EncounterProtected;
    return CombatReason::Applied;
}
void hit_stop(RunRuntime &run,EnemyHandle target,bool fresh,bool crit) {
    auto &state=run.state;const auto &enemy=state.enemies[target.slot];
    const auto &def=run.content->definitions[enemy.definition];const auto &config=state.combat_config;
    if (!state.hitstop_enabled || state.phase!=godot::RunState::Phase::Play || state.controls_locked || state.encounter_protected) return;
    double seconds=0;
    if (fresh && enemy.hp<=0) seconds=config.kill_hitstop*(enemy.radius>25?config.hitstop_big_mult:1.0)*(crit?config.hitstop_crit_mult:1.0);
    if (crit) seconds=std::max(seconds,enemy.hp<=0?0.05:0.035);
    if (def.hitstop_multiplier<=0) return;
    const double stop=std::min(seconds*def.hitstop_multiplier,std::max(0.0,config.kill_hitstop_cap-state.dash_stop));
    state.hitstop=std::max(state.hitstop,stop);state.dash_stop+=stop;
}
}
EnemyHandle CombatResolver::damage_target(const RunRuntime &run,EnemyHandle struck) {
    const auto &state=run.state;EnemyHandle target=struck;
    // 世代の古い参照と循環は、ほかの個体への命中に変換しない。
    for (size_t i=0;i<=state.enemies.size();++i) {
        if (!state.enemy_handles.contains(target)) return {};
        const auto next=state.enemies[target.slot].damage_target;
        if (!next.generation) return target;
        target=next;
    }
    return {};
}
bool CombatResolver::allows_hit(const RunRuntime &run,EnemyHandle target,const DamageRequest &request) {
    if (!run.state.enemy_handles.contains(target)) return false;
    const auto &enemy=run.state.enemies[target.slot];
    const auto &policy=run.combat_hooks.enemy_policy(run.content->definitions[enemy.definition].kind);
    return !policy.allows || policy.allows(run,target,request);
}
DamageResult CombatResolver::damage_enemy(RunRuntime &run,const DamageRequest &request) {
    CombatHooks::Dispatch dispatch(run.combat_hooks);
    auto &state=run.state;DamageResult result;result.struck=request.struck;result.requested=request.amount;
    result.target=damage_target(run,request.struck);
    result.reason=protection(run,result.target);
    if (state.enemy_handles.contains(result.target)) result.hp_before=result.hp_after=state.enemies[result.target.slot].hp;
    if (!std::isfinite(request.amount) || !request.direction.is_finite() || !request.impact.is_finite() || !std::isfinite(request.knock) || request.shatter_depth<0 || request.cause>=Cause::Count) result.reason=CombatReason::Invalid;
    else if (result.reason!=CombatReason::Dead && request.amount<=0) result.reason=CombatReason::Nonpositive;
    if (result.reason!=CombatReason::Applied) {EventBuilder::enemy_damage(run,request,result);return result;}
    if (request.cause!=Cause::Ram && request.cause!=Cause::Bump && !allows_hit(run,result.target,request)) {
        result.reason=CombatReason::DamageGate;EventBuilder::enemy_damage(run,request,result);return result;
    }
    const auto definition=state.enemies[result.target.slot].definition;
    const auto policy=run.combat_hooks.enemy_policy(run.content->definitions[definition].kind);
    result.resolved=request.cause==Cause::Ram && policy.ram_damage?policy.ram_damage(run,result.target,request.amount):request.amount;
    if (!std::isfinite(result.resolved) || result.resolved<0) {result.reason=CombatReason::Invalid;EventBuilder::enemy_damage(run,request,result);return result;}
    bool fresh=state.enemies[result.target.slot].hp>=state.enemies[result.target.slot].max_hp-1e-6;
    if (state.draw.tracing) {
        auto &enemy=state.enemies[result.target.slot];
        if (enemy.dash_seen!=state.draw.dash_id) {enemy.dash_seen=state.draw.dash_id;enemy.dash_fresh=fresh;}
        fresh=enemy.dash_fresh;
    }
    state.enemies[result.target.slot].hp-=result.resolved;
    if (policy.body_damaged) policy.body_damaged(run,result.target);
    if (!state.enemy_handles.contains(result.target)) {result.reason=CombatReason::Invalid;EventBuilder::enemy_damage(run,request,result);return result;}
    result.hp_after=state.enemies[result.target.slot].hp;
    result.applied=std::max(0.0,result.hp_before-std::max(0.0,result.hp_after));
    result.overkill=result.hp_after<=0?std::max(0.0,result.resolved-std::max(0.0,result.hp_before)):0;
    result.reason=result.hp_after>result.hp_before-result.resolved?CombatReason::PhaseFloor:CombatReason::Applied;
    // ダメージの観測は、撃破hookが再び攻撃を生成するより前に確定する。
    EventBuilder::enemy_damage(run,request,result);
    run.combat_hooks.damage_applied(run,request,result);
    if (request.cause==Cause::Ram && result.applied>0 && state.enemy_handles.contains(result.target)) hit_stop(run,result.target,fresh,request.crit);
    if (!state.enemy_handles.contains(result.target)) return result;
    state.enemies[result.target.slot].flash=0.12;
    auto resolved_request=request;resolved_request.amount=result.resolved;
    EventBuilder::enemy_hit(run,resolved_request,result.target);
    if (state.enemies[result.target.slot].hp<=0) result.killed=kill_enemy(run,request,result.resolved>=state.enemies[result.target.slot].max_hp*0.8).killed;
    else {
        const auto &def=run.content->definitions[definition];auto &enemy=state.enemies[result.target.slot];
        if (def.knockback>0 && !(state.enemy_handles.contains(enemy.parent) && state.enemies[enemy.parent.slot].is_boss)) enemy.vel+=request.direction*request.knock*def.knockback/std::max(1.0,enemy.radius/20.0);
    }
    if (request.crit && !request.no_crit) run.combat_hooks.critical(run,request,result);
    return result;
}
KillResult CombatResolver::kill_enemy(RunRuntime &run,const DamageRequest &request,bool one_shot) {
    CombatHooks::Dispatch dispatch(run.combat_hooks);
    auto &state=run.state;KillResult result;result.target=damage_target(run,request.struck);result.reason=protection(run,result.target);
    if (request.cause>=Cause::Count || request.shatter_depth<0 || !request.direction.is_finite()) result.reason=CombatReason::Invalid;
    if (result.reason!=CombatReason::Applied) return result;
    const auto enemy=state.enemies[result.target.slot];
    DeathContext death;death.request=request;death.target=result.target;death.one_shot=one_shot;
    death.corpse={enemy.id,uint32_t(enemy.definition+1),enemy.pos,enemy.vel,enemy.radius,enemy.facing,enemy.max_hp,enemy.xp,enemy.elite,enemy.is_boss};
    if (state.field.rock_handles.contains(enemy.rock)) death.corpse.rare_weapon=state.field.rocks[enemy.rock.slot].rare_weapon;
    const auto policy=run.combat_hooks.enemy_policy(run.content->definitions[enemy.definition].kind);
    if (policy.can_defeat && !policy.can_defeat(run,result.target)) {result.reason=CombatReason::PhaseFloor;return result;}
    // 形態移行を撃破に数えない。死亡印は再入するhookより先に立てる。
    if (!state.enemy_handles.contains(result.target) || state.enemies[result.target.slot].dead) {result.reason=CombatReason::Dead;return result;}
    state.enemies[result.target.slot].dead=true;state.dead_rows.push_back(result.target.slot);
    if (!enemy.is_boss) ++state.kills;
    AttackSystem::source_ended(state,result.target,AttackEndReason::ParticipantEnd);
    EnemySystem::leave_hound(state,result.target.slot);
    run.combat_hooks.death_marked(run,death);
    EventBuilder::enemy_kill(run,death);result.killed=true;
    if (enemy.is_boss) {if (policy.boss_defeated) policy.boss_defeated(run,death);return result;}
    death.hull_used=request.cause==Cause::Afterimage || run.combat_hooks.capture(run,death);
    if (death.hull_used && state.enemy_handles.contains(result.target)) state.enemies[result.target.slot].hull_scattered=true;
    if (!death.hull_used) run.combat_hooks.shatter(run,death);
    run.combat_hooks.enemy_death(run,death);
    PickupSystem::drop_enemy(run,death.corpse);
    if (request.cause!=Cause::Afterimage) {
        run.combat_hooks.trait_kill(run,death);run.combat_hooks.weapon_kill(run,death);
    }
    return result;
}
ShipDamageResult CombatResolver::ship_damage(RunRuntime &run,const ShipDamageRequest &request) {
    CombatHooks::Dispatch dispatch(run.combat_hooks);auto &state=run.state;
    ShipDamageResult result;result.hp_before=result.hp_after=state.ship.hp;
    result.amount=request.amount*(request.scale==DamageScale::AtkScale?state.combat_config.atk_scale:1.0);
    if (!std::isfinite(result.amount) || !std::isfinite(request.slow) || request.cause>=Cause::Count) result.reason=CombatReason::Invalid;
    else if (state.phase!=godot::RunState::Phase::Play) result.reason=CombatReason::RunPhase;
    else if (state.boss_dead) result.reason=CombatReason::BossDefeated;
    else if (state.controls_locked) result.reason=CombatReason::ControlsLocked;
    else if (state.encounter_protected) result.reason=CombatReason::EncounterProtected;
    else if (state.ship.shield_t>0) {
        if (state.ship.shield_flash<=0) {CombatEvent event;event.kind=CombatEventKind::ShieldBlock;event.pos=state.ship.pos;state.combat_events.push_back(event);}
        state.ship.shield_flash=0.12;result.reason=CombatReason::Shield;
    } else if (state.ship.invuln>0) result.reason=CombatReason::Invulnerability;
    else if (state.invincible) result.reason=CombatReason::DebugInvincible;
    else if (result.amount>0 && request.cause!=Cause::FinalStrike && request.cause!=Cause::Debug && run.combat_hooks.barrier(run,request,result.amount)) {
        state.ship.invuln=state.ship_config.invulnerability;result.reason=CombatReason::Barrier;
    } else {
        state.ship.hp-=result.amount;
        if (request.slow>0) state.ship.glide=false;
        state.ship.vel*=1.0-std::min(0.9,request.slow);
        state.ship.invuln=state.ship_config.invulnerability;state.ship.hurt=state.ship_config.ship_hurt_time;
        result.hp_after=state.ship.hp;result.accepted=true;result.reason=CombatReason::Applied;
    }
    if (result.accepted) {state.lifecycle.last_request=request;state.lifecycle.last_damage=result;state.lifecycle.has_damage=true;}
    EventBuilder::player_damage(run,request,result);
    if (result.accepted && result.hp_after>0) run.combat_hooks.hurt(run,request,result);
    return result;
}
}
