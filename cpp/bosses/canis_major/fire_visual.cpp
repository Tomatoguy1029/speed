#include "fire_visual.h"
#include "image_pose.h"
#include "../../systems/attack_system.h"
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <algorithm>
#include <cmath>

namespace speed {
namespace {
const CanisFireFxDefinition *config(const ContentBundle &content,uint32_t technique) {
    const auto it=std::find_if(content.canis_fire_fx.begin(),content.canis_fire_fx.end(),[&](const auto &v){return v.technique==technique;});
    return it==content.canis_fire_fx.end()?nullptr:&*it;
}
int64_t action(const RunRuntime &r,const BossBodyState &body,uint32_t technique) {
    for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,body.actor) && t.definition==technique && t.stage<TechniqueStage::Finished) return t.id;
    return 0;
}
}
void CanisFireVisualSystem::begin(RunRuntime &r,BossBodyState &body,AttackHandle handle,uint32_t technique,EnemyHandle hound) {
    const auto *fx=config(*r.content,technique);const auto *attack=AttackSystem::get(r.state,handle);
    if (!fx || !attack || attack->row>=r.state.hazards.size()) return;
    const auto &hazard=r.state.hazards[attack->row];const auto *source=std::get_if<CanisFlameHazard>(&hazard.shape);
    if (!source || source->kind!=CanisFlameHazard::Kind::Jet || !source->definition || source->definition>r.content->canis_flames.size()) return;
    const auto &def=r.content->canis_flames[source->definition-1];auto &state=body.canis.fire_visual;
    const int64_t owner=action(r,body,technique);
    if (state.action!=owner) {state.action=owner;state.next_ordinal=0;}
    CanisFireVisual visual;visual.id=attack->id;visual.action=owner;visual.technique=technique;visual.profile=source->definition;visual.ordinal=state.next_ordinal++;
    visual.hound=hound;visual.hound_jet=hound.generation && fx->has_hound_jet;
    visual.origin=hazard.pos;visual.angle=source->angle;visual.length=def.length*(visual.hound_jet?fx->hound_jet_length:fx->jet_length);
    visual.width=def.width*(visual.hound_jet?fx->hound_jet_width:fx->jet_width);
    visual.started=body.clock;visual.duration=def.duration;visual.speed=visual.hound_jet && fx->has_hound_speed?fx->hound_speed:1;
    visual.has_footprint=fx->external_id=="O-relay" || fx->external_id=="O-hunt";
    visual.history.origin=visual.origin;visual.history.angle=visual.angle;visual.history.started=visual.started;
    state.jets.push_back(std::move(visual));
}
void CanisFireVisualSystem::tick(RunRuntime &r,BossBodyState &body) {
    auto &jets=body.canis.fire_visual.jets;const auto &camera=r.state.control;
    if (!(camera.logical_size.x>0 && camera.logical_size.y>0 && camera.camera_zoom>0)) return;
    constexpr int height=225;const int width=std::max(1,int(std::lround(camera.logical_size.x/camera.logical_size.y*height)));
    const double scale=camera.camera_zoom*height/camera.logical_size.y,cell=1.0/scale;
    const auto view_origin=camera.camera_center-godot::Vector2(width*cell,height*cell)*0.5;
    const int64_t frame=int64_t(std::floor(body.clock*60.0+1e-8));
    for (auto &jet:jets) {
        const auto *fx=config(*r.content,jet.technique);if (!fx) continue;
        const bool sampled=jet.frame!=frame;
        if (!sampled && jet.field_origin==view_origin && jet.cell==cell && jet.field_width==uint32_t(width) && jet.field_height==height) continue;
        const double age=body.clock-jet.started;
        auto source=jet.origin;
        if (!jet.hound_jet && age<=jet.duration) source=CanisImagePose::mouth(r,body);
        const auto logical=(source-view_origin)*scale;
        CanisFireFieldInput input;input.world_scale=scale;input.origin_x=logical.x;input.origin_y=logical.y;input.angle=jet.angle;
        input.length=jet.length*fx->size;input.width=fx->size*(jet.hound_jet?fx->hound_jet_width:fx->jet_width);
        input.age=age;input.duration=jet.duration;input.alpha=std::min(1.0,fx->intensity);input.seed=int32_t(5+jet.ordinal*13);
        input.speed_rate=jet.speed;input.spikes=fx->jet_spikes;input.logical_width=width;input.logical_height=height;
        jet.pixels=CanisFireField::raster(input);jet.frame=frame;jet.field_origin=view_origin;jet.cell=cell;jet.field_width=width;jet.field_height=height;
        if (sampled && jet.has_footprint && age>=0 && age<=jet.duration+.22/jet.speed) jet.history.stamp(jet.pixels,view_origin,scale,body.clock);
    }
    // 1.0+hash*1.8秒の最長寿命と、その後のすす0.8秒を保持する。
    jets.erase(std::remove_if(jets.begin(),jets.end(),[&](const auto &jet){return body.clock-jet.started>jet.duration+.22/jet.speed+3.6;}),jets.end());
}
godot::Array CanisFireVisualSystem::snapshot(const RunRuntime &r,const BossBodyState &body) {
    godot::Array out;
    for (const auto &jet:body.canis.fire_visual.jets) {
        const auto *fx=config(*r.content,jet.technique);if (!fx) continue;
        godot::Dictionary q;q["id"]=jet.id;q["settings"]=godot::String::utf8(fx->external_id.c_str());q["started"]=jet.started;q["duration"]=jet.duration;q["speed"]=jet.speed;
        q["field_origin"]=jet.field_origin;q["cell"]=jet.cell;q["history_cell"]=jet.history.cell;
        godot::PackedInt32Array pixels;pixels.resize(jet.pixels.size()*3);
        for (size_t i=0;i<jet.pixels.size();++i) {pixels.set(i*3,jet.pixels[i].x);pixels.set(i*3+1,jet.pixels[i].y);pixels.set(i*3+2,jet.pixels[i].layer);}q["pixels"]=pixels;
        godot::PackedInt64Array footprint;footprint.resize(jet.history.footprint.size());size_t n=0;for (auto key:jet.history.footprint) footprint.set(n++,int64_t(key));q["footprint"]=footprint;
        godot::Array deposits;for (const auto &d:jet.history.deposits) {godot::Dictionary row;row["position"]=d.position;row["updated"]=d.updated;row["seed"]=int64_t(d.seed);godot::PackedVector2Array points;points.resize(d.pixels.size());for (size_t i=0;i<d.pixels.size();++i) points.set(i,d.pixels[i]);row["pixels"]=points;deposits.push_back(row);}q["deposits"]=deposits;
        out.push_back(q);
    }
    return out;
}
void CanisFireVisualSystem::clear(BossBodyState &body) {body.canis.fire_visual={};}
bool CanisFireVisualSystem::validate(const BossBodyState &body,const ContentBundle &content) {
    for (const auto &v:body.canis.fire_visual.jets) {
        if (v.id<=0 || !config(content,v.technique) || !v.origin.is_finite() || !v.field_origin.is_finite() || v.length<0 || v.width<0 || v.duration<=0 || v.speed<=0) return false;
        for (double x:{v.angle,v.length,v.width,v.started,v.duration,v.speed,v.cell,v.history.cell}) if (!std::isfinite(x)) return false;
        for (const auto &d:v.history.deposits) {if (!d.position.is_finite() || !std::isfinite(d.updated)) return false;for (auto p:d.pixels) if (!p.is_finite()) return false;}
    }
    return true;
}
}
