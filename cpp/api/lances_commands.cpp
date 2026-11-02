#include "run_core.h"
#include "../systems/attacks/light_lances.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
Dictionary SpeedRunCore::development_lances_command(const String &kind,const Dictionary &p) {
    const auto result=[](bool ok,Variant value=Variant()){Dictionary d;d["ok"]=ok;d["code"]=ok?0:1;d["field"]=ok?"":"light_lances";d["message"]=ok?"":"光の槍の生成条件が不正です";d["value"]=value;return d;};
    if (!runtime.api_development) return result(false);
    if (kind=="dev_light_lances_state" || kind=="dev_tick_light_lances") {
        if (kind=="dev_tick_light_lances") {
            const Variant dt=p.get("world_dt",Variant());if (p.size()!=1 || (dt.get_type()!=Variant::FLOAT && dt.get_type()!=Variant::INT) || !std::isfinite(double(dt)) || double(dt)<0) return result(false);speed::LightLancesSystem::step(runtime,dt);
        } else if (!p.is_empty()) return result(false);Array rows;
        for (const auto &l:runtime.state.attacks.lances) {Dictionary row;row["id"]=int64_t(l.id);row["from"]=l.from;row["velocity"]=l.velocity;row["length"]=l.length;row["width"]=l.width;row["damage"]=l.damage;row["knock"]=l.knock;row["life"]=l.life;row["duplicate"]=l.duplicate;PackedInt64Array hits;for (auto id:l.hits) hits.push_back(id);hits.sort();row["hits"]=hits;rows.push_back(row);}
        Dictionary value;value["items"]=rows;value["flying_count"]=int64_t(speed::AttackSystem::flying_count(runtime.state));value["pending"]=int64_t(runtime.state.attacks.friendly_reservations);return result(true,value);
    }
    if (p.size()!=6 || p.get("position",Variant()).get_type()!=Variant::VECTOR2 || p.get("direction",Variant()).get_type()!=Variant::VECTOR2) return result(false);
    speed::LightLanceParams params;params.position=p["position"];params.direction=p["direction"];
    for (const char *key:{"length","width","damage","knock"}) {const Variant value=p.get(key,Variant());if ((value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value))) return result(false);if (String(key)=="length") params.length=value;else if (String(key)=="width") params.width=value;else if (String(key)=="damage") params.damage=value;else params.knock=value;}
    const auto ids=speed::LightLancesSystem::fire(runtime,params);Array values;for (auto id:ids) values.push_back(int64_t(id));return result(!ids.empty(),values);
}
