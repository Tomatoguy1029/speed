#include "charge.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../systems/combat_resolver.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const BossTechniqueDefinition &rule(const RunRuntime &r,const TechniqueState &t) {return r.content->boss_techniques[t.definition-1];}
const BossDefinition &boss(const RunRuntime &r,const TechniqueState &t) {return r.content->bosses[rule(r,t).boss-1];}
double horn_length(const RunRuntime &r,const TechniqueState &t) {const auto &p=boss(r,t);return r.state.enemies[t.actor.slot].radius*(rule(r,t).phase>=2?p.horn_length_ratio_p2:p.horn_length_ratio);}
TrackingPolicy tracking(const RunRuntime &r,const TechniqueState &t) {const auto &e=r.state.enemies[t.actor.slot];return {r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};}
godot::Vector2 strike_aim(const RunRuntime &r,const TechniqueState &t,double lead=-1) {
    const auto &p=rule(r,t);const auto &e=r.state.enemies[t.actor.slot];const auto velocity=r.state.ship.vel;
    auto target=r.state.ship_pos+velocity*(lead<0?boss(r,t).lock_lead:lead);
    const auto offset=target-e.pos;const double speed=p.distance/p.active,reach=horn_length(r,t);
    const double a=velocity.length_squared()-speed*speed,b=2.0*(offset.dot(velocity)-reach*speed),c=offset.length_squared()-reach*reach;
    double contact=0;
    if (c>0) {
        contact=p.active;
        if (std::abs(a)<0.001) {if (b< -0.001) contact=-c/b;}
        else {
            const double discriminant=b*b-4.0*a*c;
            if (discriminant>=0) for (double root:{(-b-std::sqrt(discriminant))/(2.0*a),(-b+std::sqrt(discriminant))/(2.0*a)}) if (root>=0) contact=std::min(contact,root);
        }
    }
    target+=velocity*std::clamp(contact,0.0,p.active);
    return tracking(r,t).target(e.pos,e.facing,target);
}
void damage(RunRuntime &r,TechniqueState &t,const godot::PackedVector2Array &before) {
    if (t.hit || t.stage!=TechniqueStage::Active) return;
    const auto points=MonocerosCharge::horn(r,t);
    const SweptSegment shape{before[0],before[1],points[0],points[1],boss(r,t).horn_width*0.5};
    if (!CollisionQuery::touches(shape,{t.previous_ship,r.state.ship_pos,r.state.ship_config.ship_radius},{true,true})) return;
    ShipDamageRequest request;request.amount=rule(r,t).damage;request.scale=DamageScale::AtkScale;request.cause=Cause::Horn;
    request.source=r.state.enemies[t.actor.slot].definition+1;request.technique=t.definition;
    CombatResolver::ship_damage(r,request);t.hit=true;
}
void recovery(RunRuntime &r,TechniqueState &t) {t.stage=TechniqueStage::Recovery;t.remaining=rule(r,t).recover;r.state.enemies[t.actor.slot].vel={};}
}
bool MonocerosCharge::in_reach(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    TechniqueState t;t.actor=actor;t.definition=definition;const auto &p=rule(r,t);const auto &b=boss(r,t);
    return r.state.enemies[actor.slot].pos.distance_to(strike_aim(r,t,p.warn))<=p.distance+horn_length(r,t)+b.horn_width*0.5+r.state.ship_config.ship_radius;
}
bool MonocerosCharge::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {
    if (!r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead || !definition || definition>r.content->boss_techniques.size()) return false;
    TechniqueState t;t.actor=actor;t.definition=definition;const auto &p=rule(r,t);const auto &b=boss(r,t);const auto &e=r.state.enemies[actor.slot];
    const double reach=p.distance+horn_length(r,t)+b.horn_width*0.5+r.state.ship_config.ship_radius;
    return e.pos.distance_to(r.state.ship_pos)<=reach && std::abs(angle_difference((r.state.ship_pos-e.pos).angle()-e.facing))<=b.turn*std::max(0.0,p.warn-b.lock_lead) && e.pos.distance_to(strike_aim(r,t,p.warn))<=reach;
}
godot::PackedVector2Array MonocerosCharge::horn(const RunRuntime &r,const TechniqueState &t,bool warning) {
    const auto &e=r.state.enemies[t.actor.slot];const auto direction=godot::Vector2::from_angle(e.facing);
    godot::PackedVector2Array points;points.push_back(e.pos+direction*e.radius*0.65);points.push_back(e.pos+direction*horn_length(r,t)+(warning?t.direction*rule(r,t).distance:godot::Vector2()));return points;
}
void MonocerosCharge::begin(RunRuntime &r,TechniqueState &t) {
    auto &e=r.state.enemies[t.actor.slot];e.vel={};t.aim=strike_aim(r,t);t.direction=godot::Vector2::from_angle(e.facing);t.previous_ship=r.state.ship_pos;
}
void MonocerosCharge::command(RunRuntime &r,TechniqueState &t,TechniqueCommand command) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);
    if (command==TechniqueCommand::LockAim) {
        if (t.stage!=TechniqueStage::Windup || t.locked) return;
        if (tracking(r,t).locked()) t.aim=strike_aim(r,t);
        if (t.aim.distance_squared_to(e.pos)>0.000001) e.facing=(t.aim-e.pos).angle();
        t.locked=true;t.direction=godot::Vector2::from_angle(e.facing);
    } else if (command==TechniqueCommand::LaunchStrike) {
        if (t.stage!=TechniqueStage::Windup) return;
        MonocerosCharge::command(r,t,TechniqueCommand::LockAim);
        if (e.pos.distance_to(t.aim)>p.distance+horn_length(r,t)+b.horn_width*0.5+r.state.ship_config.ship_radius) {recovery(r,t);return;}
        const double distance=std::max(b.near_clearance,std::min(double(e.pos.distance_to(t.aim)),p.distance));
        if (FieldSystem::first_body_hit(r,e.pos,e.pos+t.direction*distance,e.radius)) {
            t.stage=TechniqueStage::Failed;t.reposition=b.reposition_time;
            const auto side=(t.aim-e.pos).normalized().orthogonal();
            t.reposition_direction=FieldSystem::body_gap(r,e.pos+side*220.0,e.radius)>=FieldSystem::body_gap(r,e.pos-side*220.0,e.radius)?side:-side;
            e.vel={};return;
        }
        t.stage=TechniqueStage::Active;
    } else if (command==TechniqueCommand::EndStrike && t.stage==TechniqueStage::Active) recovery(r,t);
}
void MonocerosCharge::step(RunRuntime &r,TechniqueState &t,double dt) {
    auto &e=r.state.enemies[t.actor.slot];const auto &p=rule(r,t);const auto &b=boss(r,t);
    if (t.stage==TechniqueStage::Windup && !t.locked && p.track_during_warn && !tracking(r,t).locked()) {
        t.aim=strike_aim(r,t);e.facing=e.facing+std::clamp(angle_difference((t.aim-e.pos).angle()-e.facing),-b.turn*dt,b.turn*dt);t.direction=godot::Vector2::from_angle(e.facing);
    } else if (t.stage==TechniqueStage::Active) {
        const auto before=horn(r,t);const auto from=e.pos,step=t.direction*(p.distance/p.active*dt),to=from+step;
        const auto horn_from=from+t.direction*horn_length(r,t);
        const auto horn_hit=FieldSystem::first_body_hit(r,horn_from,horn_from+step,b.horn_width*0.5);
        const auto body_hit=FieldSystem::first_body_hit(r,from,to,e.radius);
        if (horn_hit && !r.state.field.bodies[horn_hit->body].moon && (!body_hit || horn_hit->t<=body_hit->t)) {
            e.pos=from.lerp(to,horn_hit->t);damage(r,t,before);t.stuck_body=horn_hit->body;t.stuck_offset=e.pos-r.state.field.bodies[t.stuck_body].position;
            t.stage=TechniqueStage::Stuck;t.remaining=b.stuck_time;e.vel={};return;
        }
        if (body_hit) {e.pos=from.lerp(to,body_hit->t);damage(r,t,before);recovery(r,t);return;}
        e.pos=to;e.vel=step/dt;damage(r,t,before);
    } else if (t.stage==TechniqueStage::Stuck) {
        t.remaining=std::max(0.0,t.remaining-dt);e.pos=r.state.field.bodies[t.stuck_body].position+t.stuck_offset;
        if (t.remaining<=0) {t.stage=TechniqueStage::Extract;t.remaining=b.extract_time;}
    } else if (t.stage==TechniqueStage::Recovery || t.stage==TechniqueStage::Extract) {
        if (t.stage==TechniqueStage::Extract) {const auto from=e.pos;e.pos-=t.direction*b.extract_speed*dt;FieldSystem::collide_enemy(r,t.actor.slot,from,dt);}
        t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) {t.stage=TechniqueStage::Finished;e.vel={};}
    }
}
}
