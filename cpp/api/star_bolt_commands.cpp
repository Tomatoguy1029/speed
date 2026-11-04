#include "run_core.h"
#include "../systems/attacks/star_bolt.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_star_bolt_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"star_bolt";out["message"]=ok?String():String::utf8("星弾の発生元・値が不正です");out["value"]=value;return out;};
    if (!runtime.api_development || p.get("position",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::StarBoltParams params;params.position=p["position"];
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name=="position" || name=="owner_id" || name=="budget") continue;
        double *field=nullptr;
        if (name=="angle") field=&params.angle;else if (name=="speed") field=&params.speed;else if (name=="damage") field=&params.damage;else return result(false);
        const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return result(false);*field=v;
    }
    for (const char *key:{"angle","speed","damage"}) if (!p.has(key)) return result(false);
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("owner_id")) {
        if (p["owner_id"].get_type()!=Variant::INT) return result(false);const auto found=runtime.state.rows_by_id.find(int64_t(p["owner_id"]));
        if (found==runtime.state.rows_by_id.end()) return result(false);params.owner=runtime.state.enemy_handles.at(uint32_t(found->second));
    }
    const auto handle=speed::StarBoltSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary value;value["id"]=record->id;value["row"]=record->row;return result(true,value);
}
