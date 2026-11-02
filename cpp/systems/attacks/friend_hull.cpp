#include "friend_hull.h"
#include "../attack_system.h"
#include "../motion_math.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle FriendHullSystem::emit(RunRuntime &run,const FriendHullParams &p) {
    if (!run.state.started || run.state.closed || !run.state.combat_ready || run.content->friend_hulls.empty() || !p.position.is_finite() || !p.velocity.is_finite() || !std::isfinite(p.damage) || p.damage<0 || !std::isfinite(float(p.angle)) || p.source_id< -1 ||
        (!p.saw && (!p.source_definition || p.source_definition>run.content->definitions.size()))) return {};
    for (double v:{p.radius,p.life,p.knock}) if (!std::isfinite(float(v)) || v<0) return {};
    const auto &d=run.content->friend_hulls.front();godot::RunState::Friendly s;s.kind=int64_t(FriendKind::Hull);s.hull={1,p.source_definition,p.source_id,p.saw};
    s.pos=p.position;s.vel=p.velocity;s.radius=p.radius;s.damage=p.damage;s.life=p.life;s.pierce=true;s.no_crit=true;s.knock=p.saw?d.saw_knock:p.knock;
    s.angle=p.saw?p.velocity.angle():p.angle;s.spin=p.saw?d.saw_spin:0;s.cause=p.saw?"saw":"towShot";s.color=godot::Color::html(p.saw?"d9dde6":"ffbe65");
    if (p.source_id!=-1) s.hit_ids.insert(p.source_id);
    s.type=p.saw?godot::StringName("saw"):run.content->definitions[p.source_definition-1].source_id();s.visual=p.saw?godot::StringName():godot::StringName("weapon/massTow");
    AttackSpec spec;spec.cause=p.saw?Cause::Saw:Cause::TowShot;spec.policies=policy(EndPolicy::NaturalLifetime);spec.owner.source_id=std::max(int64_t(0),p.source_id);spec.owner.source_definition=p.source_definition;
    if (!AttackSystem::configure_contact(*run.content,d.contact,spec)) return {};
    return AttackSystem::emit_friendly(run,std::move(s),spec);
}
void FriendHullSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out,double alpha) {
    using namespace godot;const auto &s=run.state.friends[row];if (!s.alive || s.kind!=int64_t(FriendKind::Hull) || !view.grow(s.radius*2).has_point(s.pos)) return;
    const auto *record=AttackSystem::get(run.state,s.attack);if (!record || !s.hull.definition) return;
    const auto &d=run.content->friend_hulls[s.hull.definition-1];Vector2 position=s.pos;double rotation=s.angle;const auto &old=run.state.previous_poses;
    if (old.ready && row<old.friendly.size() && old.friendly[row].id==s.id) {position=old.friendly[row].position.lerp(s.pos,alpha);rotation=old.friendly[row].angle+angle_difference(double(s.angle)-old.friendly[row].angle)*alpha;}
    uint32_t visual=0;double radius=s.radius;
    if (!s.hull.saw) {
        const auto found=std::find_if(run.content->hull_looks.begin(),run.content->hull_looks.end(),[&](const auto &look){return look.enemy==s.hull.source_definition;});if (found==run.content->hull_looks.end()) return;
        visual=run.content->definitions[s.hull.source_definition-1].visual_id;radius*=found->scale;rotation=found->angle+(found->fixed_angle?0.0:double(s.vel.angle()));
    }
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::FriendHull);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;points.push_back(position);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(radius);PackedColorArray colors;
    colors.push_back(Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a)*(s.age<0.08?Color(1,1,1,1):s.age<0.18?Color::html("ffd27a"):Color(1,1,1,1)));
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["angle"]=rotation;shape["saw"]=s.hull.saw;shape["visual_id"]=int64_t(visual);shape["source_id"]=s.hull.source_id;
    PackedVector2Array teeth;if (s.hull.saw) for (const auto &point:run.content->saw_points) teeth.push_back(Vector2(point.x,point.y));shape["hull_points"]=teeth;out.push_back(shape);
}
}
