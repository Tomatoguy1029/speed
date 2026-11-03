#include "recording_builder.h"
#include "../runtime/run_runtime.h"
#include "../systems/attack_budget.h"
#include <algorithm>
namespace speed {
namespace {
std::string text(godot::StringName value) {return godot::String(value).utf8().get_data();}
RecordingEnemyKey enemy_key(const RunRuntime &r,const Enemy &e) {
    const auto &d=r.content->definitions[e.definition];
    return {text(d.source_id()),e.is_boss?"boss":r.state.field.rock_handles.contains(e.rock)?"meteor":d.rank>=3?"strong":"regular",e.elite};
}
std::string key_name(const RecordingEnemyKey &key) {
    return std::get<1>(key)+"/"+std::get<0>(key)+"/"+(std::get<2>(key)?"1":"0");
}
godot::Dictionary identity(const RecordingEnemyKey &key) {
    godot::Dictionary row;row["enemy"]=godot::String(std::get<0>(key).c_str());row["class"]=godot::String(std::get<1>(key).c_str());row["elite"]=std::get<2>(key);return row;
}
std::string weapon_id(const RunRuntime &r,const DamageRequest &q) {
    if (q.weapon_id) for (const auto &d:r.content->equipment) if (d.kind==0 && d.id==q.weapon_id) return d.external_id;
    switch (q.cause) {
    case Cause::ContactWave:return "W04";case Cause::Barrier:return "W05";case Cause::Mine:return "W07";
    case Cause::Sonic:return "W08";case Cause::ContactArc:return "W17";case Cause::TowShot:return "W21";
    case Cause::Bipolar:return "W22";case Cause::Interceptor:return "W25";case Cause::DashRangeDrone:return "W26";
    case Cause::Afterimage:return "W27";case Cause::FlashSlash:return "W28";case Cause::EndBlast:return "W29";
    default:return {};
    }
}
std::string source_name(const RunRuntime &r,const ShipDamageRequest &q) {
    if (q.cause==Cause::FinalStrike) return "boss";
    if (!q.source_is_explicit && q.technique && q.technique<=r.content->boss_techniques.size()) {
        const auto boss=r.content->boss_techniques[q.technique-1].boss;
        if (boss && boss<=r.content->bosses.size()) return r.content->bosses[boss-1].external_id;
    }
    return q.source && q.source<=r.content->definitions.size()?text(r.content->definitions[q.source-1].source_id()):"";
}
void finish(RunRuntime &r,int64_t id,const char *result) {
    auto &o=r.state.recording;const auto found=o.seen.find(id);if (found==o.seen.end()) return;
    const auto seen=found->second;auto &row=o.enemy_life[seen.key];const std::string outcome=result;
    if (outcome=="killed") ++row.killed;else if (outcome=="removed") ++row.removed;else ++row.alive_at_end;
    if (!seen.observed) ++row.unknown_spawn;
    else if (outcome=="killed") {
        row.life_world_sum+=std::max(0.0,r.state.world_time-seen.born);++row.life_world_count;
        if (seen.first_hit>=0) {row.first_hit_to_kill_world_sum+=std::max(0.0,r.state.world_time-seen.first_hit);++row.first_hit_to_kill_count;}
    }
    o.seen.erase(found);
    auto strong=o.strong.find(id);if (strong!=o.strong.end()) {strong->second.result=result;strong->second.life=std::max(0.0,r.state.time-strong->second.spawned);}
}
template<class T> godot::Dictionary amounts(const std::map<std::string,T> &values) {
    godot::Dictionary out;for (const auto &v:values) out[godot::String(v.first.c_str())]=v.second;return out;
}
}
void RecordingBuilder::set_active(RunRuntime &r,bool active) {
    auto &o=r.state.recording;if (o.active==active) return;
    if (active) {
        o={};o.active=true;
        for (const auto &e:r.state.enemies) if (e.alive && !e.dead) o.seen[e.id]={enemy_key(r,e),r.state.world_time,-1,false};
        budget(r);
    } else {
        budget(r);
        while (!o.seen.empty()) finish(r,o.seen.begin()->first,"alive");
        o.active=false;
    }
}
void RecordingBuilder::enemy_spawned(RunRuntime &r,EnemyHandle handle) {
    auto &o=r.state.recording;if (!o.active || !r.state.enemy_handles.contains(handle)) return;
    const auto &e=r.state.enemies[handle.slot];const auto key=enemy_key(r,e);
    o.seen[e.id]={key,r.state.world_time,-1,true};auto &life=o.enemy_life[key];++life.spawned;
    life.max_hp_at_spawn_sum+=e.max_hp;++life.max_hp_at_spawn_count;
    if (r.content->definitions[e.definition].rank>=3 && !e.is_boss) {RecordingStrong strong;strong.enemy=std::get<0>(key);strong.spawned=r.state.time;o.strong[e.id]=strong;}
}
void RecordingBuilder::enemy_released(RunRuntime &r,EnemyHandle handle) {
    if (r.state.recording.active && r.state.enemy_handles.contains(handle)) finish(r,r.state.enemies[handle.slot].id,"removed");
}
void RecordingBuilder::enemy_damage(RunRuntime &r,const DamageRequest &q,const DamageResult &hit) {
    if (!r.state.recording.active || !r.state.enemy_handles.contains(hit.target) || (hit.reason!=CombatReason::Applied && hit.reason!=CombatReason::PhaseFloor)) return;
    const auto &enemy=r.state.enemies[hit.target.slot];auto &o=r.state.recording;
    const std::string cause=symbol_name(q.cause);auto &row=o.effective_damage[{weapon_id(r,q),enemy_key(r,enemy),cause}];
    ++row.hits;row.resolved+=hit.resolved;row.applied+=hit.applied;row.overkill+=hit.overkill;row.discarded+=std::max(0.0,hit.resolved-hit.applied-hit.overkill);
    o.dealt[cause]+=hit.resolved;
    auto seen=o.seen.find(enemy.id);if (hit.applied>0 && seen!=o.seen.end() && seen->second.first_hit<0) seen->second.first_hit=r.state.world_time;
    auto strong=o.strong.find(enemy.id);if (strong!=o.strong.end()) {
        if (q.cause==Cause::Ram) ++strong->second.rams;
        else if (q.cause!=Cause::Bump && q.cause!=Cause::Touch) {strong->second.weapon_damage+=hit.resolved;strong->second.by_cause[cause]+=hit.resolved;}
    }
}
void RecordingBuilder::enemy_killed(RunRuntime &r,const DeathContext &death) {
    auto &o=r.state.recording;if (!o.active) return;
    finish(r,death.corpse.id,"killed");
    const std::string cause=symbol_name(death.request.cause);
    auto strong=o.strong.find(death.corpse.id);if (strong!=o.strong.end()) strong->second.killed_by=cause;
    if (!death.corpse.is_boss && death.request.cause!=Cause::Finale) {
        if (death.corpse.definition && death.corpse.definition<=r.content->definitions.size()) ++o.kills[text(r.content->definitions[death.corpse.definition-1].source_id())];
        ++o.kills_by[cause];
    }
}
void RecordingBuilder::player_damage(RunRuntime &r,const ShipDamageRequest &q,const ShipDamageResult &hit) {
    auto &o=r.state.recording;if (!o.active) return;
    const std::string cause=symbol_name(q.cause),source=source_name(r,q);
    ++o.enemy_contacts[{cause,source,combat_reason_name(hit.reason)}];
    if (hit.accepted) {o.damage[cause+(source.empty()?"":"/"+source)]+=hit.amount;o.last_hurt_cause=cause;o.last_hurt_source=source;}
}
void RecordingBuilder::budget(RunRuntime &r) {
    if (r.state.recording.active) ++r.state.recording.budget_observations[AttackBudgetSystem::used_cost(r.state)];
}
godot::Dictionary RecordingBuilder::read(const RunRuntime &r) {
    using namespace godot;const auto &o=r.state.recording;Dictionary counters,effective,life,contacts,strong;
    for (const auto &v:o.effective_damage) {
        auto row=identity(std::get<1>(v.first));row["weapon_id"]=String(std::get<0>(v.first).c_str());row["cause"]=String(std::get<2>(v.first).c_str());
        row["hits"]=v.second.hits;row["resolved"]=v.second.resolved;row["applied"]=v.second.applied;row["overkill"]=v.second.overkill;row["discarded"]=v.second.discarded;
        effective[String((std::get<0>(v.first)+"/"+key_name(std::get<1>(v.first))+"/"+std::get<2>(v.first)).c_str())]=row;
    }
    for (const auto &v:o.enemy_life) {
        auto row=identity(v.first);const auto &n=v.second;
        row["spawned"]=n.spawned;row["killed"]=n.killed;row["removed"]=n.removed;row["alive_at_end"]=n.alive_at_end;row["unknown_spawn"]=n.unknown_spawn;
        row["life_world_sum"]=n.life_world_sum;row["life_world_count"]=n.life_world_count;row["first_hit_to_kill_world_sum"]=n.first_hit_to_kill_world_sum;row["first_hit_to_kill_count"]=n.first_hit_to_kill_count;
        row["max_hp_at_spawn_sum"]=n.max_hp_at_spawn_sum;row["max_hp_at_spawn_count"]=n.max_hp_at_spawn_count;life[String(key_name(v.first).c_str())]=row;
    }
    for (const auto &v:o.enemy_contacts) {
        Dictionary row;row["cause"]=String(std::get<0>(v.first).c_str());row["source"]=String(std::get<1>(v.first).c_str());row["reason"]=String(std::get<2>(v.first).c_str());row["count"]=v.second;
        contacts[String((std::get<0>(v.first)+"/"+std::get<1>(v.first)+"/"+std::get<2>(v.first)).c_str())]=row;
    }
    for (const auto &v:o.strong) {
        Dictionary row;const auto &n=v.second;row["enemy"]=String(n.enemy.c_str());row["spawned"]=n.spawned;row["life"]=n.result=="alive" && o.active?std::max(0.0,r.state.time-n.spawned):n.life;
        row["rams"]=n.rams;row["weapon_damage"]=n.weapon_damage;row["by_cause"]=amounts(n.by_cause);row["result"]=String(n.result.c_str());if (!n.killed_by.empty()) row["killed_by"]=String(n.killed_by.c_str());strong[String::num_int64(v.first)]=row;
    }
    counters["effective_damage"]=effective;counters["enemy_life"]=life;counters["enemy_contacts"]=contacts;
    counters["kills"]=amounts(o.kills);counters["kills_by"]=amounts(o.kills_by);counters["dealt"]=amounts(o.dealt);counters["damage"]=amounts(o.damage);
    Dictionary costs;for (const auto &v:o.budget_observations) costs[String::num_real(v.first)]=v.second;counters["budget_observations"]=costs;
    Dictionary out;out["measurement_cumulative"]=counters;out["strong_observations"]=strong;out["attack_budget_used"]=AttackBudgetSystem::used_cost(r.state);
    int64_t enemies=0,in_view=0;Dictionary stars;const Rect2 view(r.state.view_center-r.state.view_half,r.state.view_half*2);
    for (const auto &e:r.state.enemies) if (e.alive && !e.dead) {++enemies;const String rank=String::num_int64(r.content->definitions[e.definition].rank);stars[rank]=int64_t(stars.get(rank,0))+1;if (view.has_point(e.pos)) ++in_view;}
    out["enemies"]=enemies;out["in_view"]=in_view;out["by_star"]=stars;out["hp_max"]=r.state.ship_config.max_hp;
    StringName band;for (const auto &phase:r.state.spawn_timeline.phases) {if (phase.start>r.state.time) break;band=phase.id;}out["band"]=band;
    Dictionary last;if (!o.last_hurt_cause.empty()) {last["cause"]=String(o.last_hurt_cause.c_str());last["source"]=String(o.last_hurt_source.c_str());}out["last_hurt"]=last;
    return out;
}
}
