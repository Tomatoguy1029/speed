#include "run_core.h"
#include "../bosses/flow/technique_runner.h"
#include "../bosses/flow/flow_runner.h"
#include "../bosses/flow/phase_controller.h"
#include "../bosses/monoceros/body.h"
#include "../bosses/centaurus/body.h"
#include "../bosses/canis_major/body.h"
#include "../bosses/canis_major/flames.h"
#include "../bosses/canis_major/hound_lunge.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_boss_command(const String &kind,const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()){Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"boss";out["message"]=ok?"":"ボス技の命令が不正です";out["value"]=value;return out;};
    if (!runtime.api_development) return result(false);
    if (kind=="dev_canis_lunge" || kind=="dev_cancel_canis_lunge") {
        if (p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("action",Variant()).get_type()!=Variant::INT || int64_t(p["action"])<=0) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));if (found==runtime.state.rows_by_id.end()) return result(false);auto *body=speed::PhaseController::find(runtime,runtime.state.enemy_handles.at(found->second));if (!body || runtime.content->bosses[runtime.content->boss_bodies[body->definition-1].boss-1].kind!=2 || body->mode>=speed::BossMode::Defeated) return result(false);
        if (kind=="dev_cancel_canis_lunge") {if (p.size()!=2) return result(false);speed::CanisHoundLunge::end_action(runtime,*body,p["action"],true);return result(true);}
        if (p.size()!=11 || p.get("target",Variant()).get_type()!=Variant::INT) return result(false);const auto target=runtime.state.rows_by_id.find(int64_t(p["target"]));if (target==runtime.state.rows_by_id.end()) return result(false);
        speed::HoundLungeSettings settings;for (const char *key:{"speed","duration","damage"}) {const auto x=p.get(key,Variant());if ((x.get_type()!=Variant::FLOAT && x.get_type()!=Variant::INT) || !std::isfinite(double(x)) || double(x)<0) return result(false);}
        for (const char *key:{"sweep","shared_hit","overwrite","release","defer"}) if (p.get(key,Variant()).get_type()!=Variant::BOOL) return result(false);
        settings.speed=p["speed"];settings.duration=p["duration"];settings.damage=p["damage"];settings.sweep=p["sweep"];settings.shared_hit=p["shared_hit"];settings.overwrite_velocity=p["overwrite"];settings.quiet=settings.overwrite_velocity;settings.release_on_cancel=settings.release_on_end=p["release"];settings.defer_first_contact=p["defer"];
        const auto handle=speed::CanisHoundLunge::begin(runtime,*body,runtime.state.enemy_handles.at(target->second),p["action"],settings);const auto *record=speed::AttackSystem::get(runtime.state,handle);return result(record!=nullptr,record?record->id:0);
    }
    if (kind=="dev_canis_flame") {
        if (p.size()!=4 || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("definition",Variant()).get_type()!=Variant::INT || p.get("target",Variant()).get_type()!=Variant::INT || p.get("observation",Variant()).get_type()!=Variant::INT) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));const auto target=runtime.state.rows_by_id.find(int64_t(p["target"]));const int64_t definition=p["definition"],observation=p["observation"];if (found==runtime.state.rows_by_id.end() || definition<=0 || uint64_t(definition)>runtime.content->canis_flames.size() || observation<0) return result(false);
        auto *body=speed::PhaseController::find(runtime,runtime.state.enemy_handles.at(found->second));if (!body || runtime.content->bosses[runtime.content->boss_bodies[body->definition-1].boss-1].kind!=2 || body->mode>=speed::BossMode::Defeated) return result(false);
        const auto handle=speed::CanisFlames::begin(runtime,*body,definition,target==runtime.state.rows_by_id.end()?speed::EnemyHandle{}:runtime.state.enemy_handles.at(target->second),observation);const auto *record=speed::AttackSystem::get(runtime.state,handle);return result(record!=nullptr,record?record->id:0);
    }
    if (kind=="dev_boss_body_state") return result(p.is_empty(),speed::PhaseController::snapshot(runtime));
    if (kind=="dev_spawn_boss") {
        if (p.size()!=3 || p.get("definition",Variant()).get_type()!=Variant::INT || p.get("position",Variant()).get_type()!=Variant::VECTOR2 || p.get("entrance",Variant()).get_type()!=Variant::BOOL) return result(false);
        const int64_t definition=p["definition"];if (definition<=0 || uint64_t(definition)>runtime.content->boss_bodies.size()) return result(false);
        const auto &d=runtime.content->bosses[runtime.content->boss_bodies[definition-1].boss-1];const auto actor=d.kind==0?speed::MonocerosBody::spawn(runtime,definition,p["position"],p["entrance"]):d.kind==1?speed::CentaurusBody::spawn(runtime,definition,p["position"],p["entrance"]):speed::CanisMajorBody::spawn(runtime,definition,p["position"],p["entrance"]);
        return result(runtime.state.enemy_handles.contains(actor),runtime.state.enemy_handles.entity_id(actor));
    }
    if (kind=="dev_cancel_boss" || kind=="dev_boss_final") {
        if (p.get("entity_id",Variant()).get_type()!=Variant::INT || p.size()!=(kind=="dev_boss_final"?2:1)) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));if (found==runtime.state.rows_by_id.end()) return result(false);const auto actor=runtime.state.enemy_handles.at(found->second);
        if (!speed::PhaseController::find(runtime,actor)) return result(false);
        if (kind=="dev_cancel_boss") {speed::PhaseController::cancel(runtime,actor);return result(true);}
        const Variant charge=p.get("charge",Variant());if ((charge.get_type()!=Variant::FLOAT && charge.get_type()!=Variant::INT) || !std::isfinite(double(charge))) return result(false);
        return result(speed::PhaseController::begin_final(runtime,actor,charge));
    }
    if (kind=="dev_boss_flow_state") return result(p.is_empty(),speed::FlowRunner::snapshot(runtime));
    if (kind=="dev_cancel_flow") {
        if (p.size()!=1 || p.get("entity_id",Variant()).get_type()!=Variant::INT) return result(false);
        for (auto &flow:runtime.state.bosses.flows) if (runtime.state.enemy_handles.entity_id(flow.actor)==int64_t(p["entity_id"])) {speed::FlowRunner::cancel(runtime,flow);flow.selection_enabled=false;return result(true);}
        return result(false);
    }
    if (kind=="dev_boss_flow") {
        if ((p.size()!=2 && p.size()!=3) || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("definition",Variant()).get_type()!=Variant::INT || (p.has("participants") && p["participants"].get_type()!=Variant::PACKED_INT64_ARRAY)) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));const int64_t definition=p["definition"];std::vector<speed::EnemyHandle> participants;
        if (p.has("participants")) {const PackedInt64Array ids=p["participants"];for (auto id:ids) {const auto item=runtime.state.rows_by_id.find(id);if (item==runtime.state.rows_by_id.end()) return result(false);participants.push_back(runtime.state.enemy_handles.at(item->second));}}
        return result(found!=runtime.state.rows_by_id.end() && definition>0 && uint64_t(definition)<=runtime.content->boss_flows.size() && speed::FlowRunner::attach(runtime,runtime.state.enemy_handles.at(found->second),definition,participants));
    }
    if (kind=="dev_boss_state") return result(p.is_empty(),speed::TechniqueRunner::snapshot(runtime));
    if (kind=="dev_boss_technique") {
        if (p.size()!=2 || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("definition",Variant()).get_type()!=Variant::INT) return result(false);
        const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));const int64_t definition=p["definition"];
        if (found==runtime.state.rows_by_id.end() || definition<=0 || uint64_t(definition)>runtime.content->boss_techniques.size()) return result(false);
        const auto handle=speed::TechniqueRunner::begin(runtime,runtime.state.enemy_handles.at(found->second),uint32_t(definition));
        if (!runtime.state.bosses.handles.contains(handle)) return result(false);
        PackedInt64Array ticket;ticket.push_back(handle.slot);ticket.push_back(handle.generation);return result(true,ticket);
    }
    if (p.size()!=1 || p.get("ticket",Variant()).get_type()!=Variant::PACKED_INT64_ARRAY) return result(false);
    const PackedInt64Array ticket=p["ticket"];if (ticket.size()!=2 || ticket[0]<0 || ticket[0]>=UINT32_MAX || ticket[1]<=0 || ticket[1]>UINT32_MAX) return result(false);
    const speed::TechniqueHandle handle{uint32_t(ticket[0]),uint32_t(ticket[1])};
    if (!speed::TechniqueRunner::running(runtime,handle)) return result(false);
    speed::TechniqueRunner::cancel(runtime,handle);return result(true);
}
