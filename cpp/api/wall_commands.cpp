#include "run_core.h"
#include "../systems/attacks/wall.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary result(bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"wall";out["message"]=ok?"":"壁の対象・形・値が不正です";out["value"]=value;return out;}
bool point(const Dictionary &p) {return p.has("position") && p["position"].get_type()==Variant::VECTOR2 && Vector2(p["position"]).is_finite();}
bool scalar(const Dictionary &p,const char *key,double &value,bool optional=false) {
    if (!p.has(key)) return optional;const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return false;value=v;return true;
}
}
Dictionary SpeedRunCore::development_wall_command(const String &kind,const Dictionary &p) {
    if (!runtime.api_development || !point(p)) return result(false);
    double angle=0;if (!scalar(p,"angle",angle)) return result(false);
    if (kind=="dev_move_wall") {
        for (const auto &key:p.keys()) if (key.get_type()!=Variant::STRING || (String(key)!="attack_id" && String(key)!="position" && String(key)!="angle" && String(key)!="length")) return result(false);
        if (!p.has("attack_id") || p["attack_id"].get_type()!=Variant::INT || (p.size()!=3 && p.size()!=4)) return result(false);
        double length=0;std::optional<double> changed;if (p.has("length")) {if (!scalar(p,"length",length)) return result(false);changed=length;}else if (p.size()!=3) return result(false);
        for (uint32_t i=0;i<runtime.state.attacks.records.size();++i) {
            const auto &record=runtime.state.attacks.records[i];if (record.alive && record.id==int64_t(p["attack_id"])) return result(speed::WallSystem::move(runtime,runtime.state.attacks.handles.at(i),p["position"],angle,changed));
        }
        return result(false);
    }
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;
        if (name!="position" && name!="angle" && name!="length" && name!="width" && name!="style" && name!="blocking" && name!="attached" && name!="delay" && name!="active" && name!="damage" && name!="color" && name!="owner_id" && name!="budget") return result(false);
    }
    speed::WallParams params;params.position=p["position"];params.angle=angle;double width=0;
    if (!scalar(p,"length",params.length) || !scalar(p,"width",width) || width<0 ||
        !scalar(p,"delay",params.delay) || !scalar(p,"active",params.active) || !scalar(p,"damage",params.damage)) return result(false);
    params.half_width=width*0.5;
    if (p.has("color")) {if (p["color"].get_type()!=Variant::COLOR) return result(false);params.color=p["color"];}
    if (p.has("budget")) {if (p["budget"].get_type()!=Variant::INT || int64_t(p["budget"])<0) return result(false);params.budget.value=p["budget"];}
    if (p.has("owner_id")) {
        if (p["owner_id"].get_type()!=Variant::INT) return result(false);const auto found=runtime.state.rows_by_id.find(int64_t(p["owner_id"]));
        if (found==runtime.state.rows_by_id.end()) return result(false);params.owner=runtime.state.enemy_handles.at(uint32_t(found->second));
    }
    if (p.has("style")) {if (p["style"].get_type()!=Variant::INT || int64_t(p["style"])<0 || int64_t(p["style"])>=int64_t(speed::WallStyle::Count)) return result(false);params.style=speed::WallStyle(int64_t(p["style"]));}
    for (const char *key:{"blocking","attached"}) if (p.has(key)) {
        if (p[key].get_type()!=Variant::BOOL) return result(false);
        if (String(key)=="blocking") params.blocking=p[key];else params.attached=p[key];
    }
    const auto handle=speed::WallSystem::emit(runtime,params);const auto *record=speed::AttackSystem::get(runtime.state,handle);if (!record) return result(false);
    Dictionary value;value["id"]=record->id;value["row"]=record->row;return result(true,value);
}
