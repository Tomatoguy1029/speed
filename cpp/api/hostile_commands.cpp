#include "run_core.h"
#include "../systems/attacks/bullet.h"
#include "../systems/attacks/missile.h"
#include "../systems/attack_system.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary result(bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"payload";out["message"]=ok?"":"発射元と敵弾の値を確認してください";out["value"]=value;return out;}
}
Dictionary SpeedRunCore::development_hostile_command(const String &kind,const Dictionary &p) {
    if (!runtime.api_development) return result(false);
    if (kind=="dev_stone_hostiles") {
        if (!p.has("duration") || !p.has("view") || p["view"].get_type()!=Variant::RECT2) return result(false);
        const Rect2 view=p["view"];if (!view.position.is_finite() || !view.size.is_finite() || view.size.x<0 || view.size.y<0) return result(false);
        const Variant duration=p["duration"];
        if (p.size()!=2 || (duration.get_type()!=Variant::FLOAT && duration.get_type()!=Variant::INT) || !std::isfinite(double(duration)) || double(duration)<0 || !std::isfinite(float(double(duration)))) return result(false);
        speed::BulletSystem::petrify(runtime.state,view,duration);return result(true);
    }
    if (!p.has("source_id") || p["source_id"].get_type()!=Variant::INT) return result(false);
    const auto source=runtime.state.rows_by_id.find(int64_t(p["source_id"]));if (source==runtime.state.rows_by_id.end()) return result(false);
    double angle=0,shot_speed=0;speed::BulletValues values;
    for (const auto &key:p.keys()) {
        if (key.get_type()!=Variant::STRING) return result(false);const String name=key;if (name=="source_id") continue;
        const Variant value=p[key];if ((value.get_type()!=Variant::INT && value.get_type()!=Variant::FLOAT) || !std::isfinite(double(value))) return result(false);
        if (name=="angle") angle=value;else if (name=="speed") shot_speed=value;
        else if (name=="damage") values.damage=double(value);else if (name=="slow") values.slow=double(value);else if (name=="turn") values.turn=double(value);else return result(false);
    }
    if (!p.has("angle") || !p.has("speed")) return result(false);
    const auto handle=kind=="dev_fire_missile"?speed::MissileSystem::fire_enemy(runtime,runtime.state.enemy_handles.at(uint32_t(source->second)),angle,shot_speed,values):speed::BulletSystem::fire_enemy(runtime,runtime.state.enemy_handles.at(uint32_t(source->second)),angle,shot_speed,values);
    const auto *attack=speed::AttackSystem::get(runtime.state,handle);if (!attack) return result(false);
    Dictionary created;created["row"]=attack->row;created["id"]=attack->id;return result(true,created);
}
