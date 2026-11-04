#include "run_core.h"
#include "../systems/attacks/friend_debris.h"
#include <cmath>
using namespace godot;
namespace {
bool number(const Dictionary &p,const char *key,double &out,bool optional=false) {if (!p.has(key)) return optional;const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return false;out=v;return true;}
}
Dictionary SpeedRunCore::development_debris_command(const String &kind,const Dictionary &p) {
    const auto result=[](bool ok) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"debris";out["message"]=ok?String():String::utf8("破片の発生元・値が不正です");out["value"]=Variant();return out;};
    if (!runtime.api_development) return result(false);
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name!="position" && name!="source_id" && name!="count" && name!="speed" && name!="damage" && name!="color" && name!="armor_count" && name!="direction" && name!="velocity" && name!="knock" && name!="radius_mult" && name!="life_mult" && name!="knock_mult" && name!="shatter_depth") return result(false);
    }
    int64_t source_id=-1;if (p.has("source_id")) {if (p["source_id"].get_type()!=Variant::INT) return result(false);source_id=p["source_id"];}
    double damage=0;if (!number(p,"damage",damage) || damage<0) return result(false);
    if (kind=="dev_burst_debris" || kind=="dev_debris_on_death") {
        if (p.get("count",Variant()).get_type()!=Variant::INT || int64_t(p["count"])<0 || int64_t(p["count"])>INT32_MAX) return result(false);
        double speed=0;if (!number(p,"speed",speed) || speed<0 || !std::isfinite(float(speed))) return result(false);
        if (kind=="dev_debris_on_death") {
            const auto found=runtime.state.rows_by_id.find(source_id);if (found==runtime.state.rows_by_id.end()) return result(false);
            runtime.state.attacks.development_debris_sources[source_id]={uint32_t(int64_t(p["count"])),speed,damage};return result(true);
        }
        if (p.get("position",Variant()).get_type()!=Variant::VECTOR2) return result(false);
        speed::DebrisBurstParams params;params.position=p["position"];params.count=p["count"];params.speed=speed;params.damage=damage;params.source_id=source_id;params.color=Color(1,1,1,1);
        if (p.has("color")) {if (p["color"].get_type()!=Variant::COLOR) return result(false);params.color=p["color"];}
        if (p.has("armor_count")) {if (p["armor_count"].get_type()!=Variant::INT || int64_t(p["armor_count"])<0) return result(false);params.armor_count=p["armor_count"];}
        return result(speed::FriendDebrisSystem::burst(runtime,params));
    }
    const auto found=runtime.state.rows_by_id.find(source_id);if (found==runtime.state.rows_by_id.end()) return result(false);
    const auto source=runtime.state.enemy_handles.at(uint32_t(found->second));
    if (kind=="dev_scatter_hull") {
        speed::DebrisScatterParams params;params.source=source;params.damage=damage;
        if (p.get("direction",Variant()).get_type()!=Variant::VECTOR2 || !number(p,"speed",params.speed) || !number(p,"knock",params.knock,true) || !number(p,"radius_mult",params.radius_mult,true) || !number(p,"life_mult",params.life_mult,true)) return result(false);
        params.direction=p["direction"];
        if (p.has("shatter_depth")) {if (p["shatter_depth"].get_type()!=Variant::INT || int64_t(p["shatter_depth"])<0 || int64_t(p["shatter_depth"])>INT32_MAX) return result(false);params.shatter_depth=int32_t(int64_t(p["shatter_depth"]));}
        return result(speed::FriendDebrisSystem::scatter(runtime,params));
    }
    if (kind=="dev_fling_corpse") {
        speed::DebrisFlingParams params;params.source=source;params.damage=damage;
        if (p.get("velocity",Variant()).get_type()!=Variant::VECTOR2 || !number(p,"radius_mult",params.radius_mult,true) || !number(p,"life_mult",params.life_mult,true) || !number(p,"knock_mult",params.knock_mult,true)) return result(false);
        params.velocity=p["velocity"];return result(speed::FriendDebrisSystem::fling(runtime,params));
    }
    return result(false);
}
