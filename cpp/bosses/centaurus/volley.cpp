#include "volley.h"
#include "reference_fx.h"
#include "../../systems/attacks/light_arrow.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <algorithm>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const CentaurusVolleyDefinition &volley(const RunRuntime &r,const TechniqueState &t) {return *std::find_if(r.content->centaurus_volleys.begin(),r.content->centaurus_volleys.end(),[&](const auto &v){return v.technique==t.definition;});}
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {
    const auto &e=r.state.enemies[t.actor.slot];godot::Dictionary p;p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);
}
}
bool CentaurusVolley::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusVolley::begin(RunRuntime &r,TechniqueState &t) {t.detail=CentaurusVolleyState{};t.aim=r.state.enemy_aim;t.previous_ship=r.state.ship_pos;r.state.enemies[t.actor.slot].vel={};cue(r,t,"telegraph");}
void CentaurusVolley::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=rule(r,t);
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    const auto &b=r.content->bosses[p.boss-1];const auto target=t.stage==TechniqueStage::Windup && !p.track_during_warn?t.aim:r.state.enemy_aim;
    if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference((target-e.pos).angle()-e.facing),-b.turn*dt,b.turn*dt);
}
void CentaurusVolley::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    if (t.stage!=TechniqueStage::Windup && t.stage!=TechniqueStage::Active) return;
    const auto &p=rule(r,t);const auto &v=volley(r,t);auto &e=r.state.enemies[t.actor.slot];
    if (command==TechniqueCommand::ReleaseArrow) {
        const auto body=std::find_if(r.content->boss_bodies.begin(),r.content->boss_bodies.end(),[&](const auto &b){return b.boss==p.boss;});
        const auto &b=*std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &b){return b.body==body->id;});
        const auto mouth=e.pos+godot::Vector2::from_angle(e.facing)*e.radius*b.bow_reach;
        const auto target=p.track_during_warn?r.state.enemy_aim:t.aim;const bool locked=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();
        LightArrowParams shot;shot.position=mouth;shot.angle=locked?e.facing:(target-mouth).angle();shot.speed=p.speed;shot.radius=v.radius;shot.travel=v.travel;shot.damage=p.damage*r.state.combat_config.atk_scale;shot.owner=t.actor;shot.definition=v.projectile;shot.technique=r.state.bosses->handles.at(uint32_t(&t-r.state.bosses->techniques.data()));
        LightArrowSystem::emit(r,shot);CentaurusReferenceFx::released(r,t,mouth,shot.angle);++std::get<CentaurusVolleyState>(t.detail).released;t.stage=TechniqueStage::Active;cue(r,t,"released");
    } else if (command==TechniqueCommand::FinishVolley) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;cue(r,t,"recovery_started");}
}
bool CentaurusVolley::validate(const TechniqueState &t,const ContentBundle &c) {
    const auto *state=std::get_if<CentaurusVolleyState>(&t.detail);const auto p=std::find_if(c.centaurus_volleys.begin(),c.centaurus_volleys.end(),[&](const auto &p){return p.technique==t.definition;});return state && p!=c.centaurus_volleys.end() && state->released<=p->count;
}
}
