#include "hound.h"
#include "pursuit.h"
#include "../../systems/group_system.h"
#include "../../systems/tracking_policy.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
double move_toward(double value,double target,double step) {return value+std::clamp(target-value,-step,step);}
}
bool HoundBehavior::running(const godot::RunState &state,uint32_t row) {
    const auto &e=state.enemies[row];return e.alive && !e.dead && !e.held && e.stone<=0 && !e.slash_hold && e.shove_time<=0 && e.knock_t<=0 && e.mode!=godot::RunState::EnemyMode::Windup;
}
godot::Vector2 HoundBehavior::pack_velocity(const RunRuntime &run,uint32_t row) {
    const auto &state=run.state;const auto &e=state.enemies[row];const auto &pack=run.content->definitions[e.definition].pack;
    const auto *group=state.groups.groups.getptr(e.group_id);
    const auto *order=GroupSystem::order(state,state.enemy_handles.at(row));
    const bool following=order && order->follow && order->follow_until>state.world_time;
    const double gap=std::max(1.0,pack.gap),reach=std::max(1.0,pack.reach);
    godot::Vector2 separation,center,velocity;int count=0;
    if (group) for (const auto &member:group->members) {
        const auto actor=member.value.actor;
        if (!state.enemy_handles.contains(actor) || actor.slot==row || !running(state,actor.slot)) continue;
        const auto &neighbor=state.enemies[actor.slot];const auto offset=e.pos-neighbor.pos;const double distance=offset.length();
        if (!following && distance>reach) continue;
        center+=neighbor.pos;velocity+=neighbor.vel;++count;
        if (distance>0.001 && distance<gap) separation+=offset/distance*(1.0-distance/gap);
    }
    if (following) {
        const auto to=order->follow_goal-e.pos;const double top=e.speed*order->follow_scale;
        auto desired=to.length_squared()>1.0?to.normalized()*std::min(top,double(to.length())/0.25):godot::Vector2();
        return (desired+separation*e.speed*pack.separation).limit_length(top);
    }
    const auto chase=(state.ship_pos-e.pos).normalized()*e.speed;if (!count) return chase;
    auto desired=chase.lerp(velocity/count,std::clamp(pack.alignment,0.0,1.0));
    desired+=(center/count-e.pos)/reach*e.speed*pack.cohesion;
    return (desired+separation*e.speed*pack.separation).limit_length(e.speed);
}
void HoundBehavior::prepare(RunRuntime &run,const std::vector<size_t> &rows) {
    for (auto row:rows) {
        auto &e=run.state.enemies[row];const auto *o=GroupSystem::order(run.state,run.state.enemy_handles.at(uint32_t(row)));
        e.pursuit_ready=!e.slash_hold && (running(run.state,row) || (o && o->quiet));
        if (e.pursuit_ready) e.pursuit=pack_velocity(run,uint32_t(row));
    }
}
godot::Vector2 HoundBehavior::pursuit(RunRuntime &run,uint32_t row,double dt,const TrackingPolicy &tracking) {
    auto &e=run.state.enemies[row];const auto target=e.pursuit_ready?e.pursuit:(run.state.ship_pos-e.pos).normalized()*e.speed;
    return e.vel.lerp(tracking.velocity(e.vel,e.facing,target),std::clamp(run.content->definitions[e.definition].accel*dt,0.0,1.0));
}
bool HoundBehavior::ordered_move(RunRuntime &run,uint32_t row,double dt,const TrackingPolicy &tracking) {
    auto &e=run.state.enemies[row];auto *o=GroupSystem::order(run.state,run.state.enemy_handles.at(row));if (!o) return false;
    if (o->steer) {
        if (o->steer_until>run.state.world_time) {
            const auto &c=o->steering;const auto to=o->steer_goal-e.pos;const double distance=to.length();
            if (tracking.locked()) o->heading=e.facing;
            if (distance<c.arrive) {
                o->speed=move_toward(o->speed,0,c.decel*dt);
                if (o->speed<80 && !tracking.locked()) {e.facing=o->heading;PursuitBehavior::turn(e,(o->face_point-e.pos).angle(),c.face_turn,dt,tracking);o->heading=e.facing;}
            } else {
                e.facing=o->heading;PursuitBehavior::turn(e,to.angle(),o->speed>=c.turn_switch?c.turn_slow:c.turn_fast,dt,tracking);o->heading=e.facing;
                const double target=std::min(c.max_speed,distance*2.2)*std::max(0.25,std::cos(o->heading-to.angle()));
                o->speed=move_toward(o->speed,target,(target>o->speed?c.accel:c.decel)*dt);
            }
            e.vel=godot::Vector2::from_angle(o->heading)*o->speed;e.facing=o->heading;e.mode=godot::RunState::EnemyMode::Move;e.charge=0;return true;
        }
        o->steer=false;
    }
    if (o->quiet) {
        if (o->quiet_until>run.state.world_time) {
            const auto desired=o->quiet_velocity_set?o->quiet_velocity:pursuit(run,row,dt,tracking);
            e.vel=tracking.velocity(e.vel,e.facing,desired);
            if (e.vel.length_squared()>0.01 && !tracking.locked()) e.facing=e.vel.angle();
            e.mode=godot::RunState::EnemyMode::Move;e.charge=0;return true;
        }
        o->quiet=false;
    }
    return false;
}
}
