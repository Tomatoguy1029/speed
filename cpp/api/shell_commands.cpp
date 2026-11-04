#include "run_core.h"
#include "../systems/attacks/shell.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_shell_command(const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()){Dictionary d;d["ok"]=ok;d["code"]=ok?0:1;d["field"]=ok?"":"shell";d["message"]=ok?"":"圧縮弾の生成条件が不正です";d["value"]=value;return d;};
    if (!runtime.api_development || p.get("source_id",Variant()).get_type()!=Variant::INT) return result(false);
    const auto source=runtime.state.rows_by_id.find(int64_t(p["source_id"]));if (source==runtime.state.rows_by_id.end()) return result(false);
    speed::ShellParams params;params.source=runtime.state.enemy_handles.at(uint32_t(source->second));
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;if (name=="source_id" || name=="contents" || name=="budget") continue;
        double *field=nullptr;if (name=="angle") field=&params.angle;else if (name=="speed") field=&params.speed;else if (name=="radius") field=&params.radius;else if (name=="range") field=&params.range;else if (name=="burst") field=&params.burst;else if (name=="damage") field=&params.damage;else return result(false);
        const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return result(false);*field=v;
    }
    for (const char *key:{"angle","speed","radius","range","burst","damage"}) if (!p.has(key)) return result(false);
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("contents")) {if (p["contents"].get_type()!=Variant::PACKED_STRING_ARRAY) return result(false);const PackedStringArray items=p["contents"];for (const auto &item:items) {uint32_t id=0;for (uint32_t i=0;i<runtime.content->definitions.size();++i) if (runtime.content->definitions[i].id==StringName(item)) {id=i+1;break;}if (!id) return result(false);params.contents.push_back(id);}}
    const auto handle=speed::ShellSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);Dictionary value;value["id"]=record->id;value["row"]=record->row;return result(true,value);
}
