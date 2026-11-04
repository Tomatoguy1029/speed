#include "beam.h"
#include "../attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
AttackHandle BeamSystem::emit(RunRuntime &run,const BeamParams &p) {
    if (!run.state.started || run.state.closed || p.style>=BeamStyle::Count || !p.position.is_finite() || run.content->beams.empty() || p.definition>run.content->beams.size() ||
        (p.owner.generation && !run.state.enemy_handles.contains(p.owner))) return {};
    for (double value:{p.length,p.half_width,p.delay,p.active,p.damage}) if (!std::isfinite(value) || value<0) return {};
    for (double value:{p.length,p.half_width,p.delay,p.active,p.angle,p.arc}) if (!std::isfinite(float(value))) return {};
    for (float channel:{p.color.r,p.color.g,p.color.b,p.color.a}) if (!std::isfinite(channel)) return {};
    HazardState hazard;hazard.pos=p.position;hazard.delay=p.delay;hazard.duration=p.active;hazard.damage=p.damage;hazard.color=p.color;
    hazard.shape=BeamHazard{float(p.angle),float(p.length),float(p.half_width),float(p.arc),p.definition?p.definition:1,uint32_t(p.style)};
    AttackSpec spec;spec.cause=Cause::Beam;spec.technique=p.technique;if (run.state.bosses.handles.contains(p.technique)) spec.source_technique=run.state.bosses.techniques[p.technique.slot].definition;spec.owner.live_source=p.owner;spec.owner.attached=p.owner.generation>0 && p.attached;spec.owner.budget=p.budget;
    spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (p.owner.generation && p.attached) spec.policies|=policy(EndPolicy::CancelWithParticipant);
    if (!AttackSystem::configure_contact(*run.content,run.content->beams[p.definition?p.definition-1:0].contact,spec)) return {};
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
    const auto &hazard=run.state.hazards[row];const auto *beam=std::get_if<BeamHazard>(&hazard.shape);if (!hazard.alive || !beam || beam->style==uint32_t(BeamStyle::Flood)) return;
    const auto *record=AttackSystem::get(run.state,hazard.attack);if (!record) return;
    if (beam->style==uint32_t(BeamStyle::Draco)) {
        Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Polyline);shape["layer"]=11;shape["order"]=int32_t(row);shape["owner_id"]=record->id;shape["draco_beam"]=true;
        PackedVector2Array points;points.push_back(hazard.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(beam->half_width);PackedColorArray colors;colors.push_back(hazard.color);
        shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["time"]=double(hazard.time);shape["delay"]=double(hazard.delay);shape["active"]=double(hazard.duration);shape["angle"]=double(beam->angle);shape["length"]=double(beam->length);shape["clock"]=run.state.world_time;shapes.push_back(shape);return;
    }
    const double zoom=std::max(0.01,run.state.control.camera_zoom);const bool charging=hazard.time<hazard.delay;
    if (!charging && !view.grow(beam->length).has_point(hazard.pos)) return;
    Dictionary shape;shape["kind"]=int32_t(charging?RenderShapeKind::Circle:RenderShapeKind::Polyline);shape["layer"]=10;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    const auto source=record->spec.owner.source_definition;
    if (source && source<=run.content->definitions.size() && run.content->definitions[source-1].kind==EnemyDefinition::Kind::Beamer) shape["reference_beamer"]=true;
    if (source && source<=run.content->definitions.size() && run.content->definitions[source-1].kind==EnemyDefinition::Kind::Cross) shape["reference_cross"]=true;
    if (source && source<=run.content->definitions.size() && run.content->definitions[source-1].kind==EnemyDefinition::Kind::Sniper && beam->style==uint32_t(BeamStyle::Telescope)) shape["reference_telescope"]=true;
    if (charging && beam->style==uint32_t(BeamStyle::Guide) && view.grow(beam->length).has_point(hazard.pos)) {
        const double k=std::clamp(double(hazard.time)/std::max(0.001,double(hazard.delay)),0.0,1.0);
        Dictionary guide=shape.duplicate();guide["kind"]=int32_t(RenderShapeKind::Polyline);guide["behind_parent"]=true;
        PackedVector2Array path;path.push_back(hazard.pos);path.push_back(hazard.pos+Vector2::from_angle(beam->angle)*beam->length);
        PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(2);PackedFloat32Array widths;widths.push_back(1.5/zoom);
        auto color=hazard.color;color.a=0.2+0.5*k;PackedColorArray colors;colors.push_back(color);
        guide["points"]=path;guide["offsets"]=offsets;guide["widths"]=widths;guide["colors"]=colors;shapes.push_back(guide);
    }
    PackedVector2Array points;PackedInt32Array offsets;PackedFloat32Array widths;PackedColorArray colors;offsets.push_back(0);
    if (charging) {
        const double k=std::clamp(double(hazard.time)/std::max(0.001,double(hazard.delay)),0.0,1.0);
        points.push_back(hazard.pos);offsets.push_back(1);widths.push_back(4.0/zoom+10.0*k);
        auto color=hazard.color;color.a=0.25+0.5*k;colors.push_back(color);
    } else {
        const auto to=hazard.pos+Vector2::from_angle(beam->angle)*beam->length;
        double fade=1.0-std::clamp(double(hazard.time-hazard.delay)/std::max(0.001,double(hazard.duration)),0.0,1.0)*0.6;
        if (beam->style==uint32_t(BeamStyle::Telescope)) {const double edge=std::min(0.08,double(hazard.duration));const double k=std::clamp((double(hazard.delay)+hazard.duration-hazard.time)/std::max(0.001,edge),0.0,1.0);fade*=k*k*(3.0-2.0*k);shape["rounded"]=true;}
        const double full_width=beam->half_width*2.0;
        const double sizes[]={full_width*1.6,full_width,std::max(2.0/zoom,full_width*0.3)};
        Color palette[]={hazard.color,hazard.color,Color(1,1,1,1)};const double alpha[]={0.35,0.9,0.85};
        for (int i=0;i<3;++i) {points.push_back(hazard.pos);points.push_back(to);offsets.push_back(points.size());widths.push_back(sizes[i]);palette[i].a=alpha[i]*fade;colors.push_back(palette[i]);}
    }
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shapes.push_back(shape);
}
}
