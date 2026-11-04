#include "flood.h"
#include <cmath>
#include "../attack_system.h"
#include "../../output/frame_builder.h"
namespace speed {
AttackHandle FloodSystem::emit(RunRuntime &run,const BeamParams &params) {
    if (run.content->floods.empty()) return {};
    auto beam=params;beam.style=BeamStyle::Flood;return BeamSystem::emit(run,beam);
}
void FloodSystem::render(const RunRuntime &run,uint32_t row,godot::Rect2 view,godot::Array &out) {
    using namespace godot;const auto &h=run.state.hazards[row];const auto *b=std::get_if<BeamHazard>(&h.shape);
    if (!h.alive || !b || b->style!=uint32_t(BeamStyle::Flood) || !view.grow(b->length*(1+std::abs(std::tan(b->arc)))).has_point(h.pos)) return;
    const auto *record=AttackSystem::get(run.state,h.attack);if (!record) return;const auto &d=run.content->floods.front();
    Dictionary shape;shape["kind"]=int32_t(RenderShapeKind::Flood);shape["layer"]=11;shape["order"]=int32_t(row);shape["owner_id"]=record->id;
    const auto source=record->spec.owner.source_definition;
    if (source && source<=run.content->definitions.size() && run.content->definitions[source-1].kind==EnemyDefinition::Kind::Aquarius) shape["reference_aquarius"]=true;
    PackedVector2Array points;points.push_back(h.pos);PackedInt32Array offsets;offsets.push_back(0);offsets.push_back(1);PackedFloat32Array widths;widths.push_back(b->half_width*2);PackedColorArray colors;colors.push_back(h.color);
    shape["points"]=points;shape["offsets"]=offsets;shape["widths"]=widths;shape["colors"]=colors;shape["time"]=double(h.time);shape["delay"]=double(h.delay);shape["active"]=double(h.duration);shape["angle"]=double(b->angle);shape["length"]=double(b->length);shape["spread"]=double(b->arc);shape["effect_group"]=b->flood_group;shape["margin"]=d.margin;out.push_back(shape);
}
void FloodSystem::end_visual(RunRuntime &run,const FloodTailState &f,int64_t id) {
    if (run.content->floods.empty()) return;const auto &d=run.content->floods.front();if (f.age>=d.tail) return;
    godot::Dictionary event;event["id"]=id;event["row"]=f.row;event["pos"]=f.pos;event["angle"]=f.angle;event["length"]=f.length;event["width"]=f.width;event["spread"]=f.spread;event["age"]=f.age;event["tail"]=d.tail;event["collapse"]=d.collapse;event["margin"]=d.margin;FrameBuilder::append(run,"flood_end",event);
}
}
