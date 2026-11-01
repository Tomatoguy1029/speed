#include "run_core.h"
#include "../runtime/run_runner.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <climits>
#include <algorithm>
#include <cstring>
using namespace godot;
namespace {
Dictionary success(Variant value=Variant()) {Dictionary out;out["ok"]=true;out["code"]=0;out["message"]="";out["field"]="";out["value"]=value;return out;}
Dictionary failure(int code,const char *field,const char *message) {Dictionary out;out["ok"]=false;out["code"]=code;out["field"]=field;out["message"]=message;out["value"]=Variant();return out;}
bool keys(const Dictionary &data,std::initializer_list<const char *> allowed) {
    auto names=data.keys();
    for (int64_t i=0;i<names.size();++i) {
        if (names[i].get_type()!=Variant::STRING && names[i].get_type()!=Variant::STRING_NAME) return false;
        bool found=false;for (auto key:allowed) if (String(names[i])==key) {found=true;break;}
        if (!found) return false;
    }return true;
}
bool is(const Dictionary &data,const char *key,Variant::Type type) {return data.has(key) && data[key].get_type()==type;}
struct Guard {bool &busy;explicit Guard(bool &value):busy(value){busy=true;}~Guard(){busy=false;}};
Dictionary progress(const speed::RunRuntime &run) {Dictionary value;value["epoch"]=run.epoch;value["tick"]=run.state.control.tick;value["state_revision"]=run.state.control.revision;return value;}
}
Dictionary SpeedRunCore::configure_run(const PackedByteArray &bytes,const Dictionary &options) {
    if (runtime.busy) return failure(7,"configure","更新中は再入できません");Guard guard(runtime.busy);
    if (runtime.api_configured || runtime.state.started || runtime.state.closed) return failure(4,"configure","開始前の新しいランに設定してください");
    if (!keys(options,{"api_version","run_id","mode","stage_id","profile","settings"}) ||
        !is(options,"api_version",Variant::INT) || !is(options,"run_id",Variant::INT) || !is(options,"mode",Variant::INT) ||
        !is(options,"stage_id",Variant::STRING) || !is(options,"profile",Variant::DICTIONARY) || !is(options,"settings",Variant::DICTIONARY)) return failure(1,"options","設定の型または項目が不正です");
    if (int64_t(options["api_version"])!=1) return failure(2,"api_version","APIの版が一致しません");
    if (int64_t(options["run_id"])<=0 || int64_t(options["mode"])<0 || int64_t(options["mode"])>1 || String(options["stage_id"]).is_empty()) return failure(1,"options","ラン番号・モード・ステージが不正です");
    const Dictionary profile=options["profile"],settings=options["settings"];
    if (!profile.is_empty() || !keys(settings,{"hitstop"}) || (settings.has("hitstop") && !is(settings,"hitstop",Variant::BOOL))) return failure(1,"profile/settings","未登録の設定項目があります");
    if (bytes.size()<88 || std::memcmp(bytes.ptr(),"SPDRUN01",8)) return failure(1,"bundle","生成物の形式が不正です");
    if (bytes.decode_u32(8)!=speed::FORMAT_VERSION || bytes.decode_u32(12)!=speed::ABI_VERSION) return failure(2,"bundle","生成物の版が一致しません");
    Ref<SpeedRunCore> candidate;candidate.instantiate();
    if (!candidate->configure_content(bytes)) return failure(1,"bundle","生成物の版・参照・署名を確認してください");
    speed::apply_config(candidate->runtime.content->config,candidate->runtime.state);
    auto &state=candidate->runtime.state;const auto &s=state.ship_config;const auto &d=state.draw_config;const auto &c=state.control;
    if (s.max_hp<=0 || s.max_speed<=0 || s.base_max_speed<=0 || s.field_radius<=0 || d.length<=0 || d.run_time<=0 || d.capacity<=0 || d.charge_time<=0 || d.length_mult<=0 || d.scale_min>1 || c.base_view<=0 || c.zoom_ref_speed<=0 || c.zoom_min<=0 || c.zoom_min>1 || state.frame_grid_cell<=0) return failure(1,"bundle.config","機体・描線・カメラの設定が不正です");
    candidate->runtime.api_run_id=options["run_id"];candidate->runtime.api_development=int64_t(options["mode"])==1;
    candidate->runtime.state.control.stage_id=String(options["stage_id"]);candidate->runtime.api_configured=true;
    state.hitstop_enabled=settings.get("hitstop",true);
    runtime=std::move(candidate->runtime);
    PackedByteArray digest;digest.resize(32);std::copy(runtime.content->payload_sha256.begin(),runtime.content->payload_sha256.end(),digest.ptrw());
    Dictionary value;value["bundle_hash"]=digest.hex_encode();value["epoch"]=runtime.epoch;return success(value);
}
Dictionary SpeedRunCore::start_run(const Variant &seed,const Dictionary &options) {
    if (runtime.busy) return failure(7,"start","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.api_configured || runtime.state.started || runtime.state.closed) return failure(4,"start","設定済みの新しいランだけを開始できます");
    if (seed.get_type()!=Variant::INT || !keys(options,{"start_time","equipment","position","start_kind","scenario"}) ||
        (options.has("position") && (!is(options,"position",Variant::VECTOR2) || !Vector2(options["position"]).is_finite()))) return failure(1,"start","開始入力が不正です");
    const Variant time=options.get("start_time",0.0);
    if ((time.get_type()!=Variant::FLOAT && time.get_type()!=Variant::INT) || !std::isfinite(double(time)) || double(time)!=0 ||
        (options.has("equipment") && (!is(options,"equipment",Variant::ARRAY) || !Array(options["equipment"]).is_empty())) ||
        (options.has("start_kind") && (!is(options,"start_kind",Variant::STRING) || String(options["start_kind"])!="normal")) ||
        (options.has("scenario") && (!is(options,"scenario",Variant::DICTIONARY) || !Dictionary(options["scenario"]).is_empty()))) return failure(1,"start","未登録の途中開始・装備・試行入力です");
    auto &state=runtime.state;state.ship={};state.draw={};
    state.ship.pos=options.get("position",Vector2(-state.ship_config.start_radius,0));state.ship_pos=state.ship.pos;
    state.ship.vel=Vector2(0,-state.ship_config.base_max_speed*0.3);state.ship.hp=state.ship_config.max_hp;
    state.ship_ready=state.draw_ready=true;
    if (!start(int64_t(seed))) return failure(8,"start","ランを初期化できません");
    if (!rebuild_enemy_grid(state.frame_grid_cell)) return failure(8,"grid","検索索引を準備できません");
    ++state.control.revision;return success(progress(runtime));
}
Dictionary SpeedRunCore::step_run(const Variant &delta,const Dictionary &data,const Dictionary &viewport) {
    if (runtime.busy) return failure(7,"step","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"step","開始していないランです");
    speed::InputFrame input;
    if (delta.get_type()!=Variant::FLOAT || double(delta)!=1.0/120.0 || !speed::decode_input(data,input) ||
        viewport.size()!=1 || !is(viewport,"logical_size",Variant::VECTOR2)) return failure(1,"input/viewport","固定更新の入力が不正です");
    const Vector2 size=viewport["logical_size"];
    if (!size.is_finite() || size.x<=0 || size.y<=0) return failure(1,"logical_size","論理サイズは有限の正数にしてください");
    if (runtime.state.control.tick==INT64_MAX || runtime.state.control.revision==INT64_MAX) return failure(9,"tick","更新番号が上限です");
    if (!speed::RunRunner::step_play(*this,1.0/120.0,input,size)) return failure(8,"step","更新の整合を確認してください");
    ++runtime.state.control.tick;++runtime.state.control.revision;return success(progress(runtime));
}
Dictionary SpeedRunCore::command_run(const Dictionary &envelope) {
    if (runtime.busy) return failure(7,"command","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"command","開始していないランです");
    if (!keys(envelope,{"run_id","epoch","command_id","kind","payload"}) || envelope.size()!=5 ||
        !is(envelope,"run_id",Variant::INT) || !is(envelope,"epoch",Variant::INT) || !is(envelope,"command_id",Variant::INT) ||
        !is(envelope,"kind",Variant::STRING) || !is(envelope,"payload",Variant::DICTIONARY)) return failure(1,"command","命令の形式が不正です");
    if (int64_t(envelope["run_id"])!=runtime.api_run_id || int64_t(envelope["epoch"])!=runtime.epoch) return failure(3,"run_id/epoch","古いランまたは世代です");
    const int64_t id=envelope["command_id"];
    if (id<=0 || id<runtime.last_command_id) return failure(3,"command_id","古い命令番号です");
    if (id==runtime.last_command_id) return runtime.last_command_response.duplicate(true);
    const String kind=envelope["kind"];const Dictionary payload=envelope["payload"];Dictionary response;
    if (runtime.state.control.revision==INT64_MAX) return failure(9,"state_revision","状態番号が上限です");
    if (kind=="pause" && payload.size()==1 && is(payload,"paused",Variant::BOOL)) {
        if (runtime.state.phase==Phase::Ended) response=failure(4,"phase","終了したランは停止できません");
        else {
            if (bool(payload["paused"]) && runtime.state.phase!=Phase::Paused) {runtime.state.control.resume_phase=int32_t(runtime.state.phase);runtime.state.phase=Phase::Paused;runtime.state.hitstop=0;}
            else if (!bool(payload["paused"]) && runtime.state.phase==Phase::Paused) runtime.state.phase=Phase(runtime.state.control.resume_phase);
            response=success();
        }
    } else if ((kind=="set_ui_overlay" || kind=="set_ui_reward") && payload.size()==1 && is(payload,"active",Variant::BOOL)) {
        if (kind=="set_ui_overlay") runtime.state.control.ui_overlay=payload["active"];
        else runtime.state.control.ui_reward=payload["active"];
        response=success();
    } else if (kind=="set_settings" && payload.size()==1 && is(payload,"hitstop",Variant::BOOL)) {
        runtime.state.hitstop_enabled=payload["hitstop"];if (!runtime.state.hitstop_enabled) runtime.state.hitstop=0;response=success();
    } else if (kind=="dev_spawn" && runtime.api_development && payload.size()==2 && is(payload,"definition_id",Variant::STRING) && is(payload,"position",Variant::VECTOR2) && Vector2(payload["position"]).is_finite()) {
        auto entity=spawn_enemy(String(payload["definition_id"]),payload["position"],Dictionary());
        if (entity>0) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=entity>0?success(entity):failure(5,"definition_id","生成できる定義がありません");
    } else if (kind=="dev_remove" && runtime.api_development && payload.size()==1 && is(payload,"entity_id",Variant::INT)) {
        const bool removed=remove_enemy(int64_t(payload["entity_id"]));
        if (removed) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=removed?success():failure(5,"entity_id","対象がありません");
    } else response=failure(1,"kind/payload","未登録の命令または引数です");
    if (bool(response["ok"])) ++runtime.state.control.revision;
    runtime.last_command_id=id;runtime.last_command_response=response.duplicate(true);return response;
}
Dictionary SpeedRunCore::frame_run() const {
    if (runtime.busy) return failure(7,"read_frame","更新中は再入できません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"read_frame","開始していないランです");
    const auto &control=runtime.state.control;Dictionary camera;camera["center"]=control.camera_center;camera["zoom"]=control.camera_zoom;camera["half"]=runtime.state.view_half;
    Dictionary value=progress(runtime);value["run_id"]=runtime.api_run_id;value["camera"]=camera;
    Dictionary ui;ui["input_enabled"]=runtime.state.phase==Phase::Play && !control.ui_overlay && !control.ui_reward;ui["ship"]=ship_snapshot();ui["draw"]=draw_snapshot();value["ui"]=ui;
    value["events"]=runtime.state.events.duplicate(true);value["resource_requests"]=Array();value["result"]=Variant();return success(value);
}
Dictionary SpeedRunCore::dispose_run() {
    if (runtime.busy) return failure(7,"dispose","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.state.closed) {close();if (runtime.epoch<INT64_MAX) ++runtime.epoch;}
    runtime.last_command_response.clear();return success();
}
