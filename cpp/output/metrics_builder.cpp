#include "metrics_builder.h"
#include "frame_builder.h"
#include "../runtime/checkpoint.h"
#include "../runtime/run_runtime.h"
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <climits>
#include <map>
#include <tuple>
namespace speed {
MetricsTimer::~MetricsTimer() {
    const int64_t us=std::max<int64_t>(0,std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-began).count());
    sample.total_us+=std::min(us,INT64_MAX-sample.total_us);
    if (sample.count<INT64_MAX) ++sample.count;
    sample.max_us=std::max(sample.max_us,us);
}
void MetricsBuilder::flush_observations(RunRuntime &r) {
    for (const auto &e:r.state.observations.pending) {
        const auto &a=e.action;const auto &t=r.content->boss_techniques[a.definition-1];
        godot::Dictionary d;d["action_id"]=a.id;d["body_id"]=a.actor_id;d["action"]=godot::String(t.external_id.c_str());
        d["boss"]=godot::String(r.content->bosses[t.boss-1].external_id.c_str());d["observed_start"]=a.observed_start;
        d["step"]=e.step==ObservationEvent::Selected?"selected":e.step==ObservationEvent::Execute?"execute":"observation_end";
        d["checks"]=int64_t(a.checks);d["contacts"]=int64_t(a.contacts);d["applied"]=a.applied;
        if (e.step>=ObservationEvent::Finished) d["outcome"]=a.applied>0?"hit":a.contacts>0?"contact_blocked":a.checks>0?"evaluated_miss":"no_hit_observed";
        d["reason"]=e.step==ObservationEvent::RecordingEnd?"recording_end":e.step==ObservationEvent::ActorEnd?"actor_end":"finished";
        FrameBuilder::append(r,"boss_action",d);
    }
    r.state.observations.pending.clear();
}
void MetricsBuilder::set_recording(RunRuntime &r,bool active) {
    auto &s=r.state;auto &o=s.observations;if (o.recording==active) return;
    if (!active) o.stop();else {
        o.recording=true;
        for (auto &t:s.bosses.techniques) if (t.stage<TechniqueStage::Finished) t.observation_id=o.begin(s.enemy_handles.entity_id(t.actor),t.definition,false);
        // 終了して行が再利用された技も、発生時のHandleと出所で分ける。
        std::map<std::tuple<int64_t,uint64_t,uint32_t>,int64_t> remaining;
        for (auto &a:s.attacks.records) if (a.alive && a.spec.source_technique) {
            auto &spec=a.spec;int64_t id=0;
            if (s.bosses.handles.contains(spec.technique)) id=s.bosses.techniques[spec.technique.slot].observation_id;
            else for (const auto &t:s.bosses.techniques) if (t.stage<TechniqueStage::Finished && t.definition==spec.source_technique && s.enemy_handles.entity_id(t.actor)==spec.owner.source_id) {id=t.observation_id;break;}
            if (!o.find(id)) {
                const auto key=std::make_tuple(spec.owner.source_id,handle_key(spec.technique),spec.source_technique);
                auto &retained=remaining[key];if (!retained) {retained=o.begin(spec.owner.source_id,spec.source_technique,false);if (auto *v=o.find(retained)) v->running=false;}
                id=retained;
            }
            spec.observation_id=id;o.retain(id);
        }
    }
    flush_observations(r);
}
godot::Dictionary MetricsBuilder::read(const RunRuntime &run) {
    auto out=FrameBuilder::metrics(run);godot::Dictionary timings;
    const auto packed=[](const MetricSample &sample) {godot::Array values;values.push_back(sample.total_us);values.push_back(sample.count);values.push_back(sample.max_us);return values;};
    timings["sim"]=packed(run.frame_workspace.metrics.sim);timings["output_build"]=packed(run.frame_workspace.metrics.output_build);
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
    Dictionary cap;cap["mode"]="oldest_high_absorber";cap["limit"]=s.pickup_config.gem_max;cap["absorber_id"]=p.gem_absorber_id?int64_t(p.gem_absorber_id):-1;
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
    if (initial) {
        Dictionary tuning;
        for (const auto &v:c.enemy_tuning) {const auto id=c.definitions[v.enemy-1].id;Dictionary values=tuning.get(id,Dictionary());values[String::utf8(v.key.c_str())]=v.value;tuning[id]=values;}
        out["enemy_tuning"]=tuning;
        Dictionary existing;existing["ground"]=existing_ground;existing["carried"]=existing_cargo;existing["cap"]=cap;out["existing"]=existing;
        Dictionary values,rewards;for (size_t i=0;i<3;++i) values[names[i]]=c.crystal_values[i];
        for (const auto &d:c.definitions) {Array counts;for (auto n:d.xp_rewards) counts.push_back(int64_t(n));Dictionary reward;reward["rank"]=d.rank;reward["counts"]=counts;reward["strong_gold"]=d.gold_eligible;rewards[d.id]=reward;}
        Dictionary config;config["xp_reward_version"]=2;config["xp_crystal_values"]=values;config["enemy_rewards"]=rewards;config["strong_gold_chance"]=s.pickup_config.strong_gold_chance;Dictionary limit=cap.duplicate();limit.erase("absorber_id");config["cap"]=limit;
        config["ship_multiplier"]=s.pickup_config.xp_mult;config["run_multiplier"]=s.loadout.xp_gain_mult;config["collection_multiplier"]=s.pickup_config.xp_mult*s.loadout.xp_gain_mult;config["multiplier_application"]="collection_once";
        config["xp_base"]=c.progression.xp_base;config["xp_growth"]=c.progression.xp_growth;config["xp_curve"]=c.progression.xp_curve;out["xp_config"]=config;
        PackedByteArray digest;digest.resize(32);std::copy(c.payload_sha256.begin(),c.payload_sha256.end(),digest.ptrw());Dictionary identity;identity["payload_sha256"]=digest.hex_encode();identity["abi_version"]=ABI_VERSION;identity["state_schema_version"]=STATE_SCHEMA_VERSION;identity["stage_id"]=s.control.stage_id;out["identity"]=identity;
    }
    return out;
}

}
