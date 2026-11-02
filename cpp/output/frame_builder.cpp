#include "frame_builder.h"
#include "../runtime/run_runtime.h"
#include <climits>
#include <cmath>
using namespace godot;
namespace speed {
namespace {
bool value_only(const Variant &value,unsigned depth=0) {
    if (depth>32) return false;
    switch(value.get_type()) {
    case Variant::OBJECT:case Variant::CALLABLE:case Variant::SIGNAL:return false;
    case Variant::FLOAT:return std::isfinite(double(value));
    case Variant::VECTOR2:return Vector2(value).is_finite();
    case Variant::DICTIONARY: {
        Dictionary data=value;auto keys=data.keys();
        for (int64_t i=0;i<keys.size();++i) if (!value_only(keys[i],depth+1) || !value_only(data[keys[i]],depth+1)) return false;
        return true;
    }
    case Variant::ARRAY: {
        Array data=value;for (int64_t i=0;i<data.size();++i) if (!value_only(data[i],depth+1)) return false;
        return true;
    }
    default:return true;
    }
}
void count(int64_t &value) {if (value<INT64_MAX) ++value;}
}
void FrameBuilder::append(RunRuntime &run,StringName type,const Dictionary &data) {
    if (!run.api_configured) {auto legacy=data.duplicate(true);legacy["type"]=type;run.state.events.append(legacy);return;}
    auto &out=run.frame_workspace;EventType kind;
    if (out.invalid) return;
    if (!parse_symbol(String(type).utf8().get_data(),kind) || out.next_sequence==INT64_MAX || !value_only(data)) {out.invalid=true;return;}
    auto payload=data.duplicate(true);auto names=payload.keys();
    for (int64_t i=0;i<names.size();++i) {
        const String key=names[i];
        if (key=="t" || key=="world_t") continue;
        if (!event_field_allowed(kind,key.utf8().get_data())) {out.invalid=true;return;}
    }
    Notification event;event.type=kind;event.sequence=out.next_sequence++;
    event.tick=out.publishing_tick>=0?out.publishing_tick:run.state.control.tick;
    event.time=data.get("t",run.state.time);event.world_time=data.get("world_t",run.state.world_time);
    payload.erase("t");payload.erase("world_t");event.payload=payload;
    out.pending.push_back(std::move(event));count(out.metrics.events_emitted);
}
Array FrameBuilder::events(RunRuntime &run) {
    Array events;auto &out=run.frame_workspace;
    for (const auto &event:out.pending) {
        Dictionary row;row["epoch"]=run.epoch;row["sequence"]=event.sequence;row["tick"]=event.tick;
        row["t"]=event.time;row["world_t"]=event.world_time;row["type"]=StringName(symbol_name(event.type));row["payload"]=event.payload.duplicate(true);
        events.append(row);
    }
    if (!out.pending.empty()) out.exposed=out.pending.back().sequence;
    return events;
}
int FrameBuilder::acknowledge(RunRuntime &run,int64_t epoch,int64_t sequence) {
    auto &out=run.frame_workspace;
    if (epoch!=run.epoch || sequence<=out.acked) return 3;
    if (sequence<=0 || sequence>out.exposed) return 1;
    while (!out.pending.empty() && out.pending.front().sequence<=sequence) {out.pending.pop_front();count(out.metrics.events_acked);}
    out.acked=sequence;return 0;
}
Dictionary FrameBuilder::ui_delta(RunRuntime &run,const Dictionary &ui) {
    auto &out=run.frame_workspace;
    if (out.ui_revision!=run.state.control.revision) {
        Dictionary delta;auto names=ui.keys();
        for (int64_t i=0;i<names.size();++i) if (!out.previous_ui.has(names[i]) || Variant(out.previous_ui[names[i]])!=Variant(ui[names[i]])) delta[names[i]]=ui[names[i]];
        out.previous_ui=ui.duplicate(true);out.ui_delta=delta.duplicate(true);out.ui_revision=run.state.control.revision;
    }
    return out.ui_delta.duplicate(true);
}
Dictionary FrameBuilder::metrics(const RunRuntime &run) {
    const auto &m=run.frame_workspace.metrics;Dictionary out;
    out["schema_version"]=1;out["run_id"]=run.api_run_id;out["epoch"]=run.epoch;out["tick"]=run.state.control.tick;
    out["fixed_steps"]=m.fixed_steps;out["commands"]=m.commands;out["events_emitted"]=m.events_emitted;out["events_acked"]=m.events_acked;
    out["pending_events"]=int64_t(run.frame_workspace.pending.size());out["enemies"]=int64_t(run.state.rows_by_id.size());
    out["friendly_shots"]=int64_t(run.state.live_friends);
    std::vector<int64_t> counts(run.content->definitions.size(),0);
    for (const auto &rows:run.state.behavior_rows) for (auto row:rows) ++counts[run.state.enemies[row].definition];
    Dictionary types,pools;
    for (size_t i=0;i<counts.size();++i) if (counts[i]) {const auto name=run.content->definitions[i].source_id();types[name]=int64_t(types.get(name,int64_t(0)))+counts[i];}
    int64_t attacks[3]={};
    for (const auto &attack:run.state.attacks.records) if (attack.alive) ++attacks[int(attack.pool)];
    for (int i=0;i<3;++i) pools[String::num_int64(i)]=attacks[i];
    out["enemy_types"]=types;out["attack_pools"]=pools;return out;
}
}
