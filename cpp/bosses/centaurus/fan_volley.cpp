#include "fan_volley.h"
#include "../flow/phase_controller.h"
#include "../../systems/attacks/light_arrow.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include <algorithm>
namespace speed {
namespace {
const CentaurusFanDefinition &rule(const ContentBundle &c,const TechniqueState &t) {return *std::find_if(c.centaurus_fans.begin(),c.centaurus_fans.end(),[&](const auto &v){return v.technique==t.definition;});}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);}
}
bool CentaurusFan::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && PhaseController::find(r,actor) && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusFan::begin(RunRuntime &r,TechniqueState &t) {t.detail=CentaurusVolleyState{};t.started_at=PhaseController::find(r,t.actor)->clock;t.aim=r.state.enemy_aim;r.state.enemies[t.actor.slot].vel={};cue(r,t,"fan_windup");}
void CentaurusFan::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=r.content->boss_techniques[t.definition-1];
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    const auto target=p.track_during_warn?r.state.enemy_aim:t.aim;const auto &d=r.content->bosses[p.boss-1];
    if (!tracking.locked()) e.facing+=std::clamp(angle_difference((target-e.pos).angle()-e.facing),-d.turn*dt,d.turn*dt);
    const double elapsed=PhaseController::find(r,t.actor)->clock-t.started_at;if (elapsed<p.warn) return;
    const auto &v=rule(*r.content,t);auto &fired=std::get<CentaurusVolleyState>(t.detail).released;t.stage=TechniqueStage::Active;
    const auto body=std::find_if(r.content->boss_bodies.begin(),r.content->boss_bodies.end(),[&](const auto &b){return b.boss==p.boss;});
    const auto &b=*std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &b){return b.body==body->id;});
    while (fired<v.shots && elapsed>=p.warn+fired*v.interval) {
        const auto mouth=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*b.bow_reach;const double angle=tracking.locked()?e.facing:(r.state.enemy_aim-mouth).angle();
        for (uint32_t k=0;k<v.count;++k) {LightArrowParams shot;shot.position=mouth;shot.angle=angle+(v.count>1?(double(k)/double(v.count-1)-0.5)*v.spread:0);shot.speed=p.speed;shot.radius=v.radius;shot.travel=v.travel;shot.damage=p.damage*r.state.combat_config.atk_scale;shot.length=v.length;shot.owner=t.actor;shot.definition=v.projectile;shot.technique=r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data()));LightArrowSystem::emit(r,shot);}
        ++fired;cue(r,t,"fan_released");
    }
    if (fired>=v.shots) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;cue(r,t,"recovery_started");}
}
bool CentaurusFan::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=std::get_if<CentaurusVolleyState>(&t.detail);return v && v->released<=rule(c,t).shots;}
godot::Dictionary CentaurusFan::snapshot(const RunRuntime &r,const TechniqueState &t) {const auto &p=rule(*r.content,t);godot::Dictionary out;out["released"]=std::get<CentaurusVolleyState>(t.detail).released;out["interval"]=p.interval;return out;}
}
