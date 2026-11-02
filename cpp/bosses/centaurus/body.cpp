#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/field.h"
#include "../../systems/motion_math.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
const CentaurusBodyDefinition &parameters(const RunRuntime &r,const BossBodyState &body) {
    return *std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &p){return p.body==body.definition;});
}
void remember_guard(RunRuntime &r,BossBodyState &body,int64_t id) {
    if (id<0) return;const auto &p=parameters(r,body);
    body.centaurus.guards.push_back({r.state.enemy_handles.at(r.state.rows_by_id.at(id)),r.state.control.rng.randf_range(p.sail_guard_min,p.sail_guard_max),r.state.control.rng.randf_range(0,6.283185307179586)});
}
uint32_t guards_near(const RunRuntime &r,const BossBodyState &body,godot::Vector2 &sum) {
    const auto &p=parameters(r,body);const auto at=r.state.enemies[body.actor.slot].pos;uint32_t count=0;
    for (const auto &e:r.state.enemies) if (e.alive && !e.dead && r.content->definitions[e.definition].id==godot::StringName("defender") && e.pos.distance_squared_to(at)<=p.guard_search*p.guard_search) {sum+=e.pos;++count;}
    return count;
}
}
EnemyHandle CentaurusBody::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {
    if (!definition || definition>r.content->boss_bodies.size() || r.content->bosses[r.content->boss_bodies[definition-1].boss-1].kind!=1) return {};
    return PhaseController::spawn(r,definition,at,entrance);
}
void CentaurusBody::spawned(RunRuntime &r,BossBodyState &body) {
    const auto &p=parameters(r,body);const auto actor=r.state.enemies[body.actor.slot];const auto back=-godot::Vector2::from_angle(actor.facing);
    for (uint32_t k=0;k<p.guard_count;++k) {
        const double offset=p.guard_count>1?(double(k)/std::max(1u,p.guard_count-1)-0.5)*2.2:0;
        EnemySpawn spawn;spawn.position=actor.pos+back.rotated(offset)*(actor.radius+70.0);spawn.facing=actor.facing;spawn.has_facing=true;
        remember_guard(r,body,EnemySystem::spawn(r,p.guard-1,spawn));
    }
    body.centaurus.guard_refill=p.guard_refill;
}
void CentaurusBody::pre_step(RunRuntime &r,BossBodyState &body,double dt) {
    auto &v=body.centaurus;v.turn_motion=0;const auto &p=parameters(r,body);const auto &e=r.state.enemies[body.actor.slot];const auto offset=r.state.ship_pos-e.pos;const auto speed=r.state.ship.vel.length();
    bool busy=false;for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,body.actor) && t.stage<TechniqueStage::Finished) busy=true;
    if (body.phase<2 || body.mode!=BossMode::Idle || busy || speed<r.content->config.ship_config_base_max_speed*r.content->config.ship_config_steer_cruise*0.5 || speed<0.001 || offset.length()<p.path_min || offset.length()>p.path_max || std::abs(r.state.ship.vel.normalized().dot(offset.normalized()))>=p.path_cos) v.path_hold=0;
    else v.path_hold+=dt;
}
void CentaurusBody::step(RunRuntime &r,BossBodyState &body,double dt) {
    auto &v=body.centaurus;const auto &p=parameters(r,body);const auto &d=r.content->bosses[r.content->boss_bodies[body.definition-1].boss-1];
    v.guard_refill=std::max(0.0,v.guard_refill-dt);
    if (v.guard_refill<=0) {
        v.guard_refill=p.guard_refill;godot::Vector2 sum;
        if (guards_near(r,body,sum)<p.guard_count) {
            const auto actor=r.state.enemies[body.actor.slot];auto away=(actor.pos-r.state.ship_pos).normalized();if (away==godot::Vector2()) away=-godot::Vector2::from_angle(actor.facing);
            EnemySpawn spawn;spawn.position=actor.pos+away.rotated(r.state.control.rng.randf_range(-0.5,0.5))*70;spawn.facing=actor.facing;spawn.has_facing=true;
            remember_guard(r,body,EnemySystem::spawn(r,p.guard-1,spawn));
        }
    }
    v.guard_scan-=dt;if (v.guard_scan<=0) {v.guard_scan=p.guard_scan;godot::Vector2 sum;const auto count=guards_near(r,body,sum);v.has_guard_point=count>=p.guard_min && count>0;v.guard_point=v.has_guard_point?sum/double(count):godot::Vector2();}
    auto &e=r.state.enemies[body.actor.slot];const auto aim=r.state.enemy_aim;const auto offset=e.pos-aim;const double distance=offset.length();auto direction=offset/std::max(distance,1.0);
    if (v.has_guard_point && v.guard_point.distance_squared_to(aim)>1) direction=(v.guard_point-aim).normalized();
    auto step=aim+direction*std::clamp(distance,p.keep_min,p.keep_max)-e.pos;const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    if (step.length()>24) {step=tracking.velocity(e.vel,e.facing,step.limit_length(d.speed*dt));const auto from=e.pos;e.pos+=step;e.vel=step/std::max(dt,0.001);FieldSystem::collide_enemy(r,body.actor.slot,from,dt);} else e.vel={};
    const double before=e.facing;if (!tracking.locked()) e.facing+=std::clamp(angle_difference((aim-e.pos).angle()-e.facing),-d.turn*dt,d.turn*dt);v.turn_motion=angle_difference(e.facing-before)/std::max(dt,0.001);
}
bool CentaurusBody::validate(const godot::RunState &s,const ContentBundle &c,const BossBodyState &body) {
    if (c.bosses[c.boss_bodies[body.definition-1].boss-1].kind!=1) return true;const auto &v=body.centaurus;
    if (!v.guard_point.is_finite() || !v.leap_from.is_finite() || !v.leap_to.is_finite() || (v.path_side!=1 && v.path_side!=-1) || (v.sail_side!=1 && v.sail_side!=-1) || !std::isfinite(v.turn_motion)) return false;
    for (double value:{v.guard_refill,v.path_hold,v.leap_ready_at,v.leap_elapsed,v.retreat_ready_at}) if (!std::isfinite(value) || value<0) return false;
    if (!std::isfinite(v.guard_scan)) return false;
    for (const auto &entry:v.cooldowns) if (!entry.first || entry.first>c.boss_techniques.size() || c.boss_techniques[entry.first-1].phase!=1 || !std::isfinite(entry.second) || entry.second<0) return false;
    for (const auto &g:v.guards) if (!std::isfinite(g.scale) || !std::isfinite(g.phase) || g.scale<0 || (s.enemy_handles.contains(g.actor) && c.definitions[s.enemies[g.actor.slot].definition].kind!=EnemyDefinition::Kind::Defender)) return false;
    return true;
}
}
