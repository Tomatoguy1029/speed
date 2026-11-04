#include "metrics_builder.h"
#include "frame_builder.h"
#include "recording_builder.h"
#include "../bosses/flow/technique_runner.h"
#include "../systems/attack_system.h"
#include "../systems/heroes.h"
#include "../runtime/checkpoint.h"
#include "../runtime/run_runtime.h"
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <climits>
#include <map>
#include <tuple>
#include "build_identity.h"
namespace speed {
MetricsDetailTimer::~MetricsDetailTimer() {
    if (!sample) return;
    const int64_t us=std::max<int64_t>(0,std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count());
    sample->total_us+=std::min(us,INT64_MAX-sample->total_us);
    if (sample->count<INT64_MAX) ++sample->count;
    sample->max_us=std::max(sample->max_us,us);
    for (auto &entry:sample->window_max) entry.second=std::max(entry.second,us);
}
MetricsTimer::~MetricsTimer() {
    const int64_t us=std::max<int64_t>(0,std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count());
    sample.total_us+=std::min(us,INT64_MAX-sample.total_us);
    if (sample.count<INT64_MAX) ++sample.count;
    sample.max_us=std::max(sample.max_us,us);
    for (auto &entry:sample.window_max) entry.second=std::max(entry.second,us);
}
void MetricsBuilder::diagnostic(RunRuntime &r,godot::StringName type,const godot::Dictionary &data,uint32_t detail) {
    if (r.state.observations.recording && r.state.observations.detail_level>=detail) FrameBuilder::append(r,type,data);
}
namespace {
godot::Dictionary action_fields(const RunRuntime &r,const ActionObservation &a) {
    godot::Dictionary d=a.boundary.duplicate(true);
    if (a.definition) {
        const auto &t=r.content->boss_techniques[a.definition-1];
        d["action"]=godot::String(t.external_id.c_str());d["boss"]=godot::String(r.content->bosses[t.boss-1].external_id.c_str());
    }
    d["action_id"]=a.observed_start?godot::Variant(a.id):godot::Variant();d["body_id"]=a.actor_id;
    d["observed_start"]=a.observed_start;d["origin"]=a.origin;
    d["decision_id"]=a.observed_start && a.decision_id?godot::Variant(a.decision_id):godot::Variant();return d;
}
const char *observed_outcome(uint64_t checks,uint64_t contacts,double applied) {
    return applied>0?"hit":contacts>0?"contact_blocked":checks>0?"evaluated_miss":"no_hit_observed";
}
const char *effect_end_reason(AttackEndReason reason) {
    switch (reason) {
        case AttackEndReason::Lifetime:return "lifetime";case AttackEndReason::TechniqueCancel:return "technique_cancel";
        case AttackEndReason::TechniqueEnd:return "technique_end";case AttackEndReason::ParticipantEnd:return "participant_end";
        case AttackEndReason::BossClear:return "boss_clear";case AttackEndReason::BonusClear:return "bonus_clear";
        case AttackEndReason::Hit:return "hit";case AttackEndReason::Relocate:return "relocate";case AttackEndReason::Barrier:return "barrier";
    }
    return "lifetime";
}
}
void MetricsBuilder::flush_observations(RunRuntime &r) {
    auto &o=r.state.observations;
    for (const auto &e:o.pending) {
        const auto &a=e.action;if (a.definition>r.content->boss_techniques.size()) continue;
        auto d=action_fields(r,a);
        const char *steps[]={"selected","execute","warning","aim_lock","recovery","interrupted","observation_end","observation_end","observation_end"};
        d["step"]=steps[e.step];d["checks"]=int64_t(a.checks);d["contacts"]=int64_t(a.contacts);d["applied"]=a.applied;
        d["observation_scope"]="actor_direct_geometry";
        if (e.step>=ObservationEvent::Finished) d["outcome"]=observed_outcome(a.checks,a.contacts,a.applied);
        d["reason"]=e.step==ObservationEvent::RecordingEnd?godot::StringName("recording_end"):e.step==ObservationEvent::ActorEnd?godot::StringName("actor_end"):a.reason;
        FrameBuilder::append(r,"boss_action",d);
    }
    o.pending.clear();
    for (const auto &event:o.pending_effects) {
        const auto &e=event.effect;if (e.definition>r.content->boss_techniques.size()) continue;
        auto d=action_fields(r,e.action);d.erase("t");d.erase("world_t");
        d["observed_start"]=e.observed_start;d["effect_id"]=e.id;
        d["step"]=event.step==EffectObservationEvent::Spawned?"spawned":"ended";
        d["spawn_position"]=e.born_pos;d["position"]=e.pos;d["checks"]=int64_t(e.checks);d["contacts"]=int64_t(e.contacts);d["applied"]=e.applied;
        d["observation_scope"]="effect_observed_lifetime";
        if (event.step!=EffectObservationEvent::Spawned) {
            d["outcome"]=observed_outcome(e.checks,e.contacts,e.applied);
            d["reason"]=event.step==EffectObservationEvent::RecordingEnd?"recording_end":effect_end_reason(event.reason);
        }
        FrameBuilder::append(r,"boss_effect",d);
    }
    o.pending_effects.clear();
}
void MetricsBuilder::set_recording(RunRuntime &r,bool active,uint32_t level) {
    auto &s=r.state;auto &o=s.observations;
    if (o.recording==active && (!active || o.detail_level==level)) return;
    if (o.recording) {AttackSystem::sync_observation_positions(s);o.stop();flush_observations(r);}
    RecordingBuilder::set_active(r,active);
    for (auto &f:s.bosses.flows) {f.decision_id=0;for (auto &n:f.nodes) n.decision_id=0;}
    for (auto &t:s.bosses.techniques) t.decision_id=0;
    if (active) {
        o.detail_level=level;o.recording=true;
        for (auto &t:s.bosses.techniques) if (t.stage<TechniqueStage::Finished) t.observation_id=o.begin(s.enemy_handles.entity_id(t.actor),t.definition,false);
        for (auto &b:s.bosses.bodies) {
            b.final_observation_id=0;
            if (b.mode==BossMode::Final && (!b.final_landed || b.draco.finale.active)) TechniqueRunner::observe_scripted(r,b,b.draco.finale.active?"draco_finale":"final_strike",b.draco.finale.active?"scripted_finale":"final_strike_replay",ObservationEvent::Selected,false);
        }
        // 終了して行が再利用された技も、発生時のHandleと出所で分ける。
        std::map<std::tuple<int64_t,uint64_t,uint32_t>,int64_t> remaining;
        for (auto &a:s.attacks.records) if (a.alive && (a.spec.source_technique || s.bosses.body_handles.contains(a.spec.boss))) {
            auto &spec=a.spec;int64_t id=0;
            if (!spec.source_technique && s.bosses.body_handles.contains(spec.boss)) id=s.bosses.bodies[spec.boss.slot].final_observation_id;
            else if (s.bosses.handles.contains(spec.technique)) id=s.bosses.techniques[spec.technique.slot].observation_id;
            else for (const auto &t:s.bosses.techniques) if (t.stage<TechniqueStage::Finished && t.definition==spec.source_technique && s.enemy_handles.entity_id(t.actor)==spec.owner.source_id) {id=t.observation_id;break;}
            if (!spec.source_technique && !id) continue;
            if (!o.find(id)) {
                const auto key=std::make_tuple(spec.owner.source_id,handle_key(spec.technique),spec.source_technique);
                auto &retained=remaining[key];if (!retained) {retained=o.begin(spec.owner.source_id,spec.source_technique,false);if (auto *v=o.find(retained)) v->running=false;}
                id=retained;
            }
            spec.observation_id=id;o.retain(id);
            godot::Vector2 pos;
            if (a.pool==AttackPool::Friendly) pos=s.friends[a.row].pos;
            else if (a.pool==AttackPool::Hostile) pos=s.hostiles[a.row].pos;
            else pos=s.hazards[a.row].pos;
            o.effect_begin(a.id,id,pos,false);
        }
    }
    flush_observations(r);
}
godot::Dictionary MetricsBuilder::read(const RunRuntime &run,const std::string &reader) {
    auto out=FrameBuilder::metrics(run);godot::Dictionary timings;
    const auto packed=[&](MetricSample &sample) {
        godot::Array values;values.push_back(sample.total_us);values.push_back(sample.count);values.push_back(sample.max_us);
        if (!reader.empty()) {auto found=sample.window_max.find(reader);values.push_back(found==sample.window_max.end()?int64_t(0):found->second);if (found!=sample.window_max.end()) found->second=0;}
        return values;
    };
    timings["sim"]=packed(run.frame_workspace.metrics.sim);timings["output_build"]=packed(run.frame_workspace.metrics.output_build);
    godot::Dictionary detail;for (auto &entry:run.frame_workspace.metrics.detail) detail[godot::String(entry.first.c_str())]=packed(entry.second);
    out["detail_timings"]=detail;
    godot::Dictionary render_rows;for (auto &entry:run.frame_workspace.metrics.render_rows) render_rows[godot::String(entry.first.c_str())]=packed(entry.second);out["render_rows"]=render_rows;
    const auto &s=run.state;godot::Dictionary rows;
    const auto pool=[](int64_t used,size_t capacity) {godot::Array values;values.push_back(used);values.push_back(int64_t(capacity));return values;};
    int64_t coins=0,hostiles=0,hazards=0;for (const auto &v:s.pickups.coins) if (v.alive) ++coins;
    for (const auto &v:s.hostiles) if (v.alive) ++hostiles;for (const auto &v:s.hazards) if (v.alive) ++hazards;
    rows["enemies"]=pool(s.rows_by_id.size(),s.enemies.size());rows["friendly"]=pool(s.live_friends,s.friends.size());rows["hostile"]=pool(hostiles,s.hostiles.size());rows["hazards"]=pool(hazards,s.hazards.size());
    rows["crystals"]=pool(s.pickups.live_gems,s.pickups.gems.size());rows["coins"]=pool(coins,s.pickups.coins.size());out["rows"]=rows;
    out["timings"]=timings;return out;
}
godot::Dictionary MetricsBuilder::recording(const RunRuntime &run,bool initial) {
    using namespace godot;
    const auto &s=run.state;const auto &p=s.pickups;const auto &c=*run.content;
    static const char *names[]={"low","mid","high"};
    const auto totals=[&](const std::array<CrystalTotal,3> &values) {
        Dictionary out;for (size_t i=0;i<3;++i) {Dictionary row;row["count"]=int64_t(values[i].count);row["base_xp"]=values[i].base_xp;row["actual_xp"]=values[i].actual_xp;out[names[i]]=row;}return out;
    };
    std::array<CrystalTotal,3> ground{},carried{};Array existing_ground,existing_cargo;
    const auto crystal=[&](const CrystalState &g) {Dictionary row;row["id"]=int64_t(g.id);row["kind"]=names[g.kind];row["base_xp"]=g.value;return row;};
    for (const auto &g:p.gems) if (g.alive) {
        ++ground[g.kind].count;ground[g.kind].base_xp+=g.value;
        if (initial) {auto row=crystal(g);Array pos;pos.push_back(g.pos.x);pos.push_back(g.pos.y);row["pos"]=pos;row["absorber"]=g.id==p.gem_absorber_id;existing_ground.push_back(row);}
    }
    for (const auto &entry:p.cargo) {
        Array rows;for (const auto &g:entry.crystals) {++carried[g.kind].count;carried[g.kind].base_xp+=g.value;if (initial) rows.push_back(crystal(g));}
        if (initial) {Dictionary row;row["enemy_id"]=entry.enemy_id;row["crystals"]=rows;existing_cargo.push_back(row);}
    }
    Dictionary cap;cap["mode"]="offscreen_low_far_old";cap["limit"]=s.pickup_config.gem_max;cap["absorber_id"]=p.gem_absorber_id?int64_t(p.gem_absorber_id):-1;
    Dictionary xp;xp["supplied"]=totals(p.supplied);xp["collected"]=totals(p.collected);xp["lost"]=totals(p.lost);xp["ground"]=totals(ground);xp["carried"]=totals(carried);xp["cap"]=cap;
    Dictionary rolls;rolls["eligible"]=int64_t(p.gold_rolls);rolls["won"]=int64_t(p.gold_won);xp["gold_rolls"]=rolls;xp["collected_actual_xp"]=p.collected_actual_xp;
    int64_t weapons=0,traits=0,wm=0,tm=0;Dictionary weapon_levels,trait_levels;
    for (const auto &d:c.equipment) {auto &maximum=d.kind==0?wm:tm;maximum=std::max(maximum,int64_t(d.maximum_level));}
    for (const auto &v:s.loadout.weapons) {const auto &d=c.equipment[v.definition-1];weapons+=std::min(v.level,d.maximum_level);weapon_levels[String::utf8(d.external_id.c_str())]=v.level;}
    for (const auto &v:s.loadout.traits) {const auto &d=c.equipment[v.definition-1];traits+=std::min(v.level,d.maximum_level);trait_levels[String::utf8(d.external_id.c_str())]=v.level;}
    const int64_t maximum=c.progression.weapon_slots*wm+c.progression.trait_slots*tm;
    Dictionary progress;progress["weapon_levels"]=weapons;progress["trait_levels"]=traits;progress["max_levels"]=maximum;progress["completion"]=maximum?double(weapons+traits)/maximum:0.0;
    Dictionary out;out["t"]=s.time;out["world_t"]=s.world_time;out["level"]=s.loadout.level;out["hp"]=s.ship.hp;out["kills"]=s.kills;out["weapons"]=weapon_levels;out["traits"]=trait_levels;out["xp"]=xp;out["equipment_progress"]=progress;
    Dictionary origins,roles;
    for (const auto &e:s.enemies) if (e.alive && !e.dead) {
        const StringName origin(symbol_name(e.origin)),role(symbol_name(e.role));origins[origin]=int64_t(origins.get(origin,0))+1;roles[role]=int64_t(roles.get(role,0))+1;
    }
    Dictionary population;population["origins"]=origins;population["roles"]=roles;population["raw"]=s.population.raw;population["accumulator"]=s.population.accumulator;out["population"]=population;
    out["active_observations"]=int64_t(s.observations.actions.size());
    Dictionary diagnostics;diagnostics["level"]=s.observations.detail_level;diagnostics["tracked_effects"]=int64_t(s.observations.effects.size());diagnostics["effect_tracking_dropped"]=int64_t(s.observations.effect_tracking_dropped);out["combat_diagnostics"]=diagnostics;
    out.merge(RecordingBuilder::read(run),true);
    if (initial) {
        Dictionary start;start["t"]=s.time;start["world_t"]=s.world_time;start["phase"]=int(s.phase);start["level"]=s.loadout.level;
        start["xp"]=s.loadout.xp;start["xp_gained"]=s.loadout.xp_gained;start["xp_dropped"]=p.xp_dropped;start["hp"]=s.ship.hp;start["hp_max"]=s.ship_config.max_hp;start["kills"]=s.kills;
        start["weapons"]=weapon_levels;start["traits"]=trait_levels;start["hero_power"]=HeroesSystem::snapshot(run)["power"];start["bonus_t"]=s.control.bonus_remaining;start["endless"]=s.lifecycle.endless;out["run_state"]=start;
        Array bands;for (const auto &phase:s.spawn_timeline.phases) {Dictionary row;row["id"]=phase.id;row["start"]=phase.start;bands.push_back(row);}out["bands"]=bands;
        Dictionary conditions,stats,profile,mult,add,reduce;
        stats["max_speed"]=s.ship_config.max_speed;stats["max_hp"]=s.ship_config.max_hp;
        stats["attack_mult"]=s.combat_config.attack_mult;stats["crit_chance"]=s.combat_config.crit_chance;stats["crit_mult"]=s.combat_config.crit_mult;
        stats["pickup_radius"]=s.pickup_config.coin_radius;stats["xp_pickup_radius"]=s.pickup_config.xp_radius;stats["charge_time"]=s.draw_config.charge_time;
        stats["capacity"]=s.draw_config.capacity;stats["length_mult"]=s.draw_config.length_mult;stats["glide_duration_mult"]=s.ship_config.glide_duration_mult;
        stats["xp_mult"]=s.pickup_config.xp_mult;stats["xp_gain_mult"]=s.loadout.xp_gain_mult;stats["acceleration"]=s.ship_config.acceleration;
        stats["turn_rate"]=s.ship_config.turn_rate;stats["invulnerability"]=s.ship_config.invulnerability;stats["repair_fraction"]=s.pickup_config.repair_fraction;stats["pickup_speed_mult"]=s.pickup_config.speed_mult;
        const auto &l=s.loadout;mult["max_speed"]=l.speed_profile_factor;mult["attack"]=l.attack_profile_factor;mult["pickup"]=l.pickup_profile_factor;mult["length"]=l.length_profile_factor;mult["xp"]=l.xp_profile_factor;
        add["max_hp"]=l.hp_profile_add;add["reroll"]=l.reroll_profile_add;reduce["charge_time"]=l.charge_profile_factor;profile["mult"]=mult;profile["add"]=add;profile["reduce"]=reduce;
        conditions["config"]=config_snapshot(c.config);conditions["stats"]=stats;conditions["profile"]=profile;
        conditions["rng_state"]=String::num_uint64(s.control.rng.get_state());conditions["rng_algorithm"]="pcg32";
        conditions["hitstop_enabled"]=s.hitstop_enabled;conditions["invincible"]=s.invincible;out["conditions"]=conditions;
        Dictionary tuning;
        for (const auto &v:c.enemy_tuning) {const auto id=c.definitions[v.enemy-1].id;Dictionary values=tuning.get(id,Dictionary());values[String::utf8(v.key.c_str())]=v.value;tuning[id]=values;}
        out["enemy_tuning"]=tuning;
        Dictionary existing;existing["ground"]=existing_ground;existing["carried"]=existing_cargo;existing["cap"]=cap;out["existing"]=existing;
        Dictionary values,rewards;for (size_t i=0;i<3;++i) values[names[i]]=c.crystal_values[i];
        for (const auto &d:c.definitions) {Array counts;for (auto n:d.xp_rewards) counts.push_back(int64_t(n));Dictionary reward;reward["rank"]=d.rank;reward["counts"]=counts;reward["strong_gold"]=d.gold_eligible;rewards[d.id]=reward;}
        Dictionary config;config["xp_reward_version"]=2;config["xp_crystal_values"]=values;config["enemy_rewards"]=rewards;config["strong_gold_chance"]=s.pickup_config.strong_gold_chance;config["gem_draw_max"]=s.pickup_config.gem_draw_max;Dictionary limit=cap.duplicate();limit.erase("absorber_id");config["cap"]=limit;
        config["ship_multiplier"]=s.pickup_config.xp_mult;config["run_multiplier"]=s.loadout.xp_gain_mult;config["collection_multiplier"]=s.pickup_config.xp_mult*s.loadout.xp_gain_mult;config["multiplier_application"]="collection_once";
        config["xp_base"]=c.progression.xp_base;config["xp_growth"]=c.progression.xp_growth;config["xp_curve"]=c.progression.xp_curve;out["xp_config"]=config;
        PackedByteArray digest;digest.resize(32);std::copy(c.payload_sha256.begin(),c.payload_sha256.end(),digest.ptrw());Dictionary identity;identity["payload_sha256"]=digest.hex_encode();
        std::copy(c.input_sha256.begin(),c.input_sha256.end(),digest.ptrw());identity["input_sha256"]=digest.hex_encode();
        identity["implementation_sha256"]=speed::implementation_sha256();
        identity["abi_version"]=ABI_VERSION;identity["state_schema_version"]=STATE_SCHEMA_VERSION;identity["stage_id"]=s.control.stage_id;out["identity"]=identity;
    }
    return out;
}

}
