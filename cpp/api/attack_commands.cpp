#include "run_core.h"
#include "../systems/attack_system.h"
#include "../systems/attack_budget.h"
#include "../output/event_builder.h"
#include "../content/content_bundle.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary response(bool ok,Variant value=Variant()) {Dictionary r;r["ok"]=ok;r["code"]=ok?0:1;r["message"]=ok?"":"攻撃の対象・条件・引数が不正です";r["field"]=ok?"":"kind/payload";r["value"]=value;return r;}
bool keys(const Dictionary &d,std::initializer_list<const char *> names) {
    for (const auto &key:d.keys()) {bool found=false;for (auto name:names) if (key.get_type()==Variant::STRING && String(key)==name) found=true;if (!found) return false;}return true;
}
bool scalar(const Dictionary &d,const char *key,double &value,double fallback) {
    if (!d.has(key)) {value=fallback;return true;}const Variant v=d[key];
    if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v)) || double(v)<0 || !std::isfinite(float(double(v)))) return false;
    value=v;return true;
}
template<class Tag> bool handle(const Variant &v,speed::Handle<Tag> &h) {
    if (v.get_type()!=Variant::PACKED_INT64_ARRAY) return false;const PackedInt64Array a=v;
    if (a.size()!=2 || a[0]<0 || uint64_t(a[0])>=UINT32_MAX || a[1]<=0 || uint64_t(a[1])>=UINT32_MAX) return false;
    h={uint32_t(a[0]),uint32_t(a[1])};return true;
}
PackedInt64Array packed(speed::AttackHandle h) {PackedInt64Array a;a.push_back(h.slot);a.push_back(h.generation);return a;}
}
Array SpeedRunCore::attack_snapshot() const {
    Array out;
    for (uint32_t i=0;i<runtime.state.attacks.records.size();++i) {
        const auto &r=runtime.state.attacks.records[i];if (!r.alive) continue;
        Dictionary row;row["id"]=r.id;row["handle"]=packed(runtime.state.attacks.handles.at(i));row["pool"]=int(r.pool);row["row"]=r.row;
        row["source_id"]=r.spec.owner.source_id;row["source_alive"]=runtime.state.enemy_handles.contains(r.spec.owner.live_source);
        row["budget"]=r.spec.owner.budget.value;row["residuals"]=speed::AttackBudgetSystem::retained(runtime.state,r.spec.owner.budget);
        row["policies"]=r.spec.policies;row["attached"]=r.spec.owner.attached;out.push_back(row);
    }return out;
}
Dictionary SpeedRunCore::development_attack_command(const String &kind,const Dictionary &d) {
    if (!runtime.api_development) return response(false);auto &state=runtime.state;Variant value;
    if (kind=="dev_emit_attack") {
        if (!keys(d,{"pool","position","velocity","life","damage","radius","delay","owner_id","budget","policies","attached","contact_definition","cause","source_technique","technique","participant","boss","encounter"}) || !d.has("pool") || d["pool"].get_type()!=Variant::INT || int64_t(d["pool"])<0 || int64_t(d["pool"])>2 || !d.has("position") || d["position"].get_type()!=Variant::VECTOR2 || !Vector2(d["position"]).is_finite()) return response(false);
        speed::AttackSpec spec;
        for (auto key:{"owner_id","budget","policies"}) if (d.has(key) && (d[key].get_type()!=Variant::INT || int64_t(d[key])<0)) return response(false);
        const int64_t policies=d.get("policies",1);if (policies<1 || policies>63) return response(false);spec.policies=uint32_t(policies);
        spec.owner.budget.value=d.get("budget",0);
        if (d.has("attached") && d["attached"].get_type()!=Variant::BOOL) return response(false);spec.owner.attached=d.get("attached",false);
        if (d.has("owner_id") && int64_t(d["owner_id"])>0) {
            const auto found=state.rows_by_id.find(int64_t(d["owner_id"]));if (found==state.rows_by_id.end()) return response(false);
            spec.owner.live_source=state.enemy_handles.at(uint32_t(found->second));
        }
        if ((d.has("technique") && !handle(d["technique"],spec.technique)) || (d.has("participant") && !handle(d["participant"],spec.participant)) ||
            (d.has("boss") && !handle(d["boss"],spec.boss)) || (d.has("encounter") && !handle(d["encounter"],spec.encounter))) return response(false);
        double life,damage,radius,delay;
        if (!scalar(d,"life",life,1) || !scalar(d,"damage",damage,0) || !scalar(d,"radius",radius,2) || !scalar(d,"delay",delay,0)) return response(false);
        Vector2 velocity;if (d.has("velocity")) {if (d["velocity"].get_type()!=Variant::VECTOR2 || !Vector2(d["velocity"]).is_finite()) return response(false);velocity=d["velocity"];}
        if (d.has("contact_definition")) {
            if (d["contact_definition"].get_type()!=Variant::INT || int64_t(d["contact_definition"])<=0 || uint64_t(int64_t(d["contact_definition"]))>UINT32_MAX ||
                !speed::AttackSystem::configure_contact(*runtime.content,uint32_t(int64_t(d["contact_definition"])),spec)) return response(false);
        }
        if (d.has("source_technique")) {
            if (d["source_technique"].get_type()!=Variant::INT || int64_t(d["source_technique"])<0 || uint64_t(int64_t(d["source_technique"]))>UINT32_MAX) return response(false);
            spec.source_technique=uint32_t(int64_t(d["source_technique"]));
        }
        speed::Cause cause=speed::Cause::None;
        if (d.has("cause") && (d["cause"].get_type()!=Variant::STRING || !speed::parse_symbol(String(d["cause"]).utf8().get_data(),cause))) return response(false);
        speed::AttackHandle emitted;const Vector2 pos=d["position"];
        switch(int64_t(d["pool"])) {
        case 0: {Friendly shot;shot.pos=pos;shot.vel=velocity;shot.life=life;shot.radius=radius;shot.damage=damage;spec.cause=cause==speed::Cause::None?speed::Cause::Shot:cause;emitted=speed::AttackSystem::emit_friendly(runtime,shot,spec);break;}
        case 1: {Hostile shot;shot.pos=pos;shot.vel=velocity;shot.speed=velocity.length();shot.life=life;shot.radius=radius;shot.damage=damage;spec.cause=cause==speed::Cause::None?speed::Cause::Bullet:cause;emitted=speed::AttackSystem::emit_hostile(state,shot,spec);break;}
        case 2: {if (!state.bite_zone_config.ready) return response(false);BiteZone zone;zone.pos=pos;zone.shape=speed::CircleHazard{float(radius)};zone.delay=delay;zone.duration=life;zone.damage=damage;spec.cause=cause==speed::Cause::None?speed::Cause::Blast:cause;emitted=speed::AttackSystem::emit_hazard(state,zone,spec);break;}
        }
        const auto *record=speed::AttackSystem::get(state,emitted);if (!record) return response(false);
        Dictionary created;created["id"]=record->id;created["handle"]=packed(emitted);created["row"]=record->row;value=created;
    } else if (kind=="dev_end_attack") {
        speed::AttackHandle h;if (!keys(d,{"handle"}) || !d.has("handle") || !handle(d["handle"],h)) return response(false);
        value=speed::AttackSystem::end(state,h,speed::AttackEndReason::Hit);
    } else if (kind=="dev_attack_update") {
        if (!keys(d,{"begin"}) || d.size()!=1 || d["begin"].get_type()!=Variant::BOOL) return response(false);
        if (bool(d["begin"])) {if (!speed::AttackSystem::begin_hostile_update(state)) return response(false);}
        else {if (!state.attacks.hostile_updating) return response(false);speed::AttackSystem::finish_hostile_update(state);}
    } else if (kind=="dev_clear_hostile") {
        if (!d.is_empty()) return response(false);speed::AttackSystem::clear_hostile(state,speed::AttackEndReason::BossClear);
    } else if (kind=="dev_attack_scope") {
        if (!keys(d,{"event","handle","owner_id"}) || !d.has("event") || d["event"].get_type()!=Variant::STRING) return response(false);
        const String event=d["event"];
        if (event=="bonus") speed::AttackSystem::clear_bonus(state);
        else if (event=="relocate") {
            if (!d.has("owner_id") || d["owner_id"].get_type()!=Variant::INT) return response(false);
            const auto found=state.rows_by_id.find(int64_t(d["owner_id"]));if (found==state.rows_by_id.end()) return response(false);
            speed::AttackSystem::source_ended(state,state.enemy_handles.at(uint32_t(found->second)),speed::AttackEndReason::Relocate);
        } else {
            if (!d.has("handle")) return response(false);
            if (event=="technique_cancel" || event=="technique_end") {speed::TechniqueHandle h;if (!handle(d["handle"],h)) return response(false);speed::AttackSystem::end_technique(state,h,event=="technique_cancel");}
            else if (event=="participant_end") {speed::ParticipantHandle h;if (!handle(d["handle"],h)) return response(false);speed::AttackSystem::end_participant(state,h);}
            else if (event=="boss_end") {speed::BossHandle h;if (!handle(d["handle"],h)) return response(false);speed::AttackSystem::end_boss(state,h);}
            else if (event=="encounter_end") {speed::EncounterHandle h;if (!handle(d["handle"],h)) return response(false);speed::AttackSystem::end_encounter(state,h);}
            else return response(false);
        }
    } else return response(false);
    speed::EventBuilder::flush_combat(runtime);return response(true,value);
}
