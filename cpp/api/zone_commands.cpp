#include "run_core.h"
#include "../systems/attacks/zone.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_zone_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"zone";out["message"]=ok?"":"範囲攻撃の対象・形・値が不正です";out["value"]=value;return out;};
    if (!runtime.api_development || p.get("position",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::ZoneParams params;params.position=p["position"];
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name=="position" || name=="color" || name=="owner_id" || name=="budget" || name=="style") continue;
        double *field=nullptr;
        if (name=="radius") field=&params.radius;else if (name=="delay") field=&params.delay;else if (name=="damage") field=&params.damage;else if (name=="enemy_damage") field=&params.enemy_damage;else return result(false);
        const Variant value=p[key];if ((value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value))) return result(false);*field=value;
    }
    for (const char *key:{"radius","delay","damage"}) if (!p.has(key)) return result(false);
    if (p.has("color")) {if (p["color"].get_type()!=Variant::COLOR) return result(false);params.color=p["color"];}
    if (p.has("style")) {if (p["style"].get_type()!=Variant::INT || int64_t(p["style"])<0 || int64_t(p["style"])>=int64_t(speed::ZoneStyle::Count)) return result(false);params.style=speed::ZoneStyle(int64_t(p["style"]));}
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("owner_id")) {
        if (p["owner_id"].get_type()!=Variant::INT) return result(false);const auto found=runtime.state.rows_by_id.find(int64_t(p["owner_id"]));
        if (found==runtime.state.rows_by_id.end()) return result(false);params.owner=runtime.state.enemy_handles.at(uint32_t(found->second));
    }
    const auto handle=speed::ZoneSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary created;created["id"]=record->id;created["row"]=record->row;return result(true,created);
}
