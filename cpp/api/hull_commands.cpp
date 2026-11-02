#include "run_core.h"
#include "../systems/attacks/friend_hull.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_hull_command(const String &kind,const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"hull";out["message"]=ok?String():String::utf8("船体弾の外観・値が不正です");out["value"]=value;return out;};
    if (!runtime.api_development || p.get("position",Variant()).get_type()!=Variant::VECTOR2 || p.get("velocity",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::FriendHullParams params;params.saw=kind=="dev_fire_saw";params.position=p["position"];params.velocity=p["velocity"];
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;if (name=="position" || name=="velocity" || name=="definition_id" || name=="source_id") continue;
        double *field=nullptr;if (name=="radius") field=&params.radius;else if (name=="damage") field=&params.damage;else if (name=="life") field=&params.life;else if (name=="knock") field=&params.knock;else if (name=="angle") field=&params.angle;else return result(false);
        const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return result(false);*field=v;
    }
    for (const char *key:{"radius","damage","life"}) if (!p.has(key)) return result(false);
    if (p.has("source_id")) {if (p["source_id"].get_type()!=Variant::INT) return result(false);params.source_id=p["source_id"];}
    if (!params.saw) {
        if (p.get("definition_id",Variant()).get_type()!=Variant::STRING || !p.has("angle") || !p.has("knock")) return result(false);
        for (uint32_t i=0;i<runtime.content->definitions.size();++i) if (runtime.content->definitions[i].id==StringName(p["definition_id"])) {params.source_definition=i+1;break;}
    }
    const auto handle=speed::FriendHullSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary value;value["id"]=record->id;value["row"]=record->row;return result(true,value);
}
