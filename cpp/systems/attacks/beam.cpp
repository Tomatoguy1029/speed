#include "beam.h"
#include "../attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle BeamSystem::emit(RunRuntime &run,const BeamParams &p) {
    if (!run.state.started || run.state.closed || !p.position.is_finite() || run.content->beams.empty() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    for (double value:{p.length,p.half_width,p.delay,p.active,p.damage}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.length,p.half_width,p.delay,p.active,p.angle,p.arc}) if (!std::isfinite(float(value))) return {};
    for (float channel:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(channel)) return {};
    HazardState hazard;hazard.pos=p.position;hazard.delay=p.delay;hazard.duration=p.active;hazard.damage=p.damage;hazard.color=p.color;
    hazard.shape=BeamHazard{float(p.angle),float(p.length),float(p.half_width),float(p.arc),1};
    AttackSpec spec;spec.cause=Cause::Beam;spec.owner.live_source=p.owner;spec.owner.attached=p.owner.generation>0;spec.owner.budget=p.budget;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (p.owner.generation) spec.policies|=policy(EndPolicy::CancelWithParticipant);
    if (!AttackSystem::configure_contact(*run.content,run.content->beams.front().contact,spec)) return {};
    return AttackSystem::emit_hazard(run.state,hazard,spec);
}
bool BeamSystem::move(RunRuntime &run,AttackHandle handle,godot::Vector2 position,double angle,std::optional<double> length) {
    const auto *record=AttackSystem::get(run.state,handle);
    if (!record || record->pool!=AttackPool::Hazard || !position.is_finite() || !std::isfinite(float(angle)) ||
        (length && (!std::isfinite(float(*length)) || *length<0))) return false;
    auto &hazard=run.state.hazards[record->row];auto *beam=std::get_if<BeamHazard>(&hazard.shape);if (!beam) return false;
    hazard.pos=position;beam->angle=angle;if (length) beam->length=*length;return true;
}
ContactShape BeamSystem::geometry(const HazardState &hazard) {
    const auto &beam=std::get<BeamHazard>(hazard.shape);
    if (beam.arc>0) return TaperedBeam{hazard.pos,beam.angle,beam.length,beam.half_width,beam.arc};
    return SegmentCircle{hazard.pos,hazard.pos+godot::Vector2::from_angle(beam.angle)*beam.length,beam.half_width};
}
void BeamSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &shapes) {
    using namespace godot;
    const auto &hazard=run.state.hazards[row];const auto *beam=std::get_if<BeamHazard>(&hazard.shape);if (!hazard.alive || !beam) return;
    const auto *record=AttackSystem::get(run.state,hazard.attack);if (!record) return;
    const double zoom=std::max(0.01,run.state.control.camera_zoom);const bool charging=hazard.time<hazard.delay;
    if (!charging && !view.grow(beam->length).has_point(hazard.pos)) return;
    Dictionary shape;shape["kind"]=int32_t(charging?RenderShapeKind::Circle:RenderShapeKind::Polyline);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    PackedVector2Array points;PackedInt32Array offsets;PackedFloat32Array widths;PackedColorArray colors;offsets.push_back(0);
    if (charging) {
        const double k=std::clamp(double(hazard.time)/std::max(0.001,double(hazard.delay)),0.0,1.0);
        points.push_back(hazard.pos);offsets.push_back(1);widths.push_back(4.0/zoom+10.0*k);
        auto color=hazard.color;color.a=0.25+0.5*k;colors.push_back(color);
    } else {
        const auto to=hazard.pos+Vector2::from_angle(beam->angle)*beam->length;
        const double fade=1.0-std::clamp(double(hazard.time-hazard.delay)/std::max(0.001,double(hazard.duration)),0.0,1.0)*0.6;
        const double full_width=beam->half_width*2.0;
        const double sizes[]={full_width*1.6,full_width,std::max(2.0/zoom,full_width*0.3)};
        Color palette[]={hazard.color,hazard.color,Color(1,1,1,1)};const double alpha[]={0.35,0.9,0.85};
        for (int i=0;i<3;++i) {points.push_back(hazard.pos);points.push_back(to);offsets.push_back(points.size());widths.push_back(sizes[i]);palette[i].a=alpha[i]*fade;colors.push_back(palette[i]);}
    }
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shapes.push_back(shape);
}
}
