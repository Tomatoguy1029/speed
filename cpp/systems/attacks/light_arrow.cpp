#include "light_arrow.h"
#include "../attack_system.h"
#include "../combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle LightArrowSystem::emit(RunRuntime &run,const LightArrowParams &p) {
    if (!run.state.started || run.state.closed || !p.position.is_finite() || !std::isfinite(p.angle) ||
        p.speed<=0 || p.radius<=0 || p.travel<=0 || p.damage<0 || (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    for (double v:{p.speed,p.radius,p.travel,p.length}) if (!std::isfinite(float(v))) return {};
    if (!std::isfinite(p.damage)) return {};
    if (p.definition>run.content->light_arrows.size()) return {};
    const auto found=p.definition?run.content->light_arrows.begin()+p.definition-1:std::find_if(run.content->light_arrows.begin(),run.content->light_arrows.end(),[&](const auto &d){return d.cosmic==p.cosmic;});
    if (found==run.content->light_arrows.end()) return {};
    godot::RunState::Hostile shot;shot.kind=int64_t(p.cosmic?HostileKind::CosmicArrow:HostileKind::LightArrow);
    shot.arrow={uint32_t(found-run.content->light_arrows.begin()+1),float(std::max(0.0,p.length))};shot.pos=p.position;
    shot.vel=godot::Vector2::from_angle(p.angle)*p.speed;shot.speed=p.speed;shot.radius=p.radius;shot.life=p.travel/p.speed;shot.damage=p.damage;
    if (!std::isfinite(shot.life)) return {};
    AttackSpec spec;spec.cause=Cause::Arrow;spec.technique=p.technique;if (run.state.bosses->handles.contains(p.technique)) spec.source_technique=run.state.bosses->techniques[p.technique.slot].definition;spec.owner.live_source=p.owner;spec.owner.budget=p.budget;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (!AttackSystem::configure_contact(*run.content,found->contact,spec)) return {};
    const auto handle=AttackSystem::emit_hostile(run.state,shot,spec);
    if (AttackSystem::get(run.state,handle)) {godot::Dictionary event;event["pos"]=p.position;event["kind"]=godot::StringName("arrow");FrameBuilder::append(run,"shoot",event);}return handle;
}
std::optional<double> LightArrowSystem::contact(RunRuntime &run,AttackHandle handle,godot::Vector2 from,godot::Vector2 to,double step,std::optional<double> body_t) {
    const auto *record=AttackSystem::get(run.state,handle);if (!record || record->pool!=AttackPool::Hostile) return {};
    const auto &shot=run.state.hostiles[record->row];const double length=shot.arrow.length,reach=shot.radius+run.state.ship_config.ship_radius+step+length;
    if (run.state.ship.pos.distance_squared_to(to)>reach*reach) return {};
    const auto tail=from-shot.vel.normalized()*length;
    const double t=CollisionQuery::segment_circle_t(tail,to,run.state.ship.pos,shot.radius+run.state.ship_config.ship_radius);
    if (t<0) {run.state.observations.effect_check(record->id,false);return {};}const double arrival=step>0?std::max(0.0,(t*(step+length)-length)/step):0;
    if (body_t && arrival>=*body_t) return {};
    const auto result=CombatResolver::attack_ship_damage(run,handle,SegmentCircle{tail,to,double(shot.radius)},shot.damage,0);
    return result.touching?std::optional<double>(arrival):std::nullopt;
}
void LightArrowSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &s=run.state.hostiles[row];if (!s.alive || !s.arrow.definition || !view.has_point(s.pos)) return;
    const auto *record=AttackSystem::get(run.state,s.attack);if (!record) return;const auto &d=run.content->light_arrows[s.arrow.definition-1];
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::LightArrow);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;points.push_back(s.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(s.radius*d.flight_scale);PackedColorArray colors;colors.push_back(Color(d.tint_r,d.tint_g,d.tint_b,d.tint_a));
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;
    shape["petrified_radius"]=s.stone>0?double(s.radius)*1.3:0.0;
    const auto technique=record->spec.source_technique;
    const bool power_shot=technique && technique<=run.content->boss_techniques.size() && run.content->boss_techniques[technique-1].kind==11;
    shape["angle"]=double(s.vel.angle());shape["length"]=s.arrow.length*d.flight_scale;shape["world_time"]=run.state.world_time;shape["cosmic"]=d.cosmic && !power_shot;
    shape["shot_length_scale"]=d.shot_length_scale;shape["shot_width_scale"]=d.shot_width_scale;shape["core_width"]=d.core_width;shape["cosmic_speed"]=d.cosmic_speed;shape["cosmic_star_count"]=int64_t(d.cosmic_star_count);
    shape["arrow_color"]=Color(d.arrow_r,d.arrow_g,d.arrow_b,d.arrow_a);shape["cosmic_color_a"]=Color(d.cosmic_a_r,d.cosmic_a_g,d.cosmic_a_b,d.cosmic_a_a);shape["cosmic_color_b"]=Color(d.cosmic_b_r,d.cosmic_b_g,d.cosmic_b_b,d.cosmic_b_a);
    out.push_back(shape);
}
}
