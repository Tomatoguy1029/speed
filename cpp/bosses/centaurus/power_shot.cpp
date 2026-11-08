#include "power_shot.h"
#include "../../output/event_builder.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/light_arrow.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusPowerDefinition &rule(const ContentBundle &c,const TechniqueState &t) {return *std::find_if(c.centaurus_powers.begin(),c.centaurus_powers.end(),[&](const auto &v){return v.technique==t.definition;});}
godot::Vector2 mouth(const RunRuntime &r,const TechniqueState &t) {
    const auto &e=r.state.enemies[t.actor.slot];const auto &p=r.content->boss_techniques[t.definition-1];
    const auto body=std::find_if(r.content->boss_bodies.begin(),r.content->boss_bodies.end(),[&](const auto &b){return b.boss==p.boss;});
    const auto &b=*std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &b){return b.body==body->id;});
    return e.pos+godot::Vector2::from_angle(e.facing)*e.radius*b.bow_reach;
}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {
    const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);
}
}
bool CentaurusPower::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusPower::begin(RunRuntime &r,TechniqueState &t) {t.detail=CentaurusPowerState{};t.aim=r.state.ship_pos;t.previous_ship=r.state.ship_pos;r.state.enemies[t.actor.slot].vel={};EventBuilder::audio(r,"boss.centaurus.bow_draw",r.state.enemies[t.actor.slot].pos);cue(r,t,"telegraph");}
void CentaurusPower::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=r.content->boss_techniques[t.definition-1];const auto &v=t.detail.get<CentaurusPowerState>();
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    if (v.alerting) e.facing=v.angle;
    else if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) {
        if (t.stage==TechniqueStage::Windup && !p.track_during_warn) {const auto &b=r.content->bosses[p.boss-1];e.facing+=std::clamp(angle_difference((t.aim-e.pos).angle()-e.facing),-b.turn*dt,b.turn*dt);}
        else e.facing=(r.state.ship_pos-e.pos).angle();
    }
}
void CentaurusPower::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    auto &v=t.detail.get<CentaurusPowerState>();const auto &p=r.content->boss_techniques[t.definition-1];const auto &power=rule(*r.content,t);auto &e=r.state.enemies[t.actor.slot];
    if (command==TechniqueCommand::AlertPower && t.stage==TechniqueStage::Windup) {v.origin=mouth(r,t);v.angle=e.facing;v.alerting=true;cue(r,t,"alert");}
    else if (command==TechniqueCommand::ReleaseArrow && (t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active)) {
        const auto from=v.alerting?v.origin:mouth(r,t);const auto target=p.track_during_warn?r.state.ship_pos:t.aim;
        const bool locked=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();const double angle=v.alerting?v.angle:locked?e.facing:(target-from).angle();
        for (uint32_t k=0;k<power.count;++k) {LightArrowParams shot;shot.position=from;shot.angle=angle+(double(k)-double(power.count-1)*0.5)*power.spread;shot.speed=p.speed;shot.radius=power.radius;shot.travel=power.travel;shot.damage=p.damage*r.state.combat_config.atk_scale;shot.cosmic=true;shot.owner=t.actor;shot.definition=power.projectile;shot.technique=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));LightArrowSystem::emit(r,shot);++v.released;}
        t.stage=TechniqueStage::Active;EventBuilder::audio(r,"boss.centaurus.bow_shot",r.state.enemies[t.actor.slot].pos);cue(r,t,"released");
    } else if (command==TechniqueCommand::FinishVolley && (t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active)) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;v.alerting=false;cue(r,t,"recovery_started");}
}
bool CentaurusPower::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=t.detail.get_if<CentaurusPowerState>();return v && v->origin.is_finite() && std::isfinite(v->angle) && v->released<=rule(c,t).count;}
godot::Dictionary CentaurusPower::snapshot(const RunRuntime &r,const TechniqueState &t) {
    const auto &p=rule(*r.content,t);const auto &v=t.detail.get<CentaurusPowerState>();godot::Dictionary out;out["alerting"]=v.alerting;out["released"]=v.released;out["locked_origin"]=v.origin;out["locked_angle"]=v.angle;out["travel"]=p.travel;
    if (r.state.enemy_handles.contains(t.actor)) {out["aim_origin"]=v.alerting?v.origin:mouth(r,t);out["aim_angle"]=v.alerting?v.angle:double(r.state.enemies[t.actor.slot].facing);}
    if (const auto *body=PhaseController::find(r,t.actor)) out["alert_age"]=body->clock-t.started_at-(r.content->boss_techniques[t.definition-1].warn-p.alert);
    out["ship_position"]=r.state.ship_pos;out["ship_radius"]=r.state.ship_config.ship_radius;
    godot::PackedFloat64Array offsets;for (uint32_t k=0;k<p.count;++k) offsets.push_back((double(k)-double(p.count-1)*0.5)*p.spread);out["offsets"]=offsets;return out;
}
}
