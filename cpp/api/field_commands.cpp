#include "run_core.h"
#include "../systems/field.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary reply(bool ok,Variant value=Variant()) {Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["field"]=ok?"":"field";out["message"]=ok?"":"地形の問い合わせか初期値が不正です";out["value"]=value;return out;}
bool point(const Dictionary &p,const char *key) {return p.has(key) && p[key].get_type()==Variant::VECTOR2 && Vector2(p[key]).is_finite();}
bool radius(const Dictionary &p) {if (!p.has("radius")) return false;const auto v=p["radius"];return (v.get_type()==Variant::FLOAT || v.get_type()==Variant::INT) && std::isfinite(double(v)) && double(v)>=0;}
}
Dictionary SpeedRunCore::development_field_command(const String &kind,const Dictionary &p) {
    if (!runtime.api_development) return reply(false);
    if (kind=="dev_field_query") {
        if (p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
        const String action=p["action"];
        if (action=="hit" && p.size()==4 && point(p,"from") && point(p,"to") && radius(p)) {
            const auto hit=speed::FieldSystem::first_body_hit(runtime,p["from"],p["to"],p["radius"]);
            if (!hit) return reply(true);
            const auto &body=runtime.state.field.bodies[hit->body];Dictionary value;value["id"]=runtime.content->field_bodies[body.definition].id;value["t"]=hit->t;value["point"]=hit->point;return reply(true,value);
        }
        if (action=="accel" && p.size()==2 && point(p,"position")) return reply(true,speed::FieldSystem::boundary_accel(runtime,p["position"]));
        if (p.size()!=3 || !point(p,"position") || !radius(p)) return reply(false);
        if (action=="push") return reply(true,speed::FieldSystem::push_out(runtime,p["position"],p["radius"]));
        if (action=="gap") {const double gap=speed::FieldSystem::body_gap(runtime,p["position"],p["radius"]);return reply(true,std::isfinite(gap)?Variant(gap):Variant());}
        return reply(false);
    }
    if (runtime.state.phase==Phase::Ended || runtime.state.draw.drawing || runtime.state.draw.tracing ||
        (p.size()!=2 && p.size()!=3) || !point(p,"position") || !point(p,"velocity") ||
        (p.size()==3 && (!p.has("glide") || p["glide"].get_type()!=Variant::BOOL))) return reply(false);
    auto &ship=runtime.state.ship;ship.pos=p["position"];ship.vel=p["velocity"];ship.glide=p.get("glide",false);
    ship.glide_t=0;ship.glide_speed=ship.vel.length();if (!ship.vel.is_zero_approx()) ship.heading=ship.vel.normalized();
    if (kind=="dev_field_collide") speed::FieldSystem::collide_ship(runtime);
    runtime.state.ship_pos=ship.pos;return reply(true,ship_snapshot());
}
