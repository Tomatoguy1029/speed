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
    if (kind=="dev_spawn_well" && p.is_empty()) return reply(speed::FieldSystem::spawn_well(runtime));
    if (kind=="dev_add_well") {
        if (p.size()!=4 || !point(p,"position") || !radius(p)) return reply(false);
        for (const char *key:{"life","pull"}) {const Variant value=p.get(key,Variant());if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value))) return reply(false);}
        return reply(speed::FieldSystem::add_well(runtime,p["position"],p["life"],p["radius"],p["pull"]));
    }
    if (kind=="dev_tick_gravity") {
        const Variant value=p.get("dt",Variant());if (p.size()!=1 || (value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value)) || double(value)<0) return reply(false);
        speed::FieldSystem::step_gravity(runtime,value);return reply(true);
    }
    if (kind=="dev_field_query") {
        if (p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
        const String action=p["action"];
        if (action=="wells" && p.size()==1) {
            Array wells;for (const auto &well:runtime.state.field.wells) {Dictionary row;row["position"]=well.position;row["born"]=well.born;row["life"]=well.life;row["radius"]=well.radius;row["pull"]=well.pull;wells.append(row);}return reply(true,wells);
        }
        if (action=="rocks" && p.size()==1) {
            Array rocks;
            for (uint32_t i=0;i<runtime.state.field.rocks.size();++i) {
                const auto &rock=runtime.state.field.rocks[i];Dictionary item;
                item["id"]=i+1;item["kind"]=int(rock.kind);item["initial_position"]=rock.position;item["position"]=speed::FieldSystem::rock_at(runtime,rock);
                item["velocity"]=rock.velocity;item["size"]=rock.size;item["facing"]=rock.facing;item["spin"]=rock.spin;item["manual"]=rock.manual;item["destroyed"]=rock.destroyed;
                item["enemy_id"]=runtime.state.enemy_handles.entity_id(rock.proxy);rocks.push_back(item);
            }
            return reply(true,rocks);
        }
        if (action=="snapshot" && p.size()==1) {
            Array bodies;
            for (uint32_t i=0;i<runtime.state.field.bodies.size();++i) {
                const auto &body=runtime.state.field.bodies[i];Dictionary item;
                item["id"]=i+1;item["position"]=body.position;item["radius"]=body.radius;item["moon"]=body.moon;
                item["orbit"]=body.orbit;item["a0"]=body.a0;item["direction"]=body.direction;bodies.push_back(item);
            }
            Dictionary value;value["bodies"]=bodies;value["world_time"]=runtime.state.world_time;value["body_speed_max"]=runtime.state.field.body_speed_max;return reply(true,value);
        }
        if (action=="hit" && p.size()==4 && point(p,"from") && point(p,"to") && radius(p)) {
            const auto hit=speed::FieldSystem::first_body_hit(runtime,p["from"],p["to"],p["radius"]);
            if (!hit) return reply(true);
            Dictionary value;value["id"]=hit->body+1;value["t"]=hit->t;value["point"]=hit->point;return reply(true,value);
        }
        if (action=="accel" && p.size()==2 && point(p,"position")) return reply(true,speed::FieldSystem::boundary_accel(runtime,p["position"]));
        if (p.size()!=3 || !point(p,"position") || !radius(p)) return reply(false);
        if (action=="push") return reply(true,speed::FieldSystem::push_out(runtime,p["position"],p["radius"]));
        if (action=="gap") {const double gap=speed::FieldSystem::body_gap(runtime,p["position"],p["radius"]);return reply(true,std::isfinite(gap)?Variant(gap):Variant());}
        return reply(false);
    }
    if (kind=="dev_add_rock") {
        if (runtime.content->rock_fields.empty() || !point(p,"position") || !p.has("kind") || p["kind"].get_type()!=Variant::INT || int64_t(p["kind"])<0 || int64_t(p["kind"])>=int64_t(speed::RockKind::Count)) return reply(false);
        speed::FieldRock rock;rock.kind=speed::RockKind(int64_t(p["kind"]));rock.position=p["position"];
        for (const auto &key:p.keys()) {
            if (key.get_type()!=Variant::STRING) return reply(false);const String name=key;
            if (name=="position" || name=="kind") continue;
            if (name=="velocity") {if (!point(p,"velocity")) return reply(false);rock.velocity=p[key];}
            else if (name=="manual") {if (p[key].get_type()!=Variant::BOOL) return reply(false);rock.manual=p[key];}
            else if (name=="size" || name=="facing" || name=="spin" || name=="born" || name=="gone") {
                const Variant v=p[key];if ((v.get_type()!=Variant::INT && v.get_type()!=Variant::FLOAT) || !std::isfinite(double(v))) return reply(false);
                if (name=="size") {if (double(v)<=0) return reply(false);rock.size=v;}else if (name=="facing") rock.facing=v;else if (name=="spin") rock.spin=v;else if (name=="born") rock.born=v;else rock.gone=v;
            } else return reply(false);
        }
        if (rock.kind==speed::RockKind::Comet && rock.gone<=rock.born) return reply(false);
        const auto handle=speed::FieldSystem::add_rock(runtime,rock);return reply(runtime.state.field.rock_handles.contains(handle),int64_t(handle.slot)+1);
    }
    if (kind=="dev_stream_rocks") {
        if (runtime.content->rock_fields.empty() || p.size()!=3 || !point(p,"center") || !point(p,"half") || Vector2(p["half"]).x<0 || Vector2(p["half"]).y<0 ||
            !p.has("dt") || (p["dt"].get_type()!=Variant::FLOAT && p["dt"].get_type()!=Variant::INT) || !std::isfinite(double(p["dt"])) || double(p["dt"])<=0) return reply(false);
        runtime.state.view_center=p["center"];runtime.state.view_half=p["half"];speed::FieldSystem::stream_rocks(runtime,p["dt"]);
        return reply(rebuild_enemy_grid(runtime.state.frame_grid_cell));
    }
    if (runtime.state.phase==Phase::Ended || runtime.state.draw.drawing || runtime.state.draw.tracing ||
        (p.size()!=2 && p.size()!=3) || !point(p,"position") || !point(p,"velocity") ||
        (p.size()==3 && (!p.has("glide") || p["glide"].get_type()!=Variant::BOOL))) return reply(false);
    auto &ship=runtime.state.ship;ship.pos=p["position"];ship.vel=p["velocity"];ship.glide=p.get("glide",false);
    ship.glide_t=0;ship.glide_speed=ship.vel.length();if (!ship.vel.is_zero_approx()) ship.heading=ship.vel.normalized();
    if (kind=="dev_field_collide") speed::FieldSystem::collide_ship(runtime);
    runtime.state.ship_pos=ship.pos;return reply(true,ship_snapshot());
}
