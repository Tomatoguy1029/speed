#include "run_core.h"
#include "../systems/combat_resolver.h"
#include "../output/event_builder.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary result(bool ok,Variant value=Variant()) {
    Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["message"]=ok?"":"戦闘の操作・対象・引数が不正です";
    out["field"]=ok?"":"kind/payload";out["value"]=value;return out;
}
bool fields(const Dictionary &data,std::initializer_list<const char *> allowed) {
    for (const auto &key:data.keys()) {
        if (key.get_type()!=Variant::STRING && key.get_type()!=Variant::STRING_NAME) return false;
        bool found=false;for (auto name:allowed) if (String(key)==name) {found=true;break;}
        if (!found) return false;
    }return true;
}
bool number(const Dictionary &data,const char *key) {
    if (!data.has(key)) return false;
    const Variant value=data[key];return (value.get_type()==Variant::FLOAT || value.get_type()==Variant::INT) && std::isfinite(double(value));
}
bool cause(const Dictionary &data,speed::Cause &out) {
    if (!data.has("cause")) {out=speed::Cause::Shot;return true;}
    const auto type=data["cause"].get_type();
    if (type!=Variant::STRING && type!=Variant::STRING_NAME) return false;
    return speed::parse_symbol(String(data["cause"]).utf8().get_data(),out);
}
}
Dictionary SpeedRunCore::development_combat_command(const String &kind,const Dictionary &data) {
    if (!runtime.api_development) return result(false);
    auto &state=runtime.state;
    if (kind=="dev_ship_damage") {
        speed::ShipDamageRequest request;
        if (!fields(data,{"amount","slow","cause","source","technique","scale","hit_policy"}) || !number(data,"amount") || !cause(data,request.cause)) return result(false);
        request.amount=data["amount"];
        if (data.has("slow")) {if (!number(data,"slow")) return result(false);request.slow=data["slow"];}
        for (const auto &entry: {std::pair<const char *,int64_t>{"scale",1},{"hit_policy",3},{"technique",INT32_MAX}}) {
            if (data.has(entry.first) && (data[entry.first].get_type()!=Variant::INT || int64_t(data[entry.first])<0 || int64_t(data[entry.first])>entry.second)) return result(false);
        }
        request.scale=speed::DamageScale(int64_t(data.get("scale",0)));request.hit_policy=speed::HitPolicy(int64_t(data.get("hit_policy",3)));
        request.technique=uint32_t(int64_t(data.get("technique",0)));
        if (data.has("source")) {
            if (data["source"].get_type()!=Variant::STRING) return result(false);
            const String source=data["source"];bool found=source.is_empty();
            for (size_t i=0;i<runtime.content->definitions.size();++i) if (String(runtime.content->definitions[i].id)==source) {request.source=uint32_t(i+1);found=true;break;}
            if (!found) return result(false);
        }
        const auto resolved=speed::CombatResolver::ship_damage(runtime,request);speed::EventBuilder::flush_combat(runtime);
        return result(true,speed::EventBuilder::ship_result(resolved));
    }
    if (!data.has("entity_id") || data["entity_id"].get_type()!=Variant::INT) return result(false);
    const auto found=state.rows_by_id.find(int64_t(data["entity_id"]));if (found==state.rows_by_id.end()) return result(false);
    const auto target=state.enemy_handles.at(uint32_t(found->second));
    if (kind=="dev_enemy_combat") {
        if (!fields(data,{"entity_id","guard","damage_target","pump_owner","mode"}) || data.size()<2) return result(false);
        if (data.has("mode") && (data["mode"].get_type()!=Variant::INT || int64_t(data["mode"])<0 || int64_t(data["mode"])>3)) return result(false);
        if (data.has("guard") && (!number(data,"guard") || double(data["guard"])<0)) return result(false);
        speed::EnemyHandle parent=state.enemies[target.slot].damage_target;
        if (data.has("damage_target")) {
            if (data["damage_target"].get_type()!=Variant::INT) return result(false);
            const int64_t id=data["damage_target"];
            if (!id) parent={};
            else {
                const auto next=state.rows_by_id.find(id);if (next==state.rows_by_id.end()) return result(false);
                parent=state.enemy_handles.at(uint32_t(next->second));auto cursor=parent;
                for (size_t i=0;i<=state.enemies.size();++i) {
                    if (cursor.slot==target.slot && cursor.generation==target.generation) return result(false);
                    if (!cursor.generation) break;
                    if (!state.enemy_handles.contains(cursor) || i==state.enemies.size()) return result(false);
                    cursor=state.enemies[cursor.slot].damage_target;
                }
            }
        }
        auto pump_owner=state.enemies[target.slot].pump_owner;
        if (data.has("pump_owner")) {
            if (data["pump_owner"].get_type()!=Variant::INT) return result(false);
            const int64_t id=data["pump_owner"];
            if (id==0) pump_owner={};
            else {
                const auto found=state.rows_by_id.find(id);if (found==state.rows_by_id.end()) return result(false);
                pump_owner=state.enemy_handles.at(uint32_t(found->second));if (pump_owner.slot==target.slot) return result(false);
            }
        }
        auto &enemy=state.enemies[target.slot];if (data.has("mode")) enemy.mode=speed::EnemyMode(int64_t(data["mode"]));if (data.has("guard")) enemy.guard=data["guard"];enemy.damage_target=parent;enemy.pump_owner=pump_owner;
        return result(true);
    }
    speed::DamageRequest request;request.struck=target;
    if (!cause(data,request.cause) || !fields(data,{"entity_id","amount","cause","direction","impact","knock","crit","no_crit","weapon_id","shatter_depth"})) return result(false);
    if (data.has("crit")) {if (data["crit"].get_type()!=Variant::BOOL) return result(false);request.crit=data["crit"];}
    if (data.has("no_crit")) {if (data["no_crit"].get_type()!=Variant::BOOL) return result(false);request.no_crit=data["no_crit"];}
    for (const char *key:{"weapon_id","shatter_depth"}) if (data.has(key) && (data[key].get_type()!=Variant::INT || int64_t(data[key])<0 || int64_t(data[key])>INT32_MAX)) return result(false);
    request.weapon_id=uint32_t(int64_t(data.get("weapon_id",0)));request.shatter_depth=int32_t(int64_t(data.get("shatter_depth",0)));
    for (const char *key:{"direction","impact"}) if (data.has(key) && (data[key].get_type()!=Variant::VECTOR2 || !Vector2(data[key]).is_finite())) return result(false);
    request.direction=data.get("direction",Vector2());request.has_impact=data.has("impact");request.impact=data.get("impact",Vector2());
    if (data.has("knock")) {if (!number(data,"knock")) return result(false);request.knock=data["knock"];}
    if (kind=="dev_damage") {
        if (!number(data,"amount")) return result(false);request.amount=data["amount"];
        const auto damage=speed::CombatResolver::damage_enemy(runtime,request);speed::EventBuilder::flush_combat(runtime);
        return result(true,speed::EventBuilder::damage_result(runtime,damage));
    }
    if (kind=="dev_kill") {
        if (data.has("amount")) return result(false);
        const auto killed=speed::CombatResolver::kill_enemy(runtime,request);speed::EventBuilder::flush_combat(runtime);
        Dictionary out;out["killed"]=killed.killed;out["reason"]=speed::combat_reason_name(killed.reason);return result(true,out);
    }
    return result(false);
}
