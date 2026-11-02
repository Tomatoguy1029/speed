#include "run_core.h"
#include "../systems/attack_system.h"
#include "../behaviors/traits/duplicator.h"
#include <cmath>
using namespace godot;
namespace {
bool keys(const Dictionary &d,std::initializer_list<const char *> allowed) {
    for (const auto &key:d.keys()) {bool found=false;for (auto name:allowed) if (key.get_type()==Variant::STRING && String(key)==name) found=true;if (!found) return false;}return true;
}
bool number(const Dictionary &d,const char *key,double &out,double fallback) {
    if (!d.has(key)) {out=fallback;return true;}
    const Variant v=d[key];if ((v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) || !std::isfinite(double(v)) || double(v)<0 || !std::isfinite(float(double(v)))) return false;
    out=v;return true;
}
bool integer(const Dictionary &d,const char *key,int64_t &out,int64_t fallback,int64_t maximum=INT32_MAX) {
    if (!d.has(key)) {out=fallback;return true;}
    if (d[key].get_type()!=Variant::INT || int64_t(d[key])<0 || int64_t(d[key])>maximum) return false;out=d[key];return true;
}
bool births(speed::RunRuntime &run,const Array &rows,unsigned depth,bool execute,size_t &nodes) {
    if (depth>16) return false;
    speed::FriendlyBirthScope scope(run,execute);
    for (const auto &value:rows) {
        if (++nodes>512 || value.get_type()!=Variant::DICTIONARY) return false;
        const Dictionary d=value;
        if (d.has("nested")) {
            if (d.size()!=1 || d["nested"].get_type()!=Variant::ARRAY || !births(run,d["nested"],depth+1,execute,nodes)) return false;
            continue;
        }
        if (!keys(d,{"position","velocity","kind","damage","post_damage","radius","life","age","knock","pierce","pierce_left","no_crit","cause","weapon_id","visual_key","type","hit_ids","shatter_depth","callback","callback_knock","callback_no_crit"}) || !d.has("position") || !d.has("velocity") || d["position"].get_type()!=Variant::VECTOR2 || d["velocity"].get_type()!=Variant::VECTOR2) return false;
        RunState::Friendly shot;shot.pos=d["position"];shot.vel=d["velocity"];if (!shot.pos.is_finite() || !shot.vel.is_finite()) return false;
        int64_t kind,depth_value;
        if (!integer(d,"kind",kind,0,2) || !integer(d,"pierce_left",shot.pierce_left,0) || !integer(d,"shatter_depth",depth_value,0)) return false;
        shot.kind=kind;shot.shatter_depth=int32_t(depth_value);
        double radius,life,age,knock,post_damage,callback_knock;
        if (!number(d,"damage",shot.damage,1) || !number(d,"post_damage",post_damage,shot.damage) || !number(d,"radius",radius,5) || !number(d,"life",life,1) || !number(d,"age",age,0) || !number(d,"knock",knock,250) || !number(d,"callback_knock",callback_knock,160)) return false;
        shot.radius=radius;shot.life=life;shot.age=age;shot.knock=knock;shot.callback.knock=callback_knock;
        for (auto name:{"pierce","no_crit","callback_no_crit"}) if (d.has(name) && d[name].get_type()!=Variant::BOOL) return false;
        shot.pierce=d.get("pierce",false);shot.no_crit=d.get("no_crit",false);shot.callback.no_crit=d.get("callback_no_crit",true);
        for (auto name:{"cause","weapon_id","visual_key","type","callback"}) if (d.has(name) && d[name].get_type()!=Variant::STRING) return false;
        shot.cause=StringName(d.get("cause",String("shot")));shot.weapon_id=StringName(d.get("weapon_id",String()));shot.visual=StringName(d.get("visual_key",String("weapon/forward")));shot.type=StringName(d.get("type",String()));
        speed::AttackSpec spec;spec.policies=speed::policy(speed::EndPolicy::NaturalLifetime);
        if (!speed::parse_symbol(String(shot.cause).utf8().get_data(),spec.cause) || !speed::parse_symbol(String(d.get("callback",String("none"))).utf8().get_data(),shot.callback.kind)) return false;
        if (shot.kind==int64_t(speed::FriendKind::Debris)) {
            if (run.content->friend_debris.empty()) return false;
            shot.debris.definition=1;
            shot.debris.style=shot.visual==StringName("weapon/knockback")?speed::DebrisStyle::Stardust:shot.visual==StringName("enemy/pump_burst")?speed::DebrisStyle::Pump:speed::DebrisStyle::Plain;
        } else if (shot.kind==int64_t(speed::FriendKind::Hull)) {
            if (run.content->friend_hulls.empty() || spec.cause!=speed::Cause::Saw) return false;
            shot.hull={1,0,-1,true};
        }
        if (d.has("hit_ids")) {
            if (d["hit_ids"].get_type()!=Variant::PACKED_INT64_ARRAY) return false;
            const PackedInt64Array ids=d["hit_ids"];for (auto id:ids) {if (id<=0) return false;shot.hit_ids.insert(id);}
        }
        if (!shot.weapon_id.is_empty()) {
            bool found=false;for (const auto &weapon:run.content->equipment) if (weapon.kind==0 && shot.weapon_id==StringName(weapon.external_id.c_str())) {spec.weapon=weapon.id;found=true;break;}
            if (!found) return false;
        }
        if (execute) {
            const auto emitted=speed::AttackSystem::emit_friendly(run,std::move(shot),spec);const auto *record=speed::AttackSystem::get(run.state,emitted);
            if (!record) return false;
            run.state.friends[record->row].damage=post_damage;
        }
    }
    return true;
}
}
Dictionary SpeedRunCore::development_friend_command(const String &kind,const Dictionary &d) {
    bool ok=false;
    if (runtime.api_development && kind=="dev_friend_reserve" && keys(d,{"count","release"}) && d.size()==2 && d["count"].get_type()==Variant::INT && int64_t(d["count"])>=0 && d["release"].get_type()==Variant::BOOL) {
        ok=bool(d["release"])?speed::AttackSystem::release_friendly(runtime.state,uint64_t(int64_t(d["count"]))):speed::AttackSystem::reserve_friendly(runtime.state,uint64_t(int64_t(d["count"])));
    } else if (runtime.api_development && kind=="dev_friend_births" && d.size()==1 && d.has("births") && d["births"].get_type()==Variant::ARRAY) {
        size_t count=0;const Array rows=d["births"];
        if (births(runtime,rows,0,false,count)) {count=0;ok=births(runtime,rows,0,true,count);}
    }
    Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["message"]=ok?String():String::utf8("味方攻撃の生成条件が不正です");out["field"]=ok?"":"births/count";out["value"]=int64_t(speed::AttackSystem::flying_count(runtime.state));return out;
}
