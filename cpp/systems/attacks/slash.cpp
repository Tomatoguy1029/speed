#include "slash.h"
#include "../attack_system.h"
#include "../collision_query.h"
#include "../combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include <godot_cpp/core/math.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
constexpr double LYNX_FROM[]={0.03,0.0,0.05};
constexpr double LYNX_TO[]={0.90,1.0,0.86};
constexpr int LYNX_SEGMENTS=16;
double smooth(double a,double b,double value) {const double k=std::clamp((value-a)/(b-a),0.0,1.0);return k*k*(3.0-2.0*k);}
double visual_hash(double n) {const double value=std::sin(n*127.1+311.7)*43758.5453;return value-std::floor(value);}
struct LynxPath {
    godot::Vector2 origin,forward,across;
    double size=0,span=0,gap=0;
    godot::Vector2 at(double s) const {
        const double phi=-godot::Math::PI/2.0+span*(1.0-s);
        return origin+(across*(0.12+gap)-forward*0.70+across*(1.15*std::cos(phi))-forward*(0.85*std::sin(phi)))*size;
    }
    godot::Vector2 mark(int k,double s,double start_spacing,double end_spacing) const {
        const auto diff=at(std::min(1.0,s+0.01))-at(std::max(0.0,s-0.01));
        const auto unit=diff.length_squared()>0?diff.normalized():godot::Vector2();
        const auto normal=godot::Vector2(-unit.y,unit.x);
        return at(s)+normal*((k-1)*(start_spacing+(end_spacing-start_spacing)*s)*size);
    }
};
bool touches_lynx(const LynxDefinition &p,const SlashState &slash,godot::Vector2 pos,double angle,double max_size,double age,godot::Vector2 ship,double ship_radius) {
    const auto forward=godot::Vector2::from_angle(angle),across=godot::Vector2(-forward.y,forward.x)*slash.side;
    const double full=max_size*p.fx_max_size,initial=full*p.fx_start;
    const double growth=std::clamp(age/p.fx_grow,0.0,1.0),ease=1.0-std::pow(1.0-growth,3.0);
    const double size=full*(p.fx_start+(1.0-p.fx_start)*ease);
    if (size<=0) return false;
    const LynxPath initial_path{{},forward,across,initial,p.fx_span,0.0};
    const auto shift=(slash.paw_offset-initial_path.at(0.0))*(initial/size);
    const LynxPath path{pos+shift,forward,across,size,p.fx_span,p.fx_gap};
    const double cut=std::min(1.0,age/p.fx_cut),thickness=0.07*size*0.9;
    for (int k=0;k<3;++k) for (int i=0;i<LYNX_SEGMENTS;++i) {
        const double m=double(i)/LYNX_SEGMENTS;
        const double a=LYNX_FROM[k]+(LYNX_TO[k]-LYNX_FROM[k])*m;
        if (a>cut) break;
        const double b=std::min(cut,LYNX_FROM[k]+(LYNX_TO[k]-LYNX_FROM[k])*double(i+1)/LYNX_SEGMENTS);
        const auto from=path.mark(k,a,p.fx_space0,p.fx_space1),to=path.mark(k,b,p.fx_space0,p.fx_space1);
        const double width=thickness*smooth(0.0,0.1,m)*std::pow(1.0-m,0.7)*(0.85+0.3*visual_hash(k*17+std::floor(m*9)));
        const double reach=ship_radius+width;
        if (CollisionQuery::point_segment_squared(ship,from,to)<=reach*reach) return true;
    }
    return false;
}
}
AttackHandle SlashSystem::emit(RunRuntime &run,const SlashParams &p) {
    if (!run.state.started || run.state.closed || run.content->slashes.empty() || !p.position.is_finite() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner)) || (p.side!=1 && p.side!=-1) || p.size<=0 || !std::isfinite(p.angle) ||
        p.lynx_definition>run.content->lynxes.size() || !p.paw_offset.is_finite()) return {};
    for (double value:{p.speed,p.size,p.range,p.damage}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.speed,p.size,p.range}) if (!std::isfinite(float(value))) return {};
    godot::RunState::Hostile shot;shot.kind=int64_t(HostileKind::Slash);shot.pos=p.position;
    shot.vel=godot::Vector2::from_angle(p.angle)*p.speed;shot.speed=p.speed;shot.radius=p.size;
    shot.life=p.range/std::max(p.speed,1.0);shot.damage=p.damage;shot.slash={1,float(p.side)};
    shot.slash.lynx_definition=p.lynx_definition;shot.slash.initial_life=shot.life;shot.slash.paw_offset=p.paw_offset;
    if (!std::isfinite(shot.life)) return {};
    AttackSpec spec;spec.cause=Cause::Slash;spec.owner.live_source=p.owner;spec.owner.budget=p.budget;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (!AttackSystem::configure_contact(*run.content,run.content->slashes.front().contact,spec)) return {};
    const auto handle=AttackSystem::emit_hostile(run.state,shot,spec);
    if (AttackSystem::get(run.state,handle)) {godot::Dictionary event;event["pos"]=p.position;event["kind"]=godot::StringName("slash");FrameBuilder::append(run,"shoot",event);}
    return handle;
}
bool SlashSystem::touches(const ContentBundle &content,godot::Vector2 pos,double angle,double size,double side,godot::Vector2 at,double reach) {
    if (content.slashes.empty() || size<=0) return false;
    const auto u=godot::Vector2::from_angle(angle),d=at-pos;
    const auto local=godot::Vector2(d.dot(godot::Vector2(-u.y,u.x))*side,-d.dot(u))/size;
    const double margin=(content.slashes.front().thickness*0.5*size+reach)/size;
    for (size_t i=1;i<content.slashes.size();++i) {
        const auto &a=content.slashes[i-1],&b=content.slashes[i];if (a.claw!=b.claw) continue;
        if (CollisionQuery::point_segment_squared(local,{a.x,a.y},{b.x,b.y})<=margin*margin) return true;
    }return false;
}
bool SlashSystem::contact(RunRuntime &run,AttackHandle handle,godot::Vector2 to) {
    const auto *record=AttackSystem::get(run.state,handle);if (!record || record->pool!=AttackPool::Hostile) return false;
    auto &shot=run.state.hostiles[record->row];
    if (!shot.slash.definition) return false;
    const double age=std::max(0.0,shot.slash.initial_life-shot.life);shot.slash.age=age;
    const bool touching=shot.slash.lynx_definition?
        touches_lynx(run.content->lynxes[shot.slash.lynx_definition-1],shot.slash,to,shot.vel.angle(),shot.radius,age,run.state.ship.pos,run.state.ship_config.ship_radius):
        touches(*run.content,to,shot.vel.angle(),shot.radius,shot.slash.side,run.state.ship.pos,run.state.ship_config.ship_radius);
    run.state.observations.effect_check(record->id,touching);if (!touching) return false;
    const auto spec=record->spec;
    ShipDamageRequest request;request.observation_id=spec.observation_id;request.effect_id=record->id;request.amount=shot.damage;request.scale=spec.contact.scale;request.hit_policy=spec.contact.hit_policy;
    request.cause=spec.cause;request.technique=spec.source_technique;
    // 現行の斬撃は、移動後の爪痕だけで判定し、発生元の種類名を被弾記録へ付けない。
    CombatResolver::ship_damage(run,request);AttackSystem::mark_ship_hit(run.state,handle);AttackSystem::record_ship_position(run.state,handle);
    EventBuilder::flush_combat(run);return true;
}
void SlashSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &shot=run.state.hostiles[row];
    if (!shot.alive || !shot.slash.definition || !view.grow(shot.radius*2.0).has_point(shot.pos)) return;
    const auto *record=AttackSystem::get(run.state,shot.attack);if (!record) return;
    const auto u=Vector2::from_angle(shot.vel.angle()),across=Vector2(-u.y,u.x)*shot.slash.side;
    const double thickness=run.content->slashes.front().thickness*shot.radius,zoom=std::max(0.01,run.state.control.camera_zoom);
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Polyline);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    if (shot.slash.lynx_definition) shape["reference_lynx"]=true;
    PackedVector2Array points;PackedInt32Array offsets;PackedFloat32Array widths;PackedColorArray colors;offsets.push_back(0);
    for (uint32_t claw=0;claw<3;++claw) for (uint32_t stroke=0;stroke<3;++stroke) {
        for (const auto &point:run.content->slashes) {
            if (point.claw!=claw || (stroke==2 && (point.sample==0 || point.sample==16))) continue;
            points.push_back(shot.pos+(across*point.x-u*point.y)*shot.radius);
        }
        offsets.push_back(points.size());widths.push_back(stroke==0?thickness*2.2:stroke==1?thickness:std::max(1.5/zoom,thickness*0.3));
        colors.push_back(stroke==0?Color(1.0,0.45,0.15,0.28):stroke==1?Color(1.0,0.55,0.22,0.95):Color(1.0,0.95,0.85,1.0));
    }
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;out.push_back(shape);
}
}
