#include "run_core.h"
#include "../systems/attacks/light_arrow.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_light_arrow_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"light_arrow";out["message"]=ok?"":"光弾の発生元・値が不正です";out["value"]=value;return out;};
    if (!runtime.api_development || p.get("position",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::LightArrowParams params;params.position=p["position"];
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name=="position" || name=="owner_id" || name=="budget" || name=="cosmic") continue;
        double *field=nullptr;
        if (name=="angle") field=&params.angle;else if (name=="speed") field=&params.speed;else if (name=="damage") field=&params.damage;else if (name=="radius") field=&params.radius;else if (name=="travel") field=&params.travel;else if (name=="length") field=&params.length;else return result(false);
        const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return result(false);*field=v;
    }
    for (const char *key:{"angle","speed","radius","travel","damage"}) if (!p.has(key)) return result(false);
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("owner_id")) {
        if (p["owner_id"].get_type()!=Variant::INT) return result(false);const auto found=runtime.state.rows_by_id.find(int64_t(p["owner_id"]));
        if (found==runtime.state.rows_by_id.end()) return result(false);params.owner=runtime.state.enemy_handles.at(uint32_t(found->second));
    }
    if (p.has("cosmic")) {if (p["cosmic"].get_type()!=Variant::BOOL) return result(false);params.cosmic=p["cosmic"];}
    const auto handle=speed::LightArrowSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary value;value["id"]=record->id;value["row"]=record->row;return result(true,value);
}
