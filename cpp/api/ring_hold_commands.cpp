#include "run_core.h"
#include "../systems/attacks/ring_hold.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_ring_hold_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"ring_hold";out["message"]=ok?"":"待機弾の発生元・個数・値が不正です";out["value"]=value;return out;};
    if (!runtime.api_development || p.get("source_id",Variant()).get_type()!=Variant::INT || p.get("count",Variant()).get_type()!=Variant::INT ||
        int64_t(p["count"])<0 || uint64_t(int64_t(p["count"]))>UINT32_MAX) return result(false);
    const auto source=runtime.state.rows_by_id.find(int64_t(p["source_id"]));if (source==runtime.state.rows_by_id.end()) return result(false);
    speed::RingHoldParams params;params.source=runtime.state.enemy_handles.at(uint32_t(source->second));params.count=uint32_t(int64_t(p["count"]));
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;if (name=="source_id" || name=="count" || name=="budget") continue;
        double *field=nullptr;
        if (name=="radius") field=&params.radius;else if (name=="wait") field=&params.wait;else if (name=="speed") field=&params.speed;else if (name=="damage") field=&params.damage;else return result(false);
        const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v)) || double(v)<0) return result(false);*field=v;
    }
    for (const char *key:{"radius","wait","speed","damage"}) if (!p.has(key)) return result(false);
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    const auto handles=speed::RingHoldSystem::emit(runtime,params);Array rows;
    for (const auto handle:handles) {const auto *record=speed::AttackSystem::get(runtime.state,handle);Dictionary row;row["id"]=record->id;row["row"]=record->row;rows.push_back(row);}
    return result(handles.size()==params.count,rows);
}
