#include "run_core.h"
#include "../systems/collision_query.h"
#include "../systems/combat_resolver.h"
#include "../systems/attack_system.h"
#include "../output/event_builder.h"
#include "../content/content_bundle.h"
#include <algorithm>
#include <cmath>
using namespace godot;
namespace {
Dictionary response(bool ok,Variant value=Variant()) {
    Dictionary out;out["ok"]=ok;out["code"]=ok?0:1;out["message"]=ok?"":"攻撃の形・対象・値が不正です";
    out["field"]=ok?"":"contact";out["value"]=value;return out;
}
bool points(const Dictionary &d,const char *key,std::vector<Vector2> &out) {
    if (!d.has(key)) return true;
    if (d[key].get_type()!=Variant::PACKED_VECTOR2_ARRAY) return false;
    PackedVector2Array values=d[key];
    for (int64_t i=0;i<values.size();++i) {if (!values[i].is_finite()) return false;out.push_back(values[i]);}
    return true;
}
}
Dictionary SpeedRunCore::development_contact_command(const Dictionary &d) {
    if (!runtime.api_development || d.get("handle",Variant()).get_type()!=Variant::PACKED_INT64_ARRAY) return response(false);
    const PackedInt64Array handle=d["handle"];
    if (handle.size()!=2 || handle[0]<0 || uint64_t(handle[0])>=UINT32_MAX || handle[1]<=0 || uint64_t(handle[1])>=UINT32_MAX) return response(false);
    const speed::AttackHandle attack{uint32_t(handle[0]),uint32_t(handle[1])};
    const auto *record=speed::AttackSystem::get(runtime.state,attack);if (!record) return response(false);
    const auto definition=std::find_if(runtime.content->contacts.begin(),runtime.content->contacts.end(),[&](const auto &v){return v.id==record->spec.contact_definition;});
    if (definition==runtime.content->contacts.end()) return response(false);
    for (const auto &key:d.keys()) {
        if (key.get_type()!=Variant::STRING && key.get_type()!=Variant::STRING_NAME) return response(false);
        const String name=key;
        if (name=="handle" || name=="points" || name=="before") continue;
        if (name=="center" || name=="half") {if (d[key].get_type()!=Variant::VECTOR2 || !Vector2(d[key]).is_finite()) return response(false);}
        else if (name=="apply") {if (d[key].get_type()!=Variant::BOOL) return response(false);}
        else if (name=="radius" || name=="angle" || name=="arc" || name=="gap_angle" || name=="gap_arc" || name=="amount" || name=="slow") {
            const Variant value=d[key];if ((value.get_type()!=Variant::FLOAT && value.get_type()!=Variant::INT) || !std::isfinite(double(value))) return response(false);
        } else return response(false);
    }
    std::vector<Vector2> path,before;if (!points(d,"points",path) || !points(d,"before",before)) return response(false);
    const Vector2 center=d.get("center",Vector2()),half=d.get("half",Vector2());
    const double radius=d.get("radius",0.0),angle=d.get("angle",0.0),arc=d.get("arc",Math::PI),gap_angle=d.get("gap_angle",0.0),gap_arc=d.get("gap_arc",0.0);
    const double amount=d.get("amount",0.0),slow=d.get("slow",0.0),width=definition->half_width;
    if (radius<0 || half.x<0 || half.y<0 || arc<0 || arc>Math::PI || gap_arc<0 || gap_arc>Math::PI || amount<0 || slow<0) return response(false);
    speed::ContactShape shape;
    switch(speed::ContactShapeKind(definition->shape)) {
    case speed::ContactShapeKind::PointCircle:shape=speed::PointCircle{center,radius};break;
    case speed::ContactShapeKind::SegmentCircle:
        if (path.size()!=2) return response(false);shape=speed::SegmentCircle{path[0],path[1],width};break;
    case speed::ContactShapeKind::SweptSegment:
        if (path.size()!=2 || before.size()!=2) return response(false);shape=speed::SweptSegment{before[0],before[1],path[0],path[1],width};break;
    case speed::ContactShapeKind::Polyline:
        if (path.size()<2 || (!before.empty() && before.size()!=path.size())) return response(false);shape=speed::Polyline{std::move(path),std::move(before),width};break;
    case speed::ContactShapeKind::Fan:shape=speed::Fan{center,radius,angle,arc};break;
    case speed::ContactShapeKind::RingBand:shape=speed::RingBand{center,radius,width,angle,arc,gap_angle,gap_arc};break;
    case speed::ContactShapeKind::Rect:shape=speed::ContactRect{center,half,angle};break;
    default:return response(false);
    }
    Dictionary result;
    if (bool(d.get("apply",false))) {
        const auto contact=speed::CombatResolver::attack_ship_damage(runtime,attack,shape,amount,slow);
        result["touching"]=contact.touching;result["attempted"]=contact.attempted;
        result["damage"]=speed::EventBuilder::ship_result(contact.damage);speed::EventBuilder::flush_combat(runtime);
    } else {
        const auto &state=runtime.state;const auto from=record->ship_previous_ready?record->ship_previous:state.ship.pos;
        result["touching"]=speed::CollisionQuery::touches(shape,{from,state.ship.pos,state.ship_config.ship_radius},{definition->add_ship_radius,definition->ship_sweep});
        result["half_width"]=width;
    }
    return response(true,result);
}
