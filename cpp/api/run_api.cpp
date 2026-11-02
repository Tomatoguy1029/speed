#include "run_core.h"
#include "../behaviors/enemies/soldier.h"
#include "../systems/attack_system.h"
#include "../runtime/run_runner.h"
#include "../runtime/lifecycle.h"
#include "../output/event_builder.h"
#include "../output/render_builder.h"
#include "../systems/population_system.h"
#include "../systems/attack_budget.h"
#include "../systems/enemy_system.h"
#include "../systems/progression.h"
#include "../systems/pickup_system.h"
#include "../systems/equipment.h"
#include "../systems/combat_resolver.h"
#include "../systems/field.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>
#include <climits>
#include <algorithm>
#include <cstring>
using namespace godot;
namespace {
bool presentation_frozen(const speed::RunRuntime &run) {
    using Phase=RunState::Phase;const auto &s=run.state;const auto &c=s.control;
    return c.ui_overlay || c.ui_reward || s.phase==Phase::Paused || s.phase==Phase::LevelUp || (s.phase==Phase::Dying && s.sequence_t<s.death_freeze);
}
void advance_lance_display(speed::RunRuntime &run,double dt,double world_dt) {
    if (presentation_frozen(run)) return;
    auto &attacks=run.state.attacks;
    const double flight_dt=run.state.hitstop>0?0.0:dt;
    for (auto &v:attacks.lance_visuals) v.age+=flight_dt;
    for (auto &v:attacks.lance_effects) v.age+=world_dt;
    attacks.lance_visuals.erase(std::remove_if(attacks.lance_visuals.begin(),attacks.lance_visuals.end(),[](const auto &v){return v.age>=0.5;}),attacks.lance_visuals.end());
    attacks.lance_effects.erase(std::remove_if(attacks.lance_effects.begin(),attacks.lance_effects.end(),[](const auto &v){return v.age>=(v.hit?0.4:0.12);}),attacks.lance_effects.end());
}
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
    if (!keys(profile,{"reduce","mult"}) || (profile.has("reduce") && !is(profile,"reduce",Variant::DICTIONARY)) || (profile.has("mult") && !is(profile,"mult",Variant::DICTIONARY)) || !keys(settings,{"hitstop"}) || (settings.has("hitstop") && !is(settings,"hitstop",Variant::BOOL))) return failure(1,"profile/settings","未登録の設定項目があります");
    double charge_factor=1;
    if (profile.has("reduce")) {
        const Dictionary reduce=profile["reduce"];
        if (!keys(reduce,{"charge_time"})) return failure(1,"profile.reduce","未登録の永続強化です");
        if (reduce.has("charge_time")) {
            const Variant value=reduce["charge_time"];
            if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<=0) return failure(1,"profile.reduce.charge_time","充填倍率は有限の正数にしてください");
            charge_factor=value;
        }
    }
    double speed_factor=1;
    if (profile.has("mult")) {
        const Dictionary mult=profile["mult"];
        if (!keys(mult,{"max_speed","attack","pickup","length"})) return failure(1,"profile.mult","未登録の永続強化です");
        if (mult.has("max_speed")) {
            const Variant value=mult["max_speed"];
            if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<=0) return failure(1,"profile.mult.max_speed","速度倍率は有限の正数にしてください");
            speed_factor=value;
        }
    }
    double attack_factor=1;
    if (profile.has("mult")) {
        const Dictionary mult=profile["mult"];
        if (mult.has("attack")) {
            const Variant value=mult["attack"];
            if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<0) return failure(1,"profile.mult.attack","攻撃倍率は有限の非負数にしてください");
            attack_factor=value;
        }
    }
    double pickup_factor=1;
    if (profile.has("mult")) {
        const Dictionary mult=profile["mult"];
        if (mult.has("pickup")) {
            const Variant value=mult["pickup"];
            if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<0) return failure(1,"profile.mult.pickup","回収倍率は有限の非負数にしてください");
            pickup_factor=value;
        }
    }
    double length_factor=1;
    if (profile.has("mult")) {
        const Dictionary mult=profile["mult"];
        if (mult.has("length")) {
            const Variant value=mult["length"];
            if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<=0) return failure(1,"profile.mult.length","描線倍率は有限の正数にしてください");
            length_factor=value;
        }
    }
    if (bytes.size()<88 || std::memcmp(bytes.ptr(),"SPDRUN01",8)) return failure(1,"bundle","生成物の形式が不正です");
    if (bytes.decode_u32(8)!=speed::FORMAT_VERSION || bytes.decode_u32(12)!=speed::ABI_VERSION) return failure(2,"bundle","生成物の版が一致しません");
    Ref<SpeedRunCore> candidate;candidate.instantiate();
    if (!candidate->configure_content(bytes)) return failure(1,"bundle","生成物の版・参照・署名を確認してください");
    speed::apply_config(candidate->runtime.content->config,candidate->runtime.state);
    auto &state=candidate->runtime.state;const auto &s=state.ship_config;const auto &d=state.draw_config;const auto &c=state.control;
    if (s.max_hp<=0 || s.max_speed<=0 || s.base_max_speed<=0 || s.field_radius<=0 || d.length<=0 || d.run_time<=0 || d.capacity<=0 || d.charge_time<=0 || d.length_mult<=0 || d.scale_min>1 || c.base_view<=0 || c.zoom_ref_speed<=0 || c.zoom_min<=0 || c.zoom_min>1 || state.frame_grid_cell<=0 || candidate->runtime.content->config.character_scale<=0) return failure(1,"bundle.config","機体・描線・カメラの設定が不正です");
    candidate->runtime.api_run_id=options["run_id"];candidate->runtime.api_development=int64_t(options["mode"])==1;
    candidate->runtime.state.control.stage_id=String(options["stage_id"]);candidate->runtime.api_configured=true;
    const auto &forward=candidate->runtime.content->forward_levels.front();
    state.forward.base_interval=state.forward.interval=forward.interval;state.forward.fire.remaining=forward.interval;state.forward.damage=forward.damage;
    state.forward.life=forward.life;state.forward.spread=forward.spread;state.forward.knock=forward.knock;state.forward.pierce=forward.pierce;
    state.forward.character_scale=candidate->runtime.content->config.character_scale;state.forward.ready=true;
    state.hitstop_enabled=settings.get("hitstop",true);state.loadout.charge_profile_factor=charge_factor;state.loadout.speed_profile_factor=speed_factor;state.loadout.attack_profile_factor=attack_factor;state.loadout.pickup_profile_factor=pickup_factor;state.loadout.length_profile_factor=length_factor;
    const auto &lifecycle=candidate->runtime.content->lifecycle;
    state.lifecycle_ready=true;state.death_freeze=lifecycle.death_freeze_time;state.death_explosion=lifecycle.death_explosion_time;state.death_game_over=lifecycle.death_game_over_time;
    if (!candidate->runtime.content->budget_phases.empty()) {
        speed::AttackBudgetSystem::set_mode(state,true,true);
        speed::PopulationSystem::sync_attack_budget(candidate->runtime);
    }
    speed::PopulationSystem::prepare(candidate->runtime);
    runtime=std::move(candidate->runtime);
    PackedByteArray digest;digest.resize(32);std::copy(runtime.content->payload_sha256.begin(),runtime.content->payload_sha256.end(),digest.ptrw());
    Dictionary value;value["bundle_hash"]=digest.hex_encode();value["epoch"]=runtime.epoch;return success(value);
}
Dictionary SpeedRunCore::start_run(const Variant &seed,const Dictionary &options) {
    if (runtime.busy) return failure(7,"start","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.api_configured || runtime.state.started || runtime.state.closed) return failure(4,"start","設定済みの新しいランだけを開始できます");
    if (seed.get_type()!=Variant::INT || !keys(options,{"start_time","equipment","position","start_kind","scenario","endless"}) ||
        (options.has("endless") && !is(options,"endless",Variant::BOOL)) ||
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
    state.lifecycle.endless=options.get("endless",false);
    state.frame_ready=true;
    if (!start(int64_t(seed))) return failure(8,"start","ランを初期化できません");
    if (!rebuild_enemy_grid(state.frame_grid_cell)) return failure(8,"grid","検索索引を準備できません");
    speed::FieldSystem::initialize(runtime);
    speed::ProgressionSystem::initialize(runtime,options.has("equipment"));
    if (options.has("equipment")) speed::ProgressionSystem::open(*this,true);
    ++state.control.revision;return success(progress(runtime));
}
Dictionary SpeedRunCore::step_run(const Variant &delta,const Dictionary &data,const Dictionary &viewport) {
    if (runtime.busy) return failure(7,"step","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"step","開始していないランです");
    if (runtime.state.attacks.hostile_updating) return failure(7,"step","攻撃の個別更新中です");
    speed::InputFrame input;
    if (delta.get_type()!=Variant::FLOAT || double(delta)!=1.0/120.0 || !speed::decode_input(data,input) ||
        viewport.size()!=1 || !is(viewport,"logical_size",Variant::VECTOR2)) return failure(1,"input/viewport","固定更新の入力が不正です");
    const Vector2 size=viewport["logical_size"];
    if (!size.is_finite() || size.x<=0 || size.y<=0) return failure(1,"logical_size","論理サイズは有限の正数にしてください");
    if (runtime.state.control.tick==INT64_MAX || runtime.state.control.revision==INT64_MAX) return failure(9,"tick","更新番号が上限です");
    speed::MetricsTimer measured(runtime.frame_workspace.metrics.sim);
    speed::RenderBuilder::capture_previous(runtime);
    runtime.frame_workspace.publishing_tick=runtime.state.control.tick+1;
    const double previous_world_time=runtime.state.world_time;
    const bool advanced=speed::RunRunner::step_play(*this,1.0/120.0,input,size);
    speed::EventBuilder::flush_combat(runtime);
    runtime.frame_workspace.publishing_tick=-1;
    if (!advanced) return failure(8,"step","更新の整合を確認してください");
    advance_lance_display(runtime,1.0/120.0,std::max(0.0,runtime.state.world_time-previous_world_time));
    ++runtime.state.control.tick;++runtime.state.control.revision;
    if (runtime.frame_workspace.metrics.fixed_steps<INT64_MAX) ++runtime.frame_workspace.metrics.fixed_steps;
    return success(progress(runtime));
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
    } else if (kind=="choose_card" && payload.size()==2 && is(payload,"offer_id",Variant::INT) && is(payload,"candidate_id",Variant::INT)) {
        response=speed::ProgressionSystem::choose(runtime,payload["offer_id"],payload["candidate_id"])?success():failure(5,"offer_id/candidate_id","現在の候補と一致しません");
    } else if (kind=="reroll" && payload.size()==1 && is(payload,"offer_id",Variant::INT)) {
        response=speed::ProgressionSystem::reroll(*this,payload["offer_id"])?success():failure(4,"offer_id","引き直せません");
    } else if (kind=="cancel_choice" && payload.size()==1 && is(payload,"offer_id",Variant::INT)) {
        response=speed::ProgressionSystem::cancel(runtime,payload["offer_id"])?success():failure(5,"offer_id","選択中の候補と一致しません");
    } else if (kind=="resources_complete" && payload.size()==2 && is(payload,"request_id",Variant::INT) && is(payload,"status",Variant::INT) && (int64_t(payload["status"])==1 || int64_t(payload["status"])==-1 || int64_t(payload["status"])==-2)) {
        response=speed::ProgressionSystem::complete(runtime,payload["request_id"],payload["status"])?success():failure(5,"request_id/status","未処理の資源要求と一致しません");
    } else if (kind=="retry_resources" && payload.size()==1 && is(payload,"request_id",Variant::INT)) {
        response=speed::ProgressionSystem::retry(runtime,payload["request_id"])?success():failure(5,"request_id","再試行できる失敗要求がありません");
    } else if ((kind=="dev_grant_equipment" || kind=="dev_remove_weapon" || kind=="dev_remove_trait") && runtime.api_development && is(payload,"id",Variant::STRING)) {
        const String external=payload["id"];bool changed=false;
        for (const auto &d:runtime.content->equipment) if (external==String::utf8(d.external_id.c_str())) {
            if (kind=="dev_remove_weapon" && payload.size()==1) changed=speed::EquipmentSystem::remove_weapon(runtime,d.id);
            else if (kind=="dev_remove_trait" && payload.size()==1) changed=speed::EquipmentSystem::remove_trait(runtime,d.id);
            else if (kind=="dev_grant_equipment" && payload.size()==3 && is(payload,"kind",Variant::STRING) && is(payload,"levels",Variant::INT) &&
                String(payload["kind"])==(d.kind==0?"weapon":"trait") && int64_t(payload["levels"])>0 && int64_t(payload["levels"])<=UINT32_MAX)
                changed=speed::EquipmentSystem::grant(runtime,d.id,uint32_t(int64_t(payload["levels"])));
        }
        response=changed?success():failure(5,"equipment","装備を変更できません");
    } else if (kind=="dev_ship_defense" && runtime.api_development && payload.size()==2 && is(payload,"shield",Variant::FLOAT) && is(payload,"invulnerability",Variant::FLOAT) && std::isfinite(double(payload["shield"])) && std::isfinite(double(payload["invulnerability"])) && double(payload["shield"])>=0 && double(payload["invulnerability"])>=0) {
        runtime.state.ship.shield_t=payload["shield"];runtime.state.ship.invuln=payload["invulnerability"];response=success();
    } else if (kind=="dev_post_scatter" && runtime.api_development && payload.size()==4 && is(payload,"interval",Variant::INT) && is(payload,"projectile",Variant::INT) && is(payload,"duration",Variant::INT) && is(payload,"knockback",Variant::INT) && int64_t(payload["interval"])>=0 && int64_t(payload["projectile"])>=0 && int64_t(payload["duration"])>=0 && int64_t(payload["knockback"])>=0) {
        auto &p=runtime.state.loadout;p.post_weapon_interval_stacks=uint64_t(int64_t(payload["interval"]));p.post_projectile_speed_stacks=uint64_t(int64_t(payload["projectile"]));p.post_duration_stacks=uint64_t(int64_t(payload["duration"]));p.post_knockback_stacks=uint64_t(int64_t(payload["knockback"]));response=success();
    } else if (kind=="dev_post_length" && runtime.api_development && payload.size()==1 && is(payload,"stacks",Variant::INT) && int64_t(payload["stacks"])>=0) {
        runtime.state.loadout.post_line_length_stacks=uint64_t(int64_t(payload["stacks"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_post_pickup" && runtime.api_development && payload.size()==1 && is(payload,"stacks",Variant::INT) && int64_t(payload["stacks"])>=0) {
        runtime.state.loadout.post_xp_pickup_stacks=uint64_t(int64_t(payload["stacks"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_post_weapon_power" && runtime.api_development && payload.size()==2 && is(payload,"damage",Variant::INT) && is(payload,"followup",Variant::INT) && int64_t(payload["damage"])>=0 && int64_t(payload["followup"])>=0) {
        runtime.state.loadout.post_weapon_damage_stacks=uint64_t(int64_t(payload["damage"]));runtime.state.loadout.post_followup_stacks=uint64_t(int64_t(payload["followup"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_post_speed" && runtime.api_development && payload.size()==1 && is(payload,"stacks",Variant::INT) && int64_t(payload["stacks"])>=0) {
        runtime.state.loadout.post_max_speed_stacks=uint64_t(int64_t(payload["stacks"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_post_crit" && runtime.api_development && payload.size()==1 && is(payload,"stacks",Variant::INT) && int64_t(payload["stacks"])>=0) {
        runtime.state.loadout.post_crit_stacks=uint64_t(int64_t(payload["stacks"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_post_charge" && runtime.api_development && payload.size()==1 && is(payload,"stacks",Variant::INT) && int64_t(payload["stacks"])>=0) {
        runtime.state.loadout.post_charge_stacks=uint64_t(int64_t(payload["stacks"]));speed::EquipmentSystem::refresh_effects(runtime);response=success();
    } else if (kind=="dev_benchmark" && runtime.api_development && payload.size()==1 && is(payload,"leveling",Variant::BOOL)) {
        runtime.state.loadout.xp_gain_mult=bool(payload["leveling"])?1.0:0.0;response=success();
    } else if (kind=="dev_collect_gems" && runtime.api_development && payload.is_empty()) {
        response=success(speed::PickupSystem::collect_all(*this));
    } else if (kind=="dev_pickup_rates" && runtime.api_development && payload.size()==2 && is(payload,"ship",Variant::FLOAT) && is(payload,"run",Variant::FLOAT) && std::isfinite(double(payload["ship"])) && std::isfinite(double(payload["run"])) && double(payload["ship"])>=0 && double(payload["run"])>=0 && std::isfinite(double(payload["ship"])*double(payload["run"]))) {
        runtime.state.pickup_config.xp_mult=payload["ship"];runtime.state.loadout.xp_gain_mult=payload["run"];response=success();
    } else if (kind=="dev_spawn_pickup" && runtime.api_development && keys(payload,{"kind","position","weapon","drop"}) && is(payload,"kind",Variant::STRING) && is(payload,"position",Variant::VECTOR2) && Vector2(payload["position"]).is_finite() && (!payload.has("drop") || is(payload,"drop",Variant::BOOL)) && (!payload.has("weapon") || is(payload,"weapon",Variant::STRING))) {
        const String pickup=payload["kind"];speed::CapsuleState capsule;capsule.pos=payload["position"];capsule.drop=payload.get("drop",true);bool valid=true;
        if (pickup=="coin") runtime.state.pickups.coins.push_back({capsule.pos,true,false});
        else {
            if (pickup=="heal") capsule.kind=speed::CapsuleKind::Heal;
            else if (pickup=="magnet") capsule.kind=speed::CapsuleKind::Magnet;
            else if (pickup=="comet_weapon") {
                capsule.kind=speed::CapsuleKind::CometWeapon;
                const String id=payload.get("weapon",String());
                for (const auto &d:runtime.content->equipment) if (d.comet_only && id==String::utf8(d.external_id.c_str())) capsule.weapon=d.id;
                valid=capsule.weapon!=0;
            } else valid=false;
            if (valid) runtime.state.pickups.capsules.push_back(capsule);
        }
        response=valid?success():failure(1,"pickup","回収物の種類または武器が不正です");
    } else if (kind=="dev_carry_crystal" && runtime.api_development && payload.size()==2 && is(payload,"entity_id",Variant::INT) && is(payload,"crystal_id",Variant::INT)) {
        const auto found=runtime.state.rows_by_id.find(int64_t(payload["entity_id"]));bool carried=false;
        if (found!=runtime.state.rows_by_id.end()) for (size_t row=0;row<runtime.state.pickups.gems.size();++row) {
            if (runtime.state.pickups.gems[row].alive && runtime.state.pickups.gems[row].id==uint64_t(int64_t(payload["crystal_id"]))) {carried=speed::PickupSystem::carry(runtime,runtime.state.enemy_handles.at(uint32_t(found->second)),row);break;}
        }
        response=carried?success():failure(4,"crystal","運搬できる個体がありません");
    } else if (kind=="dev_retreat" && runtime.api_development && payload.size()==1 && is(payload,"entity_id",Variant::INT)) {
        const auto found=runtime.state.rows_by_id.find(int64_t(payload["entity_id"]));
        const bool removed=found!=runtime.state.rows_by_id.end() && speed::EnemySystem::retire(runtime,runtime.state.enemy_handles.at(uint32_t(found->second)),speed::RetireReason::Outside);
        response=removed?success():failure(4,"entity_id","退却できる敵がいません");
    } else if (kind=="dev_clear_cargo" && runtime.api_development && payload.is_empty()) {
        speed::PickupSystem::lose_all(runtime,speed::CargoLoss::Cleared);response=success();
    } else if (kind=="dev_drop_crystal" && runtime.api_development && payload.size()==2 && is(payload,"position",Variant::VECTOR2) && Vector2(payload["position"]).is_finite() && is(payload,"kind",Variant::INT) && int64_t(payload["kind"])>=0 && int64_t(payload["kind"])<=2) {
        const uint64_t crystal=speed::PickupSystem::supply(runtime,payload["position"],uint8_t(int64_t(payload["kind"])));
        response=crystal?success(int64_t(crystal)):failure(9,"crystal","結晶を供給できません");
    } else if (kind=="dev_add_xp" && runtime.api_development && payload.size()==1 && (is(payload,"amount",Variant::FLOAT) || is(payload,"amount",Variant::INT))) {
        response=speed::ProgressionSystem::add_experience(*this,payload["amount"])?success():failure(1,"amount","最終取得XPが不正です");
    } else if (kind=="abort" && payload.size()==1 && is(payload,"reason",Variant::INT)) {
        response=speed::Lifecycle::finish(runtime,speed::ResultKind::Abort)?success():failure(4,"result","結果は確定済みです");
    } else if (kind=="dev_finish" && runtime.api_development && payload.size()==1 && is(payload,"cleared",Variant::BOOL)) {
        response=speed::Lifecycle::finish(runtime,bool(payload["cleared"])?speed::ResultKind::Clear:speed::ResultKind::Death)?success():failure(4,"result","結果は確定済みです");
    } else if (kind=="dev_spawn" && runtime.api_development && payload.size()==2 && is(payload,"definition_id",Variant::STRING) && is(payload,"position",Variant::VECTOR2) && Vector2(payload["position"]).is_finite()) {
        auto entity=spawn_enemy(String(payload["definition_id"]),payload["position"],Dictionary());
        if (entity>0) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=entity>0?success(entity):failure(5,"definition_id","生成できる定義がありません");
    } else if (kind=="dev_soldier_formation" && runtime.api_development && payload.size()==6 && is(payload,"entity_id",Variant::INT) && is(payload,"king_id",Variant::INT) && is(payload,"slot",Variant::INT) && is(payload,"tier",Variant::INT) && is(payload,"anchor",Variant::VECTOR2) && is(payload,"values",Variant::PACKED_FLOAT64_ARRAY)) {
        const auto a=runtime.state.rows_by_id.find(int64_t(payload["entity_id"])),b=runtime.state.rows_by_id.find(int64_t(payload["king_id"]));const PackedFloat64Array values=payload["values"];bool ok=false;
        if (a!=runtime.state.rows_by_id.end() && b!=runtime.state.rows_by_id.end() && values.size()==5 && int64_t(payload["slot"])>=0 && int64_t(payload["tier"])>=1 && int64_t(payload["tier"])<=3) {
            speed::SoldierFormation f;f.anchor=payload["anchor"];f.spacing=values[0];f.row_near=values[1];f.row_far=values[2];f.fan_radius=values[3];f.fan_step=values[4];f.tier=int64_t(payload["tier"]);
            ok=speed::SoldierBehavior::configure(runtime,runtime.state.enemy_handles.at(a->second),runtime.state.enemy_handles.at(b->second),int64_t(payload["slot"]),f,true);
        }
        response=ok?success():failure(5,"soldier","兵と王と隊列の指定が無効です");
    } else if (kind=="dev_soldier_fire" && runtime.api_development && payload.size()==1 && is(payload,"entity_id",Variant::INT)) {
        const auto found=runtime.state.rows_by_id.find(int64_t(payload["entity_id"]));const auto attack=found==runtime.state.rows_by_id.end()?speed::AttackHandle():speed::SoldierBehavior::fire(runtime,runtime.state.enemy_handles.at(found->second));
        response=speed::AttackSystem::get(runtime.state,attack)?success():failure(5,"soldier","兵は射撃できる状態ではありません");
    } else if (kind=="dev_spawn_part" && runtime.api_development && payload.size()==3 && is(payload,"parent_id",Variant::INT) && is(payload,"definition_id",Variant::STRING) && is(payload,"position",Variant::VECTOR2)) {
        const auto parent=runtime.state.rows_by_id.find(int64_t(payload["parent_id"]));size_t definition=0;
        while (definition<runtime.content->definitions.size() && String(runtime.content->definitions[definition].id)!=String(payload["definition_id"])) ++definition;
        const int64_t id=parent==runtime.state.rows_by_id.end()?-1:speed::EnemySystem::spawn_part(runtime,runtime.state.enemy_handles.at(uint32_t(parent->second)),definition,payload["position"]);
        if (id>0) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=id>0?success(id):failure(5,"part","親または部位の定義が無効です");
    } else if (kind=="dev_move_part" && runtime.api_development && payload.size()==4 && is(payload,"parent_id",Variant::INT) && is(payload,"entity_id",Variant::INT) && is(payload,"position",Variant::VECTOR2) && is(payload,"facing",Variant::FLOAT)) {
        const auto parent=runtime.state.rows_by_id.find(int64_t(payload["parent_id"])),part=runtime.state.rows_by_id.find(int64_t(payload["entity_id"]));
        const bool moved=parent!=runtime.state.rows_by_id.end() && part!=runtime.state.rows_by_id.end() && speed::EnemySystem::move_part(runtime,runtime.state.enemy_handles.at(uint32_t(part->second)),runtime.state.enemy_handles.at(uint32_t(parent->second)),payload["position"],payload["facing"]);
        if (moved) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=moved?success():failure(5,"part","親子の参照が無効です");
    } else if (kind=="dev_relocate" && runtime.api_development && payload.size()==2 && is(payload,"entity_id",Variant::INT) && is(payload,"position",Variant::VECTOR2) && Vector2(payload["position"]).is_finite()) {
        const auto found=runtime.state.rows_by_id.find(int64_t(payload["entity_id"]));
        const bool moved=found!=runtime.state.rows_by_id.end() && speed::EnemySystem::relocate(runtime,runtime.state.enemy_handles.at(uint32_t(found->second)),payload["position"]);
        if (moved) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=moved?success():failure(5,"entity_id","再配置できる対象がありません");
    } else if (kind=="dev_remove" && runtime.api_development && payload.size()==1 && is(payload,"entity_id",Variant::INT)) {
        const bool removed=remove_enemy(int64_t(payload["entity_id"]));
        if (removed) rebuild_enemy_grid(runtime.state.frame_grid_cell);
        response=removed?success():failure(5,"entity_id","対象がありません");
    } else if (kind=="dev_damage" || kind=="dev_kill" || kind=="dev_ship_damage" || kind=="dev_enemy_combat") response=development_combat_command(kind,payload);
    else if (kind=="dev_friend_births" || kind=="dev_friend_reserve") response=development_friend_command(kind,payload);
    else if (kind=="dev_emit_attack" || kind=="dev_end_attack" || kind=="dev_attack_scope" || kind=="dev_clear_hostile" || kind=="dev_attack_update") response=development_attack_command(kind,payload);
    else if (kind=="dev_fire_light_arrow") response=development_light_arrow_command(payload);
    else if (kind=="dev_fire_star_bolt") response=development_star_bolt_command(payload);
    else if (kind=="dev_fire_ring_hold") response=development_ring_hold_command(payload);
    else if (kind=="dev_fire_lump") response=development_lump_command(payload);
    else if (kind=="dev_burst_debris" || kind=="dev_scatter_hull" || kind=="dev_fling_corpse" || kind=="dev_debris_on_death") response=development_debris_command(kind,payload);
    else if (kind=="dev_fire_light_lances" || kind=="dev_light_lances_state" || kind=="dev_tick_light_lances") response=development_lances_command(kind,payload);
    else if (kind=="dev_fire_shell") response=development_shell_command(payload);
    else if (kind=="dev_fire_zone") response=development_zone_command(payload);
    else if (kind=="dev_fire_hull" || kind=="dev_fire_saw") response=development_hull_command(kind,payload);
    else if (kind=="dev_fire_bolt") response=development_bolt_command(payload);
    else if (kind=="dev_fire_slash") response=development_slash_command(payload);
    else if (kind=="dev_fire_wall" || kind=="dev_move_wall") response=development_wall_command(kind,payload);
    else if (kind=="dev_fire_wave") response=development_wave_command(payload);
    else if (kind=="dev_fire_beam" || kind=="dev_move_beam" || kind=="dev_fire_cross" || kind=="dev_fire_flood") response=development_beam_command(kind,payload);
    else if (kind=="dev_fire_enemy" || kind=="dev_fire_missile" || kind=="dev_stone_hostiles") response=development_hostile_command(kind,payload);
    else if (kind=="dev_hound_order") response=development_hound_command(payload);
    else if (kind=="dev_defender_boost" || kind=="dev_defender_clear_boost" || kind=="dev_spawn_comet" || kind=="dev_comet_state" || kind=="dev_spawn_warp" || kind=="dev_set_warp" || kind=="dev_add_well" || kind=="dev_spawn_well" || kind=="dev_tick_gravity" || kind=="dev_field_query" || kind=="dev_field_collide" || kind=="dev_ship_motion" || kind=="dev_add_rock" || kind=="dev_stream_rocks") response=development_field_command(kind,payload);
    else if (kind=="dev_contact") response=development_contact_command(payload);
    else response=failure(1,"kind/payload","未登録の命令または引数です");
    speed::EventBuilder::flush_combat(runtime);
    if (bool(response["ok"])) {
        ++runtime.state.control.revision;
        if (runtime.frame_workspace.metrics.commands<INT64_MAX) ++runtime.frame_workspace.metrics.commands;
    }
    runtime.last_command_id=id;runtime.last_command_response=response.duplicate(true);return response;
}
Dictionary SpeedRunCore::render_run(const Rect2 &view,const Variant &alpha) const {
    if (runtime.busy) return failure(7,"read_render","更新中は再入できません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"read_render","開始していないランです");
    if (alpha.get_type()!=Variant::FLOAT || !std::isfinite(double(alpha)) || double(alpha)<0 || double(alpha)>1 ||
        !view.position.is_finite() || !view.size.is_finite() || view.size.x<0 || view.size.y<0) return failure(1,"view/alpha","表示範囲か補間係数が不正です");
    speed::MetricsTimer measured(runtime.frame_workspace.metrics.output_build);
    return success(speed::RenderBuilder::read(runtime,view,double(alpha)));
}
Dictionary SpeedRunCore::frame_run() {
    speed::MetricsTimer measured(runtime.frame_workspace.metrics.output_build);
    if (runtime.busy) return failure(7,"read_frame","更新中は再入できません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"read_frame","開始していないランです");
    if (runtime.frame_workspace.invalid) return failure(8,"events","通知の型・項目・番号が不正です");
    const auto &control=runtime.state.control;Dictionary camera;camera["center"]=control.camera_center;camera["zoom"]=control.camera_zoom;camera["half"]=runtime.state.view_half;
    Dictionary value=progress(runtime);value["run_id"]=runtime.api_run_id;value["camera"]=camera;
    Dictionary ui;ui["input_enabled"]=runtime.state.phase==Phase::Play && !control.ui_overlay && !control.ui_reward;ui["ship"]=ship_snapshot();ui["draw"]=draw_snapshot();ui["phase"]=int(runtime.state.phase);ui["hp"]=runtime.state.ship.hp;ui["coins"]=runtime.state.lifecycle.coins;ui["max_hp"]=runtime.state.ship_config.max_hp;
    const auto shield_source=runtime.state.ship.shield_source_definition;
    ui["ship_shield_visual"]=shield_source?runtime.content->definitions[shield_source-1].visual_id:0;
    ui["ship_radius"]=runtime.state.ship_config.ship_radius;
    ui["max_speed"]=runtime.state.ship_config.max_speed;ui["steer_cruise"]=runtime.state.ship_config.steer_cruise;
    ui["ship_vel"]=runtime.state.ship.vel;ui["tracing"]=runtime.state.draw.tracing;ui["ship_boost_t"]=runtime.state.ship.boost_t;ui["glide"]=runtime.state.ship.glide;
    ui["view_center"]=runtime.state.view_center;ui["view_half"]=runtime.state.view_half;ui["rare_comets"]=speed::FieldSystem::rare_comet_positions(runtime);ui["bonus_remaining"]=control.bonus_remaining;ui["run_time"]=runtime.state.time;ui["world_time"]=runtime.state.world_time;ui["kills"]=runtime.state.kills;
    Array voices;
    const auto &state=runtime.state;
    if (state.phase!=Phase::Finishing && state.phase!=Phase::Ended) for (size_t group=0;group<state.behavior_rows.size();++group) {
        if (state.behavior_kinds[group]!=speed::EnemyDefinition::Kind::Beamer && state.behavior_kinds[group]!=speed::EnemyDefinition::Kind::Sniper && state.behavior_kinds[group]!=speed::EnemyDefinition::Kind::Aquarius && state.behavior_kinds[group]!=speed::EnemyDefinition::Kind::Cross) continue;
        for (auto row:state.behavior_rows[group]) {
            const auto &enemy=state.enemies[row];if (enemy.dead || enemy.mode!=EnemyMode::Windup || (state.behavior_kinds[group]==speed::EnemyDefinition::Kind::Beamer && enemy.timer<=runtime.content->beamers[runtime.content->definitions[enemy.definition].beamer_definition-1].beam_time)) continue;
            if (state.behavior_kinds[group]==speed::EnemyDefinition::Kind::Aquarius && enemy.timer<=runtime.content->aquarius[runtime.content->definitions[enemy.definition].aquarius_definition-1].beam_time) continue;
            Dictionary voice;voice["id"]=enemy.id;voice["paused"]=state.phase!=Phase::Play || control.ui_overlay || control.ui_reward || state.hitstop>0 || enemy.stone>0 || enemy.held || enemy.shove_time>0 || enemy.knock_t>0;
            voices.push_back(voice);
        }
    }
    ui["laser_voices"]=voices;
    const auto &rampage=runtime.state.loadout.rampage;Dictionary aura;aura["equipped"]=rampage.ready;aura["kills"]=int64_t(rampage.kills);aura["strength"]=rampage.strength;aura["pop"]=rampage.pop;aura["bonus"]=rampage.bonus;aura["target_kills"]=rampage.target_kills;aura["half_life"]=rampage.half_life;aura["multiplier"]=runtime.state.loadout.effects.damage_multiplier;ui["rampage"]=aura;
    ui["rear"]=rear_snapshot();
    ui["barrier"]=barrier_snapshot();
    Dictionary gear;gear["distance"]=runtime.state.loadout.boost_distance;gear["maximum"]=runtime.state.loadout.full_charge_maximum;gear["burst_power"]=runtime.state.loadout.effects.burst_power;gear["ignore_armor"]=runtime.state.loadout.effects.ignore_armor;ui["full_charge"]=gear;ui["base_draw_length"]=runtime.state.draw_config.length;
    ui["world_scale"]=runtime.state.control.world_scale;ui["hitstop"]=runtime.state.hitstop;ui["base_max_speed"]=runtime.state.ship_config.base_max_speed;
    ui["presentation_frozen"]=presentation_frozen(runtime);
    ui["death_dim"]=runtime.state.phase==Phase::Dying?runtime.content->lifecycle.death_world_dim:0.0;
    ui["shot_multiplier"]=runtime.state.loadout.effects.shot_amount;
    ui["area_multiplier"]=runtime.state.loadout.effects.area;ui["trace_radius"]=runtime.state.trace_radius;
    ui["glide_duration_mult"]=runtime.state.ship_config.glide_duration_mult;
    ui["length_mult"]=runtime.state.draw_config.length_mult;
    ui["pickup_radius"]=runtime.state.pickup_config.coin_radius;ui["xp_pickup_radius"]=runtime.state.pickup_config.xp_radius;
    ui["attack_mult"]=runtime.state.combat_config.attack_mult;ui["attack_power"]=speed::CombatResolver::attack_power(runtime);
    ui["crit_chance"]=runtime.state.combat_config.crit_chance;ui["crit_mult"]=runtime.state.combat_config.crit_mult;
    Dictionary crit_beam;const auto &c=runtime.state.loadout.crit_beam;crit_beam["ready"]=c.ready;crit_beam["next_time"]=c.next_time;crit_beam["cooldown"]=c.cooldown;ui["crit_beam"]=crit_beam;
    Array lance_visuals,lance_effects;
    for (const auto &v:runtime.state.attacks.lance_visuals) {Dictionary item;item["id"]=int64_t(v.id);item["from"]=v.from;item["to"]=v.to;item["width"]=v.width;item["age"]=v.age;lance_visuals.push_back(item);}
    for (const auto &v:runtime.state.attacks.lance_effects) {Dictionary item;item["id"]=int64_t(v.id);item["hit"]=v.hit;item["pos"]=v.pos;item["direction"]=v.direction;item["radius"]=v.radius;item["age"]=v.age;lance_effects.push_back(item);}ui["light_lances"]=lance_visuals;ui["lance_effects"]=lance_effects;
    Dictionary vortex;const auto &vortex_state=runtime.state.loadout.vortex;vortex["ready"]=vortex_state.ready;vortex["charge"]=vortex_state.charge;vortex["hold"]=vortex_state.hold;vortex["collapse"]=vortex_state.collapse;vortex["required"]=vortex_state.kills;Array vortex_items,vortex_visuals;
    for (const auto &v:vortex_state.items) {Dictionary item;item["id"]=int64_t(v.id);item["pos"]=v.pos;item["age"]=v.age;item["radius"]=v.radius;item["damage"]=v.damage;item["kills"]=int64_t(v.kills);item["duration"]=v.duration;vortex_items.push_back(item);}
    for (const auto &v:vortex_state.visuals) {Dictionary item;item["id"]=int64_t(v.id);item["kind"]=v.kind;item["pos"]=v.pos;item["radius"]=v.radius;item["age"]=v.age;item["color"]=v.color;item["facing"]=v.facing;item["amount"]=v.amount;item["enemy_type"]=v.definition?runtime.content->definitions[v.definition-1].id:godot::StringName();vortex_visuals.push_back(item);}vortex["items"]=vortex_items;vortex["visuals"]=vortex_visuals;ui["vortex"]=vortex;
    Dictionary mines;const auto &mine_state=runtime.state.loadout.mines;mines["ready"]=mine_state.ready;mines["chain"]=mine_state.chain;Array mine_items,mine_visuals;
    for (const auto &m:mine_state.items) {Dictionary item;item["id"]=int64_t(m.id);item["pos"]=m.pos;item["from"]=m.from;item["to"]=m.to;item["age"]=m.age;item["life"]=m.life;item["damage"]=m.damage;item["radius"]=m.radius;item["detonate"]=m.detonate;mine_items.push_back(item);}
    for (const auto &v:mine_state.visuals) {Dictionary item;item["id"]=int64_t(v.id);item["pos"]=v.pos;item["radius"]=v.radius;item["age"]=v.age;mine_visuals.push_back(item);}mines["items"]=mine_items;mines["visuals"]=mine_visuals;ui["mines"]=mines;
    Dictionary run_up;const auto &ru=runtime.state.loadout.run_up;run_up["ready"]=ru.ready;run_up["first"]=ru.first;run_up["strength"]=ru.strength;run_up["distance"]=ru.distance;run_up["maximum"]=ru.multiplier;Array run_up_hits;for (const auto &h:ru.hits) {Dictionary item;item["id"]=int64_t(h.id);item["pos"]=h.pos;item["dir"]=h.direction;item["age"]=h.age;run_up_hits.push_back(item);}run_up["hits"]=run_up_hits;ui["run_up"]=run_up;
    Dictionary end_blast;const auto &blast=runtime.state.loadout.end_blast;end_blast["ready"]=blast.ready;end_blast["radius"]=blast.radius*runtime.state.loadout.effects.area;end_blast["secondary"]=blast.secondary;
    Array pending_blasts,blast_visuals;for (const auto &p:blast.pending) {Dictionary item;item["pos"]=p.pos;item["radius"]=p.radius;item["damage"]=p.damage;item["delay"]=p.delay;pending_blasts.push_back(item);}
    for (const auto &v:blast.visuals) {Dictionary item;item["id"]=int64_t(v.id);item["pos"]=v.pos;item["radius"]=v.radius;item["age"]=v.age;blast_visuals.push_back(item);}end_blast["pending"]=pending_blasts;end_blast["visuals"]=blast_visuals;ui["end_blast"]=end_blast;
    ui["capacity"]=runtime.state.draw_config.capacity;ui["charge_time"]=runtime.state.draw_config.charge_time;ui["min_charge"]=runtime.state.draw_config.min_charge;ui["full_burst"]=runtime.state.loadout.full_burst_owned;ui["full_burst_active"]=runtime.state.loadout.full_burst_active;ui["shooting_rate"]=runtime.state.draw.gauge<1.0?1.0:1.0+runtime.state.loadout.effects.full_gauge_rate*runtime.state.draw.gauge;
    ui["character_scale"]=runtime.content->config.character_scale;ui.merge(speed::ProgressionSystem::ui(runtime),true);value["ui"]=speed::FrameBuilder::ui_delta(runtime,ui);
    value["events"]=speed::FrameBuilder::events(runtime);value["resource_requests"]=speed::ProgressionSystem::requests(runtime);value["result"]=speed::Lifecycle::result(runtime);return success(value);
}
Dictionary SpeedRunCore::ack_frame_run(int64_t epoch,int64_t sequence) {
    if (runtime.busy) return failure(7,"ack_frame","更新中は受領できません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"ack_frame","開始していないランです");
    const int error=speed::FrameBuilder::acknowledge(runtime,epoch,sequence);
    return error?failure(error,"epoch/sequence","古い世代・受領済み・未公開の通知番号です"):success();
}
Dictionary SpeedRunCore::metrics_run() const {
    if (runtime.busy) return failure(7,"read_metrics","更新中は読めません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"read_metrics","開始していないランです");
    return success(speed::MetricsBuilder::read(runtime));
}
Dictionary SpeedRunCore::recording_run(bool initial) const {
    if (runtime.busy) return failure(7,"recording","更新中は読めません");
    if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return failure(4,"recording","開始していないランです");
    return success(speed::MetricsBuilder::recording(runtime,initial));
}
Dictionary SpeedRunCore::dispose_run() {
    if (runtime.busy) return failure(7,"dispose","更新中は再入できません");Guard guard(runtime.busy);
    if (!runtime.state.closed) {close();if (runtime.epoch<INT64_MAX) ++runtime.epoch;}
    runtime.resource_workspace.requests.clear();runtime.state.loadout={};
    runtime.last_command_response.clear();return success();
}
