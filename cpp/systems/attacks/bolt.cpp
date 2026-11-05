#include "bolt.h"
#include "../attack_system.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <cmath>
namespace speed {
AttackHandle BoltSystem::emit(RunRuntime &run,const BoltParams &p) {
    if (!run.state.started || run.state.closed || run.content->bolts.empty() || p.definition>run.content->bolts.size() || !p.position.is_finite() || !std::isfinite(p.angle) ||
        !std::isfinite(float(p.speed)) || p.speed<0 || !std::isfinite(p.damage) || p.damage<0 ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    const auto &definition=run.content->bolts[p.definition?p.definition-1:0];
    godot::RunState::Hostile shot;shot.kind=int64_t(HostileKind::Bolt);shot.bolt.definition=p.definition?p.definition:1;
    shot.pos=p.position;shot.vel=godot::Vector2::from_angle(p.angle)*p.speed;shot.speed=p.speed;
    shot.radius=definition.radius;shot.life=definition.life;shot.damage=p.damage;
    AttackSpec spec;spec.cause=Cause::Bolt;spec.technique=p.technique;if (run.state.bosses->handles.contains(p.technique)) spec.source_technique=run.state.bosses->techniques[p.technique.slot].definition;spec.owner.live_source=p.owner;spec.owner.budget=p.budget;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (!AttackSystem::configure_contact(*run.content,definition.contact,spec)) return {};
    const auto handle=AttackSystem::emit_hostile(run.state,shot,spec);
    if (AttackSystem::get(run.state,handle)) {godot::Dictionary event;event["pos"]=p.position;event["kind"]=godot::StringName("bolt");FrameBuilder::append(run,"shoot",event);}
    return handle;
}
void BoltSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &shot=run.state.hostiles[row];
    if (!shot.alive || !shot.bolt.definition || !view.has_point(shot.pos)) return;
    const auto *record=AttackSystem::get(run.state,shot.attack);if (!record) return;
    const auto &definition=run.content->bolts[shot.bolt.definition-1];
    const auto direction=shot.vel.normalized()*definition.flight_scale;
    const Color tint(definition.tint_r,definition.tint_g,definition.tint_b,definition.tint_a);
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Polyline);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    if (shot.bolt.reference_soldier) shape["reference_soldier_bolt"]=true;
    shape["behind_parent"]=shot.stone>0;
    PackedVector2Array points;PackedInt32Array offsets;PackedFloat32Array widths;PackedColorArray colors;offsets.push_back(0);
    const double back[]={34,30,24},front[]={6,4,2},width[]={14,6,2.5};
    const Color palette[]={Color(0.75,0.6,1,0.35),Color(0.85,0.75,1,1),Color(1,1,1,0.95)};
    for (int i=0;i<3;++i) {
        points.push_back(shot.pos-direction*back[i]);points.push_back(shot.pos+direction*front[i]);offsets.push_back(points.size());
        widths.push_back(width[i]*definition.flight_scale);colors.push_back(palette[i]*tint);
    }
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;out.push_back(shape);
    if (shot.stone>0) {
        Dictionary stone=shape.duplicate();stone["kind"]=int32_t(RenderShapeKind::Circle);
        stone.erase("reference_soldier_bolt");
        PackedVector2Array p;p.push_back(shot.pos);PackedInt32Array o;o.push_back(0);o.push_back(1);PackedFloat32Array r;r.push_back(shot.radius*1.3);PackedColorArray c;c.push_back(Color(0.62,0.6,0.58,0.9));
        stone["points"]=p;stone["offsets"]=o;stone["widths"]=r;stone["colors"]=c;out.push_back(stone);
    }
}
}
