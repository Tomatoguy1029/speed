#include "sword_flash.h"
#include "../flow/phase_controller.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/collision_query.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
void enter(MonocerosSwordState &v,MonocerosSwordState::Stage stage) {v.stage=stage;v.elapsed=0;}
void release(RunRuntime &r,TechniqueState &t) {const auto &p=rule(r,t);auto &v=std::get<MonocerosSwordState>(t.detail);auto *body=PhaseController::find(r,t.actor);if (!body) return;const auto at=r.state.enemies[t.actor.slot].pos,center=at+godot::Vector2::from_angle(v.base)*std::clamp(double(at.distance_to(v.target)),p.slash_min,p.slash_max),u=godot::Vector2::from_angle(v.base+v.side*p.slash_angle);body->slash_from=center-u*p.slash_length*0.5;body->slash_to=center+u*p.slash_length*0.5;body->has_slash=true;body->monoceros_slashes.push_back({body->slash_from,body->slash_to,p.slash_width,body->clock,v.cut+1});t.hit=false;v.released=true;v.released_at=v.elapsed;v.glow=0;godot::PackedVector2Array line;line.push_back(body->slash_from);line.push_back(body->slash_to);godot::Dictionary event;event["line"]=line;event["width"]=p.slash_width;FrameBuilder::append(r,"monoceros_slash_release",event);}
void damage(RunRuntime &r,TechniqueState &t) {if (t.hit) return;const auto *body=PhaseController::find(r,t.actor);if (!body || !body->has_slash || !r.state.observations.check(t.observation_id,CollisionQuery::sweep_segment(t.previous_ship,r.state.ship_pos,body->slash_from,body->slash_to,rule(r,t).slash_width*0.5+r.state.ship_config.ship_radius))) return;ShipDamageRequest request;request.observation_id=t.observation_id;request.amount=rule(r,t).damage;request.scale=DamageScale::AtkScale;request.cause=Cause::SwordFlash;request.source=r.state.enemies[t.actor.slot].definition+1;request.technique=t.definition;CombatResolver::ship_damage(r,request);t.hit=true;}
}
bool MonocerosSword::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {return definition && definition<=r.content->boss_techniques.size() && r.state.enemy_handles.contains(actor) && !r.state.enemies[actor.slot].dead && PhaseController::find(r,actor) && r.state.enemies[actor.slot].pos.distance_to(r.state.ship_pos)<=r.content->boss_techniques[definition-1].slash_max+r.content->boss_techniques[definition-1].slash_length*0.5;}
void MonocerosSword::begin(RunRuntime &r,TechniqueState &t) {auto &e=r.state.enemies[t.actor.slot];e.vel={};const auto &b=r.content->bosses[rule(r,t).boss-1];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};t.aim=tracking.target(e.pos,e.facing,r.state.ship_pos+r.state.ship.vel*b.lock_lead);t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;MonocerosSwordState v;v.angle=e.facing;v.target=tracking.target(e.pos,e.facing,r.state.ship_pos);t.detail=v;}
godot::PackedVector2Array MonocerosSword::horn(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=r.content->bosses[p.boss-1];const auto u=godot::Vector2::from_angle(std::get<MonocerosSwordState>(t.detail).angle);godot::PackedVector2Array out;out.push_back(e.pos+u*e.radius*0.65);out.push_back(e.pos+u*e.radius*(p.phase>=2?b.horn_length_ratio_p2:b.horn_length_ratio));return out;}
void MonocerosSword::step(RunRuntime &r,TechniqueState &t,double dt) {
    if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);auto &v=std::get<MonocerosSwordState>(t.detail);using Stage=MonocerosSwordState::Stage;v.elapsed+=dt;const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    switch (v.stage) {
    case Stage::Aim: {const double duration=v.cut==0?p.first_windup:p.warn,k=std::clamp(v.elapsed/std::max(duration,0.001),0.0,1.0);if (!t.locked) {e.facing=tracking.angle(e.facing,e.facing+std::clamp(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing),-p.aim_turn*dt,p.aim_turn*dt));v.target=tracking.target(e.pos,e.facing,r.state.ship_pos);if (v.elapsed>=duration-p.lock_time) t.locked=true;}v.glow=1.0-(1.0-k)*(1.0-k);v.angle=e.facing-v.side*p.pull*v.glow;if (v.elapsed>=duration) {v.base=e.facing;v.speed=p.lunge_speed;v.released=false;t.stage=TechniqueStage::Active;enter(v,Stage::Swing);}break;}
    case Stage::Swing: {const double k=std::clamp(v.elapsed/std::max(p.swing_time,0.001),0.0,1.0),ease=k*k*(3.0-2.0*k);v.angle=v.base+v.side*(-p.pull+2.0*p.pull*ease);v.speed*=std::exp(-p.lunge_decay*dt);const auto from=e.pos;e.vel=godot::Vector2::from_angle(v.base)*v.speed;e.pos+=e.vel*dt;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);if (!v.released && ease>=0.5) release(r,t);if (v.released && v.elapsed-v.released_at<=p.slash_hit_time) damage(r,t);if (k>=1 && v.released && v.elapsed-v.released_at>=p.slash_hit_time) {e.vel={};enter(v,v.cut+1<p.cuts?Stage::Gap:Stage::Return);if (v.stage==Stage::Gap) t.locked=false;}break;}
    case Stage::Gap:if (v.elapsed>=p.cut_gap) {++v.cut;v.side=v.cut%2==0?1:-1;v.target=tracking.target(e.pos,e.facing,r.state.ship_pos);enter(v,Stage::Aim);}break;
    case Stage::Return: {const double k=std::clamp(v.elapsed/std::max(p.return_time,0.001),0.0,1.0),from=v.base+v.side*p.pull;v.angle=from+(e.facing-from)*k*k*(3.0-2.0*k);if (v.elapsed>=p.return_time) {t.stage=TechniqueStage::Recovery;t.remaining=p.recover;e.vel={};}break;}
    }
}
bool MonocerosSword::validate(const TechniqueState &t) {if (!std::holds_alternative<MonocerosSwordState>(t.detail)) return false;const auto &v=std::get<MonocerosSwordState>(t.detail);for (double x:{v.elapsed,v.glow,v.speed,v.released_at}) if (!std::isfinite(x) || x<0) return false;return v.stage<=MonocerosSwordState::Stage::Return && v.glow<=1 && std::isfinite(v.angle) && std::isfinite(v.base) && v.target.is_finite() && (v.side==1 || v.side==-1);}
}
