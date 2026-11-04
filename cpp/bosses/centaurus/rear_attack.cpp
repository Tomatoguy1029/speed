#include "rear_attack.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/boss_contact.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include <algorithm>
namespace speed {
namespace {
void cue(RunRuntime &r,const TechniqueState &t,const char *name) {
    godot::Dictionary p;const auto &e=r.state.enemies[t.actor.slot];p["id"]=e.id;p["technique"]=t.definition;p["cue"]=name;p["position"]=e.pos;p["angle"]=e.facing;p["world_time"]=r.state.world_time;FrameBuilder::append(r,"centaurus_cue",p);
}
}
bool CentaurusRear::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead;}
void CentaurusRear::begin(RunRuntime &r,TechniqueState &t) {t.aim=r.state.ship_pos;t.previous_ship=r.state.ship_pos;r.state.enemies[t.actor.slot].vel={};cue(r,t,"telegraph");}
void CentaurusRear::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &p=r.content->boss_techniques[t.definition-1];
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    if (t.stage!=TechniqueStage::Active || t.hit) return;
    const auto &v=*std::find_if(r.content->centaurus_rears.begin(),r.content->centaurus_rears.end(),[&](const auto &v){return v.technique==t.definition;});
    const auto center=e.pos-godot::Vector2::from_angle(e.facing)*v.back_offset;
    if (!r.state.observations.check(t.observation_id,CollisionQuery::touches(PointCircle{center,v.radius},{t.previous_ship,r.state.ship_pos,r.state.ship_config.ship_radius},{true,true}))) return;
    t.hit=true;
    ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=p.damage;request.scale=DamageScale::AtkScale;request.cause=Cause::RearAttack;request.source=e.definition+1;request.technique=t.definition;CombatResolver::ship_damage(r,request);BossContactSystem::knock_back(r,t.actor);
}
void CentaurusRear::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    if (command==TechniqueCommand::StrikeRear && t.stage==TechniqueStage::Windup) {t.stage=TechniqueStage::Active;t.hit=false;cue(r,t,"strike");}
    else if (command==TechniqueCommand::FinishVolley && (t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active)) {t.stage=TechniqueStage::Recovery;t.remaining=r.content->boss_techniques[t.definition-1].recover;cue(r,t,"recovery_started");}
}
}
