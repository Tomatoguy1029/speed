#include "kick.h"
#include "../flow/phase_controller.h"
#include "strike_shape.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const BossDefinition &boss(const RunRuntime &r,const TechniqueState &t) {return r.content->bosses[rule(r,t).boss-1];}
godot::Vector2 aim(const RunRuntime &r,const TechniqueState &t,double lead) {const auto &e=r.state.enemies[t.actor.slot];return TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*lead);}
double reach(const RunRuntime &r,const TechniqueState &t) {return rule(r,t).reach+boss(r,t).horn_width*0.5+r.state.ship_config.ship_radius;}
void recovery(RunRuntime &r,TechniqueState &t) {const auto &p=rule(r,t);t.stage=TechniqueStage::Recovery;t.remaining=p.hold+(p.return_speed>0?godot::Math::PI/p.return_speed:0)+p.recover;r.state.enemies[t.actor.slot].vel={};}
}
bool MonocerosKick::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;
    TechniqueState t;t.actor=actor;t.definition=definition;const auto &e=r.state.enemies[actor.slot];
    return e.pos.distance_to(r.state.ship_pos)<=reach(r,t) && e.pos.distance_to(aim(r,t,rule(r,t).warn))<=reach(r,t);
}
void MonocerosKick::begin(RunRuntime &r,TechniqueState &t) {auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=aim(r,t,boss(r,t).lock_lead);t.direction=(t.aim-e.pos).normalized();t.previous_ship=r.state.ship_pos;}
void MonocerosKick::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    auto &e=r.state.enemies[t.actor.slot];
    if (command==TechniqueCommand::LockAim && t.stage==TechniqueStage::Windup && !t.locked) {t.locked=true;t.direction=(t.aim-e.pos).normalized();}
    else if (command==TechniqueCommand::LaunchStrike && t.stage==TechniqueStage::Windup) {
        MonocerosKick::command(r,t,TechniqueCommand::LockAim);
        if (e.pos.distance_to(t.aim)>reach(r,t) || std::abs(angle_difference(t.direction.angle()-e.facing-godot::Math::PI))>boss(r,t).kick_trigger_arc) recovery(r,t);
        else t.stage=TechniqueStage::Active;
    } else if (command==TechniqueCommand::EndStrike && t.stage==TechniqueStage::Active) {
        if (auto *body=PhaseController::find(r,t.actor)) {
            MonocerosBreathVisual visual;visual.position=t.direction*rule(r,t).reach;visual.direction=t.direction.angle();
            visual.started=body->clock;visual.lifetime=r.content->config.fx_monoceros_kick_life;visual.spread=0.9;visual.reach=120;visual.seed=39;visual.attached=true;
            body->monoceros_breaths.push_back(visual);
        }
        recovery(r,t);
    }
}
godot::PackedVector2Array MonocerosKick::horn(const RunRuntime &r,const TechniqueState &t,bool) {
    const auto &e=r.state.enemies[t.actor.slot];godot::PackedVector2Array points;points.push_back(e.pos+t.direction*e.radius*0.65);points.push_back(e.pos+t.direction*rule(r,t).reach);return points;
}
void MonocerosKick::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];
    if (t.stage==TechniqueStage::Windup && !t.locked && rule(r,t).track_during_warn && !TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) {t.aim=aim(r,t,boss(r,t).lock_lead);t.direction=(t.aim-e.pos).normalized();}
    else if (t.stage==TechniqueStage::Active) {const auto points=horn(r,t);MonocerosStrike::damage(r,t,points,points,boss(r,t).horn_width);}
    else if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;}
}
}
