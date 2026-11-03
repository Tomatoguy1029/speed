#include "run_core.h"
#include "../systems/attacks/wave.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_wave_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"wave";out["message"]=ok?"":"波動の対象・形・値が不正です";out["value"]=value;return out;};
    if (!runtime.api_development || p.get("position",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::WaveParams params;params.position=p["position"];
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name=="position" || name=="color" || name=="owner_id" || name=="budget" || name=="style" || name=="layers" || name=="interval" || name=="gap_step") continue;
        double *field=nullptr;
        if (name=="angle") field=&params.angle;else if (name=="arc") field=&params.arc;else if (name=="radius") field=&params.radius;
        else if (name=="start_radius") field=&params.start_radius;else if (name=="speed") field=&params.speed;else if (name=="width") field=&params.width;
        else if (name=="delay") field=&params.delay;else if (name=="damage") field=&params.damage;else if (name=="gap") field=&params.gap;
        else if (name=="gap_arc") field=&params.gap_arc;else if (name=="enemy_damage") field=&params.enemy_damage;else return result(false);
        const Variant value=p[key];if ((value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value))) return result(false);*field=value;
    }
    for (const char *key:{"angle","arc","radius","speed","width","delay","damage"}) if (!p.has(key)) return result(false);
    if (p.has("color")) {if (p["color"].get_type()!=Variant::COLOR) return result(false);params.color=p["color"];}
    if (p.has("style")) {if (p["style"].get_type()!=Variant::INT || int64_t(p["style"])<0 || int64_t(p["style"])>=int64_t(speed::WaveStyle::Count)) return result(false);params.style=speed::WaveStyle(int64_t(p["style"]));}
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("owner_id")) {
        if (p["owner_id"].get_type()!=Variant::INT) return result(false);const auto found=runtime.state.rows_by_id.find(int64_t(p["owner_id"]));
        if (found==runtime.state.rows_by_id.end()) return result(false);params.owner=runtime.state.enemy_handles.at(uint32_t(found->second));
    }
    if (p.has("layers")) {
        if (p["layers"].get_type()!=Variant::INT || int64_t(p["layers"])<0 || uint64_t(int64_t(p["layers"]))>UINT32_MAX) return result(false);
        double interval=0,gap_step=0;
        for (const char *key:{"interval","gap_step"}) {
            if (!p.has(key) || (p[key].get_type()!=Variant::INT && p[key].get_type()!=Variant::FLOAT) || !std::isfinite(double(p[key]))) return result(false);
            (String(key)=="interval"?interval:gap_step)=p[key];
        }
        if (interval<0) return result(false);
        const auto handles=speed::WaveSystem::emit_layers(runtime,params,uint32_t(int64_t(p["layers"])),interval,gap_step);Array rows;
        for (auto handle:handles) {const auto *record=speed::AttackSystem::get(runtime.state,handle);Dictionary row;row["id"]=record->id;row["row"]=record->row;rows.push_back(row);}
        return result(rows.size()==int64_t(p["layers"]),rows);
    }
    const auto handle=speed::WaveSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary created;created["id"]=record->id;created["row"]=record->row;return result(true,created);
}
