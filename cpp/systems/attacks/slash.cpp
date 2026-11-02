#include "slash.h"
#include "../attack_system.h"
#include "../collision_query.h"
#include "../combat_resolver.h"
#include "../../output/event_builder.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle SlashSystem::emit(RunRuntime &run,const SlashParams &p) {
    if (!run.state.started || run.state.closed || run.content->slashes.empty() || !p.position.is_finite() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner)) || (p.side!=1 && p.side!=-1) || p.size<=0 || !std::isfinite(p.angle)) return {};
    for (double value:{p.speed,p.size,p.range,p.damage}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.speed,p.size,p.range}) if (!std::isfinite(float(value))) return {};
    godot::RunState::Hostile shot;shot.kind=int64_t(HostileKind::Slash);shot.pos=p.position;
    shot.vel=godot::Vector2::from_angle(p.angle)*p.speed;shot.speed=p.speed;shot.radius=p.size;
    shot.life=p.range/std::max(p.speed,1.0);shot.damage=p.damage;shot.slash={1,float(p.side)};
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
    const auto &shot=run.state.hostiles[record->row];
    if (!shot.slash.definition || !touches(*run.content,to,shot.vel.angle(),shot.radius,shot.slash.side,run.state.ship.pos,run.state.ship_config.ship_radius)) return false;
    const auto spec=record->spec;
    ShipDamageRequest request;request.amount=shot.damage;request.scale=spec.contact.scale;request.hit_policy=spec.contact.hit_policy;
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
