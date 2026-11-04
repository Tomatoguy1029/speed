#include "fire_visual.h"
#include "image_pose.h"
#include "../../systems/attack_system.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
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
    for (const auto &t:r.state.bosses->techniques) if (same_handle(t.actor,body.actor) && t.definition==technique && t.stage<TechniqueStage::Finished) return t.id;
    return 0;
}
}
const CanisFireFxDefinition *CanisFireVisualSystem::settings(const ContentBundle &content,uint32_t technique) {return config(content,technique);}
void CanisFireVisualSystem::begin_continuous(RunRuntime &r,BossBodyState &body,const TechniqueState &t,double duration) {
    const auto *fx=config(*r.content,t.definition);if (!fx || fx->external_id!="O-sirius_flame" || duration<=0) return;
    CanisFireVisual visual;visual.id=-t.id;visual.action=t.id;visual.technique=t.definition;visual.started=body.clock;visual.duration=duration;visual.continuous=true;visual.has_footprint=true;
    const auto &enemy=r.state.enemies[body.actor.slot];visual.origin=enemy.pos+godot::Vector2::from_angle(enemy.facing)*enemy.radius*.84;
    visual.history.origin=visual.origin;visual.history.angle=enemy.facing;visual.history.started=visual.started;
    body.canis.fire_visual.jets.push_back(std::move(visual));
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
    const auto *trail=AttackSystem::get(r.state,source->trail);visual.trail_id=trail?trail->id:0;
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
        if (sampled) jet.sample_age=body.clock-jet.started;
        const double age=jet.sample_age;
        if (sampled && jet.continuous && age<jet.duration) {
            const bool active=std::any_of(r.state.bosses->techniques.begin(),r.state.bosses->techniques.end(),[&](const auto &t){return t.id==jet.action && same_handle(t.actor,body.actor) && t.stage==TechniqueStage::Active;});
            if (!active) jet.duration=std::max(0.0,age);
        }
        if (sampled && !jet.continuous && age<jet.duration) {
            const auto it=std::find_if(r.state.hazards.begin(),r.state.hazards.end(),[&](const auto &h){const auto *record=h.alive?AttackSystem::get(r.state,h.attack):nullptr;return record && record->id==jet.id;});
            const auto *source=it==r.state.hazards.end()?nullptr:std::get_if<CanisFlameHazard>(&it->shape);
            if (!source || source->source_ended) jet.duration=std::max(0.0,age);
        }
        auto source=jet.origin;double angle=jet.angle,length=jet.length;
        if (jet.continuous) {
            if (age<=jet.duration && r.state.enemy_handles.contains(body.actor)) {
                source=CanisImagePose::mouth(r,body);angle=r.state.enemies[body.actor.slot].facing;
                const auto forward=godot::Vector2::from_angle(angle);length=0;
                for (const auto &hazard:r.state.hazards) if (hazard.alive) {
                    const auto *flame=std::get_if<CanisFlameHazard>(&hazard.shape);const auto *record=AttackSystem::get(r.state,hazard.attack);
                    if (!flame || !record || flame->kind!=CanisFlameHazard::Kind::Particle || !flame->harmful || flame->jet.generation || record->spec.source_technique!=jet.technique) continue;
                    length=std::max(length,double((hazard.pos-source).dot(forward))+flame->radius);
                }
                jet.release_origin=source;jet.release_angle=angle;jet.release_length=length;jet.has_release=true;
            } else if (jet.has_release) {source=jet.release_origin;angle=jet.release_angle;length=jet.release_length;}
            else continue;
        } else if (!jet.hound_jet && age<=jet.duration) source=CanisImagePose::mouth(r,body);
        const auto logical=(source-view_origin)*scale;
        CanisFireFieldInput input;input.world_scale=scale;input.origin_x=logical.x;input.origin_y=logical.y;input.angle=angle;
        input.length=length*fx->size;input.width=fx->size*(jet.hound_jet?fx->hound_jet_width:fx->jet_width);
        input.age=age;input.duration=jet.duration;input.alpha=std::min(1.0,fx->intensity);input.seed=jet.continuous?11:int32_t(5+jet.ordinal*13);
        input.speed_rate=jet.speed;input.spikes=fx->jet_spikes;input.logical_width=width;input.logical_height=height;
        jet.pixels=CanisFireField::raster(input);jet.frame=frame;jet.field_origin=view_origin;jet.cell=cell;jet.field_width=width;jet.field_height=height;
        if (sampled && age>=0 && age<=jet.duration+.22/jet.speed) {
            if (jet.has_footprint) jet.history.stamp(jet.pixels,view_origin,scale,body.clock);
            else if (fx->external_id=="O-sirius") for (const auto &hazard:r.state.hazards) if (hazard.alive) {
                const auto *flame=std::get_if<CanisFlameHazard>(&hazard.shape);
                if (!flame || flame->kind!=CanisFlameHazard::Kind::Particle || !flame->jet.generation || flame->age>flame->life) continue;
                const auto *owner=AttackSystem::get(r.state,flame->jet);
                if (owner && owner->id==jet.id) jet.history.deposit(hazard.pos,body.clock,false);
            }
        }
    }
    // 1.0+hash*1.8秒の最長寿命と、その後のすす0.8秒を保持する。
    jets.erase(std::remove_if(jets.begin(),jets.end(),[&](const auto &jet){return body.clock-jet.started>jet.duration+.22/jet.speed+3.6;}),jets.end());
}
godot::Array CanisFireVisualSystem::snapshot(const RunRuntime &r,const BossBodyState &body) {
    godot::Array out;
    for (const auto &jet:body.canis.fire_visual.jets) {
        const auto *fx=config(*r.content,jet.technique);if (!fx) continue;
        godot::Dictionary q;q["id"]=jet.id;q["trail_id"]=jet.trail_id;q["technique"]=jet.technique;q["continuous"]=jet.continuous;q["settings"]=godot::String::utf8(fx->external_id.c_str());q["started"]=jet.started;q["duration"]=jet.duration;q["speed"]=jet.speed;
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
        if (!v.id || !config(content,v.technique) || !v.origin.is_finite() || !v.field_origin.is_finite() || !v.release_origin.is_finite() || v.length<0 || v.width<0 || v.duration<0 || v.speed<=0) return false;
        for (double x:{v.angle,v.length,v.width,v.started,v.duration,v.speed,v.cell,v.history.cell,v.release_angle,v.release_length,v.sample_age}) if (!std::isfinite(x)) return false;
        for (const auto &d:v.history.deposits) {if (!d.position.is_finite() || !std::isfinite(d.updated)) return false;for (auto p:d.pixels) if (!p.is_finite()) return false;}
    }
    return true;
}
}
