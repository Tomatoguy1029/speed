#include "lifecycle.h"
#include "../behaviors/weapons/afterimage.h"
#include "../output/frame_builder.h"
#include "../output/event_builder.h"
#include "../state/loadout_state.h"
#include "../content/content_bundle.h"
#include <climits>
using namespace godot;
namespace speed {
namespace {
int64_t next_result_id=1;
String equipment_id(const RunRuntime &run,uint32_t id) {for (const auto &d:run.content->equipment) if (d.id==id) return String::utf8(d.external_id.c_str());return "";}
Array levels(const RunRuntime &run,const std::vector<EquipmentLevel> &items) {Array out;for (const auto &e:items) {Dictionary v;v["id"]=equipment_id(run,e.definition);v["level"]=e.level;out.append(v);}return out;}
}
bool Lifecycle::finish(RunRuntime &run,ResultKind kind) {
    auto &state=run.state;auto &lifecycle=state.lifecycle;
    if (lifecycle.result || next_result_id==INT64_MAX) return false;
    RunResult result;result.id=next_result_id++;result.kind=kind;result.run_time=state.time;result.world_time=state.world_time;
    result.level=state.loadout->level;result.kills=state.kills;result.coins=lifecycle.coins+(kind==ResultKind::Clear?run.content->lifecycle.clear_bonus:0);
    result.peak_speed=state.ship.peak_speed;result.weapons=state.loadout->weapons;result.traits=state.loadout->traits;
    for (auto id:lifecycle.obtained) result.rewards.push_back({id,1});
    result.last_request=lifecycle.last_request;result.last_damage=lifecycle.last_damage;result.has_damage=lifecycle.has_damage;
    lifecycle.result=std::move(result);
    state.draw.drawing=state.draw.tracing=false;state.ship.vel=Vector2();state.phase=RunState::Phase::Ended;AfterimageBehavior::clear(run);state.hitstop=0;
    state.control.boss_ram={};
    state.control.world_real_accum=state.control.world_dt_accum=0;state.control.world_steps=0;
    state.loadout->candidates.clear();state.loadout->offer_id=state.loadout->selected_id=0;run.resource_workspace.requests.clear();
    Dictionary event;event["result_id"]=lifecycle.result->id;event["kind"]=symbol_name(kind);FrameBuilder::append(run,"run_finished",event);return true;
}
Variant Lifecycle::result(const RunRuntime &run) {
    if (!run.state.lifecycle.result) return Variant();
    const auto &r=*run.state.lifecycle.result;Dictionary out;out["result_id"]=r.id;out["kind"]=symbol_name(r.kind);out["stage_id"]=String(run.state.control.stage_id);
    out["run_time"]=r.run_time;out["world_time"]=r.world_time;out["level"]=r.level;out["kills"]=r.kills;out["coins"]=r.coins;out["peak_speed"]=r.peak_speed;out["endless"]=run.state.lifecycle.endless;
    out["legendary"]=r.kind==ResultKind::Clear?String::utf8(run.content->lifecycle.legendary.c_str()):String();
    out["weapons"]=levels(run,r.weapons);out["traits"]=levels(run,r.traits);Array rewards;
    for (const auto &r:r.rewards) {Dictionary v;v["id"]=equipment_id(run,r.equipment);v["amount"]=r.amount;rewards.append(v);}out["rewards"]=rewards;
    Dictionary damage;
    if (r.has_damage) {damage=EventBuilder::ship_result(r.last_damage);damage["cause"]=symbol_name(r.last_request.cause);damage["source"]=r.last_request.source;damage["technique"]=r.last_request.technique;}
    out["last_damage"]=damage;return out;
}
}
