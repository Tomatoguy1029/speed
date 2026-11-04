#include "stomp.h"
#include "../flow/phase_controller.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/boss_contact.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <godot_cpp/variant/transform2d.hpp>
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusStompDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->centaurus_stomps.begin(),r.content->centaurus_stomps.end(),[&](const auto &p){return p.technique==t.definition;});}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);}
godot::Vector2 center(const RunRuntime &r,const TechniqueState &t) {
    const auto &e=r.state.enemies[t.actor.slot];const auto &p=r.content->boss_techniques[t.definition-1];double at=std::max(0.0,PhaseController::find(r,t.actor)->clock-t.started_at-p.warn);godot::Vector2 local;
    std::vector<const CentaurusStompFoot *> frames;for (const auto &f:r.content->centaurus_stomp_feet) if (f.technique==t.definition) frames.push_back(&f);
    size_t index=0;while (index+2<frames.size() && at>=frames[index]->duration) {at-=frames[index]->duration;index+=2;}
    for (size_t leg=0;leg<2;++leg) {
        const auto &a=*frames[index+leg];const auto &b=*frames[std::min(index+2+leg,frames.size()-2+leg)];const double f=a.interpolate?std::clamp(at/a.duration,0.0,1.0):0;
        const auto position=godot::Vector2(a.x,a.y).lerp(godot::Vector2(b.x,b.y),f);const auto scale=godot::Vector2(a.scale_x,a.scale_y).lerp(godot::Vector2(b.scale_x,b.scale_y),f);
        godot::Transform2D transform(a.rotation+angle_difference(b.rotation-a.rotation)*f,scale,a.skew+angle_difference(b.skew-a.skew)*f,position);
        if (a.pivot) transform.set_origin(godot::Vector2(a.origin_x,a.origin_y).lerp(godot::Vector2(b.origin_x,b.origin_y),b.pivot?f:0)-transform.basis_xform(godot::Vector2(a.pivot_x,a.pivot_y)));
        local+=transform.xform(godot::Vector2(a.contact_x,a.contact_y));
    }
    return e.pos+(local*0.5*e.radius/135.0).rotated(e.facing-godot::Math::PI*0.5);
}
}
bool CentaurusStomp::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && PhaseController::find(r,actor) && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusStomp::begin(RunRuntime &r,TechniqueState &t) {t.aim=r.state.ship_pos;t.started_at=PhaseController::find(r,t.actor)->clock;r.state.enemies[t.actor.slot].vel={};cue(r,t,"stomp_windup");}
void CentaurusStomp::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=r.content->boss_techniques[t.definition-1];
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) {t.started_at=0;t.stage=TechniqueStage::Finished;}return;}
    const double elapsed=PhaseController::find(r,t.actor)->clock-t.started_at;
    if (elapsed<p.warn) return;
    if (t.stage==TechniqueStage::Windup) {t.stage=TechniqueStage::Active;cue(r,t,"stomp");}
    if (elapsed>=p.warn+p.active) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;cue(r,t,"recovery_started");return;}
    const auto &v=rule(r,t);const auto offset=r.state.ship_pos-center(r,t);
    if (!t.hit && r.state.observations.check(t.observation_id,offset.length()<=v.radius+r.state.ship_config.ship_radius && std::abs(angle_difference(offset.angle()-e.facing))<=v.half_angle)) {ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=p.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::Stomp;request.source=e.definition+1;request.technique=t.definition;t.hit=CombatResolver::ship_damage(r,request).accepted;BossContactSystem::knock_back(r,t.actor);}
}
godot::Dictionary CentaurusStomp::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=rule(r,t);godot::Dictionary out;out["center"]=center(r,t);out["range_radius"]=v.radius;out["half_angle"]=v.half_angle;out["active_duration"]=p.active;out["pose_time"]=t.stage==TechniqueStage::Active?std::max(0.0,PhaseController::find(r,t.actor)->clock-t.started_at-p.warn):0.0;return out;}
}
