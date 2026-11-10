#include "heroes.h"
#include "../behaviors/heroes/leo.h"
#include "combat_resolver.h"
#include "fuel.h"
#include "../behaviors/enemies/defender.h"
#include "combat_hooks.h"
#include "../behaviors/enemies/shield.h"
#include "motion_math.h"
#include "attack_system.h"
#include "enemy_system.h"
#include "pickup_system.h"
#include "attack_budget.h"
#include "attacks/zone.h"
#include "../output/event_builder.h"
#include "../runtime/run_runtime.h"
#include "../state/boss_states.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
#include <type_traits>
#include <variant>
namespace speed {
namespace {
bool boss_fuel_target(const RunRuntime &run,EnemyHandle target) {
    const auto &s=run.state;const auto &e=s.enemies[target.slot];
    const auto &def=run.content->definitions[e.definition];
    if (def.source_id()==godot::StringName("meteor") || def.id==godot::StringName("cepheus_soldier") || def.id==godot::StringName("triangle_star") || def.id==godot::StringName("hydra_rubble") || def.id==godot::StringName("iron") || def.id==godot::StringName("saw") || def.id==godot::StringName("rocket")) return false;
    if (e.is_boss) return def.kind!=EnemyDefinition::Kind::Hydra;
    if (e.boss_clone) return true;
    auto parent=e.parent;
    for (size_t n=0;n<s.enemies.size() && s.enemy_handles.contains(parent);++n) {
        const auto &p=s.enemies[parent.slot];if (p.is_boss || p.boss_clone) return true;parent=p.parent;
    }
    return false;
}
// 機体に最も近い線上の点。機体が線に重なるときは、弾の来た側（線の始点）を出どころにする。
godot::Vector2 segment_origin(godot::Vector2 ship,godot::Vector2 from,godot::Vector2 to) {
    const auto delta=to-from;const double length=delta.length_squared();
    const auto nearest=length>0?from+delta*std::clamp(double((ship-from).dot(delta))/length,0.0,1.0):from;
    return nearest.distance_squared_to(ship)<1.0?from:nearest;
}
godot::Vector2 contact_origin(const ContactShape &shape,godot::Vector2 ship) {
    return std::visit([&](const auto &s)->godot::Vector2 {
        using T=std::decay_t<decltype(s)>;
        if constexpr (std::is_same_v<T,SegmentCircle> || std::is_same_v<T,SweptSegment>) return segment_origin(ship,s.from,s.to);
        else if constexpr (std::is_same_v<T,Polyline>) {
            if (s.points.empty()) return ship;
            godot::Vector2 best=s.points.front();double distance=best.distance_squared_to(ship);
            for (size_t i=1;i<s.points.size();++i) {const auto p=segment_origin(ship,s.points[i-1],s.points[i]);const double d=p.distance_squared_to(ship);if (d<distance) {best=p;distance=d;}}
            return best;
        } else if constexpr (std::is_same_v<T,TaperedBeam>) return s.from;
        else return s.center;
    },shape);
}
}
double CombatResolver::attack_power(const RunRuntime &run) {
    const auto &c=run.state.combat_config;const auto &effects=run.state.loadout->effects;
    return c.base_attack*c.attack_mult*c.atk_scale*effects.burst_power*effects.damage_multiplier;
}
ShipContactResult CombatResolver::attack_ship_damage(RunRuntime &run,AttackHandle handle,const ContactShape &shape,double amount,double slow) {
    ShipContactResult result;const auto *attack=AttackSystem::get(run.state,handle);
    if (!attack) return result;
    const auto spec=attack->spec;const auto &policy=spec.contact;
    const auto before=attack->ship_previous_ready?attack->ship_previous:run.state.ship.pos;
    const ShipMotion ship{before,run.state.ship.pos,run.state.ship_config.ship_radius};
    result.touching=CollisionQuery::touches(shape,ship,{policy.add_ship_radius,policy.ship_sweep});
    run.state.observations.effect_check(attack->id,result.touching);
    AttackSystem::record_ship_position(run.state,handle);
    if (!result.touching || (attack->ship_hit && policy.hit_policy!=HitPolicy::EveryTick)) return result;
    if (policy.hit_policy==HitPolicy::MarkBefore) AttackSystem::mark_ship_hit(run.state,handle);
    ShipDamageRequest request;request.observation_id=spec.observation_id;request.effect_id=attack->id;request.amount=amount;request.slow=slow;request.cause=spec.cause;
    request.source_is_explicit=spec.damage_source!=0;request.source=spec.damage_source?spec.damage_source:spec.owner.source_definition;request.technique=spec.damage_technique?spec.damage_technique:spec.source_technique;
    if (spec.damage_technique && spec.damage_technique!=spec.source_technique) request.borrowed_technique=spec.source_technique;
    request.scale=policy.scale;request.hit_policy=policy.hit_policy;request.attacker=attacker_of(run,spec);
    request.origin=contact_origin(shape,run.state.ship.pos);request.has_origin=true;
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
    const double rank_mult=run.api_development && !enemy.is_boss && def.rank>=1 && def.rank<=10?state.debug_rank_hitstop[def.rank-1]:1.0;
    if (def.hitstop_multiplier<=0 || rank_mult<=0) return;
    const double stop=std::min(seconds*def.hitstop_multiplier*rank_mult,std::max(0.0,config.kill_hitstop_cap-state.dash_stop));
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
GateResult CombatResolver::gate(const RunRuntime &run,EnemyHandle target,const DamageRequest &request) {
    const auto &s=run.state;if (!s.enemy_handles.contains(target)) return GateResult::Pass;
    const auto &e=s.enemies[target.slot];const auto &d=run.content->definitions[e.definition];const bool ram=request.cause==Cause::Ram;
    const auto &p=run.combat_hooks.enemy_policy(d.kind);if (p.passes && p.passes(run,target)) return GateResult::Pass;
    if (d.kind==EnemyDefinition::Kind::Shield) return ShieldBehavior::blocks_front(run,target,request.has_impact?request.impact:e.pos,request.direction)?(ram?GateResult::Bounce:GateResult::Pass):GateResult::Allow;
    switch (d.gate) {
    case EnemyDefinition::Gate::Solid:return ram?GateResult::Bounce:GateResult::Allow;
    case EnemyDefinition::Gate::Membrane:return e.mode==EnemyMode::Recover?GateResult::Allow:GateResult::Pass;
    case EnemyDefinition::Gate::Ghost:case EnemyDefinition::Gate::Guard:return GateResult::Pass;
    case EnemyDefinition::Gate::Immortal:return ram?GateResult::Allow:GateResult::Pass;
    case EnemyDefinition::Gate::Claw:if (e.mode==EnemyMode::Recover) return GateResult::Allow;[[fallthrough]];
    case EnemyDefinition::Gate::Back:
        if (request.direction!=godot::Vector2() && std::abs(angle_difference(double(request.direction.angle())-e.facing))<3.141592653589793-d.gate_arc) return GateResult::Allow;
        return ram?GateResult::Bounce:GateResult::Pass;
    default:break;
    }
    return !p.allows || p.allows(run,target,request)?GateResult::Allow:GateResult::Pass;
}
bool CombatResolver::allows_hit(const RunRuntime &run,EnemyHandle target,const DamageRequest &request) {return gate(run,target,request)==GateResult::Allow;}
double CombatResolver::ram_damage(const RunRuntime &run,EnemyHandle target,double amount) {
    if (!run.state.enemy_handles.contains(target)) return amount;const auto &e=run.state.enemies[target.slot];const auto &d=run.content->definitions[e.definition];
    if (d.gate==EnemyDefinition::Gate::Immortal) return std::max(amount,e.hp);
    const auto &p=run.combat_hooks.enemy_policy(d.kind);return p.ram_damage?p.ram_damage(run,target,amount):amount;
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
    if (request.cause==Cause::Fire) state.enemies[result.target.slot].fire_hit=state.world_time;
    const auto definition=state.enemies[result.target.slot].definition;
    const auto policy=run.combat_hooks.enemy_policy(run.content->definitions[definition].kind);
    result.resolved=request.cause==Cause::Ram?ram_damage(run,result.target,request.amount):request.amount;
    if (!std::isfinite(result.resolved) || result.resolved<0) {result.reason=CombatReason::Invalid;EventBuilder::enemy_damage(run,request,result);return result;}
    bool fresh=state.enemies[result.target.slot].hp>=state.enemies[result.target.slot].max_hp-1e-6;
    if (state.draw.tracing) {
        auto &enemy=state.enemies[result.target.slot];
        if (enemy.dash_seen!=state.draw.dash_id) {enemy.dash_seen=state.draw.dash_id;enemy.dash_fresh=fresh;}
        fresh=enemy.dash_fresh;
    }
    state.enemies[result.target.slot].hp-=result.resolved;
    // 計測の間だけ、次の固定更新のHP復元までにボスが消えないようにする。
    if (run.api_development && run.benchmark_boss_hp>0 && state.enemies[result.target.slot].is_boss)
        state.enemies[result.target.slot].hp=std::max(1.0,state.enemies[result.target.slot].hp);
    if (policy.body_damaged) policy.body_damaged(run,result.target);
    if (!state.enemy_handles.contains(result.target)) {result.reason=CombatReason::Invalid;EventBuilder::enemy_damage(run,request,result);return result;}
    result.hp_after=state.enemies[result.target.slot].hp;
    if (result.hp_after>result.hp_before-result.resolved) result.reason=CombatReason::PhaseFloor;
    result.applied=std::max(0.0,result.hp_before-std::max(0.0,result.hp_after));
    result.overkill=result.hp_after<=0?std::max(0.0,result.resolved-std::max(0.0,result.hp_before)):0;
    result.reason=result.hp_after>result.hp_before-result.resolved?CombatReason::PhaseFloor:CombatReason::Applied;
    if (request.cause!=Cause::Debug && result.applied>0) {
        auto &enemy=state.enemies[result.target.slot];const auto &def=run.content->definitions[enemy.definition];
        if (boss_fuel_target(run,result.target)) {
            if (state.combat_config.base_attack>0) FuelSystem::add(run,result.applied/state.combat_config.base_attack*state.draw_config.fuel_per_hit);
        } else if (!enemy.is_boss && def.rank>=3 && def.rank<=10 && def.fuel_hits>0 && enemy.max_hp>0) {
            const double total=state.draw_config.fuel_per_hit*def.fuel_hits;
            const double amount=std::min(std::max(0.0,total-enemy.fuel_paid),result.applied/enemy.max_hp*total);
            enemy.fuel_paid+=amount;FuelSystem::add(run,amount);
        }
    }
    // ダメージの観測は、撃破hookが再び攻撃を生成するより前に確定する。
    EventBuilder::enemy_damage(run,request,result);
    run.combat_hooks.damage_applied(run,request,result);
    if (request.cause==Cause::Ram && result.applied>0 && state.enemy_handles.contains(result.target)) hit_stop(run,result.target,fresh,request.crit);
    if (!state.enemy_handles.contains(result.target)) return result;
    if (!request.boss_ram_visual) {
        state.enemies[result.target.slot].flash=0.12;
        if (result.applied>0) for (auto &body:state.bosses->bodies)
            if (same_handle(body.actor,result.target)) body.hit_feedback_until=state.sim_time+run.content->boss_image_feedback.duration;
    }
    auto resolved_request=request;resolved_request.amount=result.resolved;
    EventBuilder::enemy_hit(run,resolved_request,result.target);
    if (state.enemies[result.target.slot].hp<=0) result.killed=kill_enemy(run,request,result.resolved>=state.enemies[result.target.slot].max_hp*0.8).killed;
    else {
        const auto &def=run.content->definitions[definition];auto &enemy=state.enemies[result.target.slot];
        if (def.knockback>0 && !enemy.is_boss && !(state.enemy_handles.contains(enemy.parent) && state.enemies[enemy.parent.slot].is_boss)) {
            enemy.vel+=request.direction*request.knock*def.knockback/std::max(1.0,enemy.radius/20.0);
            if (request.cause==Cause::KillSonic || request.cause==Cause::CritBeam || request.cause==Cause::Bipolar || request.cause==Cause::TowShot) enemy.knock_t=0.3;
        }
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
    death.corpse.attack_priority=enemy.attack_priority;
    if (state.field.rock_handles.contains(enemy.rock)) death.corpse.rare_weapon=state.field.rocks[enemy.rock.slot].rare_weapon;
    const auto policy=run.combat_hooks.enemy_policy(run.content->definitions[enemy.definition].kind);
    if (policy.can_defeat && !policy.can_defeat(run,result.target)) {result.reason=CombatReason::PhaseFloor;return result;}
    // 形態移行を撃破に数えない。死亡印は再入するhookより先に立てる。
    if (!state.enemy_handles.contains(result.target) || state.enemies[result.target.slot].dead) {result.reason=CombatReason::Dead;return result;}
    DefenderBehavior::gone(run,result.target);state.enemies[result.target.slot].dead=true;state.dead_rows.push_back(result.target.slot);
    if (request.cause!=Cause::Debug && !enemy.is_boss && !boss_fuel_target(run,result.target)) {
        const auto &def=run.content->definitions[enemy.definition];
        const double remaining=std::max(0.0,state.draw_config.fuel_per_hit*def.fuel_hits-enemy.fuel_paid);
        state.enemies[result.target.slot].fuel_paid+=remaining;FuelSystem::add(run,remaining);
    }
    if (!enemy.is_boss) ++state.kills;
    AttackSystem::source_ended(state,result.target,AttackEndReason::ParticipantEnd);
    EnemySystem::leave_hound(state,result.target.slot);
    run.combat_hooks.death_marked(run,death);
    HeroesSystem::recovered(run,result.target);
    EventBuilder::enemy_kill(run,death);result.killed=true;
    if (enemy.is_boss) {if (policy.boss_defeated) policy.boss_defeated(run,death);return result;}
    death.hull_used=request.cause==Cause::Afterimage || run.combat_hooks.capture(run,death);
    if (death.hull_used && state.enemy_handles.contains(result.target)) state.enemies[result.target.slot].hull_scattered=true;
    if (!death.hull_used) run.combat_hooks.shatter(run,death);
    run.combat_hooks.enemy_death(run,death);
    const auto &definition=run.content->definitions[enemy.definition];
    if (definition.death_chain_definition) {
        const auto &p=run.content->death_chains[definition.death_chain_definition-1];ZoneParams zone;
        zone.position=death.corpse.pos;zone.color=definition.color;zone.radius=p.radius;zone.delay=p.delay;zone.damage=p.damage;zone.enemy_damage=attack_power(run)*p.power;
        zone.source_id=death.corpse.id;zone.source_definition=death.corpse.definition;zone.budget.value=AttackBudgetSystem(run).passive(std::to_string(death.corpse.id),death.target);ZoneSystem::emit(run,zone);
    }
    PickupSystem::drop_enemy(run,death.corpse);
    if (request.cause!=Cause::Afterimage) {
        run.combat_hooks.trait_kill(run,death);run.combat_hooks.weapon_kill(run,death);
    }
    return result;
}
int64_t CombatResolver::attacker_of(const RunRuntime &run,const AttackSpec &spec) {
    const auto &state=run.state;
    if (spec.boss.generation) return 0;
    if (state.enemy_handles.contains(spec.owner.live_source)) {
        const auto &enemy=state.enemies[spec.owner.live_source.slot];
        return enemy.is_boss?0:enemy.id;
    }
    if (!spec.owner.source_id) return 0;
    for (const auto &enemy:state.enemies) if (enemy.alive && enemy.id==spec.owner.source_id && enemy.is_boss) return 0;
    return spec.owner.source_id;
}
bool CombatResolver::invulnerable(const RunRuntime &run,const ShipDamageRequest &request) {
    const auto &ship=run.state.ship;
    // 機体全体の無敵（敵を特定しない被弾・バリア・ボスの技の保護）はすべての攻撃を防ぐ。
    if (ship.invuln>0) return true;
    if (!request.attacker) return false;
    for (const auto &entry:ship.attacker_invuln) if (entry.first==request.attacker) return entry.second>0;
    return false;
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
    } else if (invulnerable(run,request) || LeoBehavior::active(run) || state.heroes.twin.acting) result.reason=CombatReason::Invulnerability;
    else if (state.invincible) result.reason=CombatReason::DebugInvincible;
    else if (result.amount>0 && request.cause!=Cause::FinalStrike && request.cause!=Cause::Debug && run.combat_hooks.barrier(run,request,result.amount)) {
        state.ship.invuln=state.ship_config.invulnerability;result.reason=CombatReason::Barrier;
    } else {
        state.ship.hp-=result.amount;
        if (run.api_development && run.benchmark_survive && request.cause!=Cause::FinalStrike)
            state.ship.hp=std::max(1.0,state.ship.hp);
        if (request.slow>0) state.ship.glide=false;
        state.ship.vel*=1.0-std::min(0.9,request.slow);
        state.ship.hurt=state.ship_config.ship_hurt_time;
        if (request.attacker) {
            auto &list=state.ship.attacker_invuln;
            auto found=std::find_if(list.begin(),list.end(),[&](const auto &entry){return entry.first==request.attacker;});
            if (found!=list.end()) found->second=state.ship_config.invulnerability; else list.emplace_back(request.attacker,state.ship_config.invulnerability);
        } else state.ship.invuln=state.ship_config.invulnerability;
        result.hp_after=state.ship.hp;result.accepted=true;result.reason=CombatReason::Applied;
    }
    if (result.accepted) {state.lifecycle.last_request=request;state.lifecycle.last_damage=result;state.lifecycle.has_damage=true;}
    EventBuilder::player_damage(run,request,result);
    if (result.accepted && result.hp_after>0) {
        // 被弾の瞬間を見せる短い停止。突進ごとの停止の上限には数えない。とどめの一撃は敗北演出が止める。
        if (state.hitstop_enabled && state.combat_config.hurt_hitstop>0) state.hitstop=std::max(state.hitstop,state.combat_config.hurt_hitstop);
        run.combat_hooks.hurt(run,request,result);
    }
    return result;
}
}
