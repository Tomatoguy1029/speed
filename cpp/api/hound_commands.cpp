#include "run_core.h"
#include "../systems/group_system.h"
#include <cmath>
using namespace godot;
namespace {
Dictionary reply(bool ok) {Dictionary v;v["ok"]=ok;v["code"]=ok?0:1;v["field"]=ok?"":"hound_order";v["message"]=ok?"":"猟犬の指示または対象が不正です";v["value"]=Variant();return v;}
bool number(const Dictionary &p,const char *key,double &out) {const Variant v=p.get(key,Variant());if (v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) return false;out=v;return std::isfinite(out);}
bool point(const Dictionary &p,const char *key,Vector2 &out) {const Variant v=p.get(key,Variant());if (v.get_type()!=Variant::VECTOR2) return false;out=v;return out.is_finite();}
}
Dictionary SpeedRunCore::development_hound_command(const Dictionary &p) {
    if (!runtime.api_development || p.get("entity_id",Variant()).get_type()!=Variant::INT || p.get("action",Variant()).get_type()!=Variant::STRING) return reply(false);
    const auto found=runtime.state.rows_by_id.find(int64_t(p["entity_id"]));if (found==runtime.state.rows_by_id.end()) return reply(false);
    const auto actor=runtime.state.enemy_handles.at(uint32_t(found->second));const String action=p["action"];
    if (action=="release" && p.size()==2) return reply(speed::GroupSystem::release_order(runtime.state,actor));
    double until;if (!number(p,"until",until)) return reply(false);
    if (action=="mark" && p.size()==3) return reply(speed::GroupSystem::mark(runtime.state,actor,until));
    Vector2 goal;
    if (action=="follow" && p.size()==5) {double scale;if (!point(p,"goal",goal) || !number(p,"scale",scale) || scale<0) return reply(false);return reply(speed::GroupSystem::follow(runtime.state,actor,goal,until,scale));}
    if (action=="quiet" && (p.size()==3 || p.size()==4)) {Vector2 velocity;if (p.has("velocity") && !point(p,"velocity",velocity)) return reply(false);return reply(speed::GroupSystem::quiet(runtime.state,actor,until,p.has("velocity"),velocity));}
    if (action=="steer" && p.size()==6 && p.get("config",Variant()).get_type()==Variant::DICTIONARY) {
        Vector2 face;if (!point(p,"goal",goal) || !point(p,"face",face)) return reply(false);
        const Dictionary config=p["config"];if (config.size()!=8) return reply(false);
        speed::HoundSteering parsed;
        const char *names[]={"arrive","decel","face_turn","turn_slow","turn_fast","turn_switch","max_speed","accel"};
        double *values[]={&parsed.arrive,&parsed.decel,&parsed.face_turn,&parsed.turn_slow,&parsed.turn_fast,&parsed.turn_switch,&parsed.max_speed,&parsed.accel};
        for (int i=0;i<8;++i) if (!number(config,names[i],*values[i]) || *values[i]<0) return reply(false);
        return reply(speed::GroupSystem::steer(runtime.state,actor,goal,face,until,parsed));
    }
    return reply(false);
}
