#include "body.h"
#include "charge.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include <algorithm>
#include <cmath>
#include "../flow/phase_controller.h"
namespace speed {
EnemyHandle MonocerosBody::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {
    if (!definition || definition>r.content->boss_bodies.size() || r.content->bosses[r.content->boss_bodies[definition-1].boss-1].kind!=0) return {};
    return PhaseController::spawn(r,definition,at,entrance);
}
void MonocerosBody::step(RunRuntime &r,BossBodyState &body,double dt) {
    auto &e=r.state.enemies[body.actor.slot];const auto &p=r.content->bosses[r.content->boss_bodies[body.definition-1].boss-1];
    for (auto &t:r.state.bosses.techniques) if (same_handle(t.actor,body.actor) && t.reposition>0) {
        const auto from=e.pos;t.reposition=std::max(0.0,t.reposition-dt);e.pos+=t.reposition_direction*p.speed*dt;
        if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference(t.reposition_direction.angle()-e.facing),-p.turn*dt,p.turn*dt);
        e.vel=(e.pos-from)/dt;FieldSystem::collide_enemy(r,body.actor.slot,from,dt);return;
    }
    const auto toward=r.state.ship_pos-e.pos;const auto target=TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    bool closing=toward.length()>p.approach_range;
    for (const auto &t:r.content->boss_techniques) if (t.boss==r.content->boss_bodies[body.definition-1].boss && t.phase==body.phase) {
        if (t.external_id=="charge" && !closing) closing=!MonocerosCharge::in_reach(r,body.actor,t.id);
    }
    if (!target.locked()) e.facing+=std::clamp(angle_difference(toward.angle()-e.facing),-p.turn*dt,p.turn*dt);
    if (!closing) {e.vel={};return;}
    double travel=p.approach_speed*std::max(0.0,double(godot::Vector2::from_angle(e.facing).dot(toward.normalized())))*dt;
    if (toward.length()>p.approach_range) travel=std::min(travel,double(toward.length())-p.approach_range);
    const auto from=e.pos;e.pos+=godot::Vector2::from_angle(e.facing)*travel;e.vel=(e.pos-from)/dt;FieldSystem::collide_enemy(r,body.actor.slot,from,dt);
}
}
