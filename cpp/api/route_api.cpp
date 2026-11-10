#include "run_core.h"
#include "../systems/route_constraints.h"
#include "../systems/attack_budget.h"
#include <cmath>
using namespace godot;
namespace {
bool keys(const Dictionary &d,std::initializer_list<const char *> names) {for (auto key:d.keys()) {if (key.get_type()!=Variant::STRING && key.get_type()!=Variant::STRING_NAME) return false;bool found=false;for (auto n:names) if (String(key)==n) found=true;if (!found) return false;}return true;}
bool scalar(const Dictionary &d,const char *key,double &out,bool infinity=false) {const auto v=d.get(key,Variant());if (v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) return false;out=v;return std::isfinite(out) || (infinity && out>0 && std::isinf(out));}
bool integer(const Dictionary &d,const char *key,int64_t &out) {const auto v=d.get(key,Variant());if (v.get_type()!=Variant::INT) return false;out=v;return out>=0;}
bool flag(const Dictionary &d,const char *key,bool &out) {const auto v=d.get(key,Variant());if (v.get_type()!=Variant::BOOL) return false;out=v;return true;}
bool point(const Dictionary &d,const char *key,Vector2 &out) {const auto v=d.get(key,Variant());if (v.get_type()!=Variant::VECTOR2) return false;out=v;return out.is_finite();}
Dictionary reply(bool ok,Variant value=Variant(),int code=1) {Dictionary d;d["ok"]=ok;d["code"]=ok?0:code;d["message"]=ok?String():String::utf8("経路判定の入力・状態を確認してください");d["field"]=ok?"":"route";d["value"]=ok?value:Variant();return d;}
bool options(const Dictionary &d,speed::RouteOptions &out) {
    if (!keys(d,{"margin","window","draw_seconds","exit_clearance","scheduled","future_ticks"})) return false;
    for (auto item:{std::pair{"margin",&out.margin},{"window",&out.window},{"draw_seconds",&out.draw_seconds},{"exit_clearance",&out.exit_clearance}}) if (d.has(item.first) && !scalar(d,item.first,*item.second)) return false;
    if (d.has("scheduled") && !flag(d,"scheduled",out.scheduled)) return false;
    if (d.has("future_ticks")) {if (d["future_ticks"].get_type()!=Variant::PACKED_INT64_ARRAY) return false;PackedInt64Array ticks=d["future_ticks"];for (auto tick:ticks) {if (tick<0) return false;out.future_ticks.push_back(tick);}}
    return true;
}
const char *reason_key(speed::RouteReason reason) {
    using R=speed::RouteReason;switch(reason) {
    case R::InvalidPath:return "lab.message_7474db4292";case R::OverBudget:return "lab.message_ace1dcf08b";case R::LowFuel:return "lab.low_charge";case R::LinkTooFar:return "lab.link_too_far";case R::FieldEdge:return "lab.message_fdee8bc433";
    case R::Body:return "lab.message_409189caf0";case R::Gate:return "lab.message_416deae061";case R::Strong:return "lab.message_676b643ad5";case R::Equipment:return "lab.message_eaf4530ecf";
    case R::FutureTerrain:return "lab.message_feb890132f";case R::Bullet:return "lab.message_8e84357015";case R::Hazard:return "lab.message_c977ed9a15";default:return "";
    }
}
Dictionary obstacle(const speed::RouteObstacle &v) {
    Dictionary d;d["code"]=int64_t(v.reason);d["reason_key"]=reason_key(v.reason);d["pos"]=v.position;if (v.id) d["id"]=v.id;
    d["enemy"]=v.reason==speed::RouteReason::MovingEnemy;
    using R=speed::RouteReason;switch(v.reason) {
    case R::MovingEnemy:d["reason"]=String::utf8("動く敵や特殊な敵");d["id"]=v.id;break;case R::MovingTerrain:d["reason"]=String::utf8("動く地形や配置済みの岩");break;
    case R::FutureCommands:d["reason"]=String::utf8("この先の記録済み命令");break;case R::HomingBullet:d["reason"]=String::utf8("追尾する弾");break;case R::AttachedHazard:d["reason"]=String::utf8("敵に付いた攻撃");break;
    case R::AutoSpawn:d["reason"]=String::utf8("自動の補充");break;case R::Scheduled:d["reason"]=String::utf8("予定された命令");break;default:break;
    }return d;
}
Dictionary result(const speed::RouteResult &r,const speed::RouteOptions &o,int64_t tick) {
    static const char *status[]={"invalid","static","unfound","window","unsupported"};Dictionary d;d["status"]=status[int(r.status)];d["valid"]=r.valid;d["length"]=r.length;d["budget"]=r.budget;d["sweep_radius"]=r.radius;d["horizon"]=r.horizon;
    d["margin"]=o.margin;d["window"]=o.window;d["draw_seconds"]=o.draw_seconds;d["exit_clearance"]=std::max(0.0,o.exit_clearance);d["tick"]=tick;d["critical_dependent"]=false;
    Array blockers,unsupported,fodder;for (auto v:r.blockers) blockers.push_back(obstacle(v));for (auto v:r.unsupported) unsupported.push_back(obstacle(v));for (auto id:r.fodder) fodder.push_back(id);
    d["blockers"]=blockers;d["unsupported"]=unsupported;d["fodder"]=fodder;if (r.status==speed::RouteStatus::Invalid) d["reason_key"]=reason_key(speed::RouteReason::InvalidPath);return d;
}
bool path_points(const PackedVector2Array &points,std::vector<Vector2> &out) {for (auto p:points) {if (!p.is_finite()) return false;out.push_back(p);}return true;}
bool context(const Dictionary &d,speed::RouteContext &c) {
    if (!keys(d,{"values","tick","history_hz","equipment_count","well_count","rock_count","hero","auto_spawn","bodies","enemies","bullets","hazards"}) || d.size()!=12 || d["values"].get_type()!=Variant::DICTIONARY) return false;
    const Dictionary v=d["values"];
    const std::pair<const char *,double *> values[]={
        {"ship_radius",&c.ship_radius},{"field_radius",&c.field_radius},{"point_step",&c.point_step},{"zoom",&c.zoom},{"fuel",&c.fuel},{"fuel_max",&c.fuel_max},{"fuel_capacity",&c.fuel_capacity},{"boost_min_cost",&c.boost_min_cost},{"boost_min_q",&c.boost_min_q},
        {"draw_length",&c.draw_length},{"boost_cost_ratio",&c.boost_cost_ratio},{"max_speed",&c.max_speed},{"base_speed",&c.base_speed},{"length_mult",&c.length_mult},{"confirm_delay",&c.confirm_delay},{"run_time",&c.run_time},{"hitstop_cap",&c.hitstop_cap},
        {"time_scale",&c.time_scale},{"scale_min",&c.scale_min},{"pending_world",&c.pending_world},{"attack",&c.attack},{"window_attack",&c.window_attack},{"body_speed",&c.body_speed},{"comet_time",&c.comet_time},{"gravity_time",&c.gravity_time}};
    if (v.size()!=26 || !point(v,"ship_position",c.ship_position)) return false;for (auto [key,value]:values) if (!scalar(v,key,*value,value==&c.comet_time || value==&c.gravity_time) || *value<0) return false;
    if (c.base_speed<=0 || c.fuel_capacity<=0 || c.fuel_max<=0 || c.field_radius<=0 || c.boost_cost_ratio<=0 || c.boost_cost_ratio>1) return false;
    if (!integer(d,"tick",c.tick) || !integer(d,"history_hz",c.history_hz) || c.history_hz<=0 || !integer(d,"equipment_count",c.equipment_count) || !integer(d,"well_count",c.well_count) || !integer(d,"rock_count",c.rock_count) || !flag(d,"hero",c.hero) || !flag(d,"auto_spawn",c.auto_spawn)) return false;
    for (auto key:{"bodies","enemies","bullets","hazards"}) if (d[key].get_type()!=Variant::ARRAY) return false;
    const Array bodies=d["bodies"],enemies=d["enemies"],bullets=d["bullets"],hazards=d["hazards"];
    for (auto value:bodies) {if (value.get_type()!=Variant::DICTIONARY) return false;Dictionary row=value;speed::RouteContext::Body b;if (row.size()!=2 || !point(row,"position",b.position) || !scalar(row,"radius",b.radius) || b.radius<0) return false;c.bodies.push_back(b);}
    for (auto value:enemies) {
        if (value.get_type()!=Variant::DICTIONARY) return false;Dictionary row=value;speed::RouteContext::Enemy e;int64_t gate;
        if (row.size()!=13 || !integer(row,"id",e.id) || !point(row,"position",e.position) || !point(row,"velocity",e.velocity) || !integer(row,"gate",gate) || gate>7 || !flag(row,"boss",e.boss) || !flag(row,"chain",e.chain) || !flag(row,"split",e.split) || !flag(row,"life",e.life)) return false;
        if (row["behavior"].get_type()!=Variant::STRING) return false;const String behavior=row["behavior"];e.simple=behavior=="chase" || behavior=="drift";e.gate=uint32_t(gate);
        for (auto [key,p]:{std::pair{"radius",&e.radius},{"hp",&e.hp},{"armor",&e.armor},{"speed",&e.speed}}) if (!scalar(row,key,*p) || *p<0) return false;c.enemies.push_back(e);
    }
    for (auto value:bullets) {if (value.get_type()!=Variant::DICTIONARY) return false;Dictionary row=value;speed::RouteContext::Bullet p;if (row.size()!=5 || !integer(row,"id",p.id) || !point(row,"position",p.position) || !point(row,"velocity",p.velocity) || !scalar(row,"radius",p.radius) || p.radius<0 || !flag(row,"homing",p.homing)) return false;c.bullets.push_back(p);}
    for (auto value:hazards) {if (value.get_type()!=Variant::DICTIONARY) return false;Dictionary row=value;speed::RouteContext::Hazard h;if (row.size()!=6 || !integer(row,"id",h.id) || !point(row,"position",h.position) || !point(row,"end",h.end) || !scalar(row,"radius",h.radius) || h.radius<0 || !flag(row,"circle",h.circle) || !flag(row,"attached",h.attached)) return false;c.hazards.push_back(h);}
    return true;
}
}
Dictionary SpeedRunCore::query_route_run(const PackedVector2Array &points,const Dictionary &parameters) const {
    if (runtime.busy) return reply(false,Variant(),7);if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return reply(false,Variant(),4);
    speed::RouteOptions o;std::vector<Vector2> path;if (!options(parameters,o) || !path_points(points,path)) return reply(false);
    return reply(true,result(speed::RouteConstraints::validate(speed::RouteConstraints::context(runtime),path,o),o,runtime.state.control.tick));
}
// 未移行の制作セッション専用。読取値を一度計算し、状態や乱数を保持しない。
Dictionary SpeedRunCore::query_route_snapshot(const Dictionary &snapshot,const PackedVector2Array &points,const Dictionary &parameters) const {
    speed::RouteOptions o;speed::RouteContext c;std::vector<Vector2> path;if (!options(parameters,o) || !path_points(points,path) || !context(snapshot,c)) return reply(false);
    return reply(true,result(speed::RouteConstraints::validate(c,path,o),o,c.tick));
}

Dictionary SpeedRunCore::encounter_state_run() const {
    if (runtime.busy) return reply(false,Variant(),7);if (!runtime.api_configured || !runtime.state.started || runtime.state.closed) return reply(false,Variant(),4);
    const auto &s=runtime.state.encounter;Dictionary out;out["next"]=s.next;out["start"]=s.start;out["window"]=s.window;out["margin"]=s.margin;out["available"]=s.opportunity;out["guard_active"]=speed::AttackBudgetSystem::guard_active(runtime.state);
    PackedVector2Array route;for (auto point:s.route) route.push_back(point);out["route"]=route;out["status"]=s.window>0?"window":"static";return reply(true,out);
}
