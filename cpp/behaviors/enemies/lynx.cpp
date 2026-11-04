#include "lynx.h"
#include "gunner.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/slash.h"
#include "../../systems/attack_system.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
double smooth(double a,double b,double value) {const double k=std::clamp((value-a)/(b-a),0.0,1.0);return k*k*(3.0-2.0*k);}
}
LynxPose LynxBehavior::visual_pose(const RunRuntime &r,uint32_t row,godot::Vector2 pos,double facing,double clock) {
    const auto &enemy=r.state.enemies[row];const auto &state=std::get<LynxState>(enemy.behavior_state);const auto &p=r.content->lynxes[r.content->definitions[enemy.definition].lynx_definition-1];
    double offset=0,rotation=0;
    if (enemy.charge>0) {
        const double side=state.buds%2==0?1:-1,w=smooth(0,0.45,enemy.charge);
        offset=-0.28*w;rotation=side*0.45*w;
    } else if (state.last_fire>=0) {
        const double age=clock-state.last_fire,side=state.last_side;
        if (age<p.fx_cut) {const double f=smooth(0,p.fx_cut,age);offset=-0.28+(0.50+0.28)*f;rotation=side*(0.45+(-0.35-0.45)*f);}
        else {const double f=smooth(p.fx_cut,p.fx_cut+0.45,age);offset=0.50*(1-f);rotation=side*(-0.35)*(1-f);}
    }
    return {pos+godot::Vector2::from_angle(facing)*(offset*enemy.radius),facing+rotation};
}
void LynxBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->lynxes[d.lynx_definition-1];const auto handle=s.enemy_handles.at(row);
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,handle)) && EnemySystem::attack_due(r,handle,dt)) {
        if (!budget.request({owner,{AttackCategory::Aimed},handle,p.warn+0.3,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight,true})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    const auto delta=e.pos-s.enemy_aim;const auto u=delta/std::max(1.0,double(delta.length()));const auto room=s.view_half-godot::Vector2(1,1)*(e.radius+40.0);
    const auto goal=(s.enemy_aim+u*p.keep).clamp(s.view_center-room,s.view_center+room);
    EnemyMotion::steer(e,goal,e.speed,p.accel,dt,tracking);EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),d.turn,dt,tracking);
    if (!GunnerTiming::advance(e.fire_t,e.charge,dt,p.warn,d.fire_interval)) return;
    e.charge=0;
    auto &state=std::get<LynxState>(e.behavior_state);const double side=state.buds%2==0?1:-1;state.buds=state.buds==INT32_MAX?INT32_MIN:state.buds+1;
    const double angle=tracking.angle(e.facing,(s.ship_pos-e.pos).angle());SlashParams shot;shot.position=e.pos+godot::Vector2::from_angle(angle)*e.radius;shot.angle=angle;shot.speed=p.slash_speed;shot.size=p.slash_size;shot.range=p.slash_range;shot.damage=p.damage;shot.side=side;
    const auto body_forward=godot::Vector2::from_angle(e.facing),paw_forward=godot::Vector2::from_angle(e.facing+side*0.45);
    const auto paw_side=godot::Vector2(-paw_forward.y,paw_forward.x);
    const auto paw=e.pos-body_forward*(e.radius*0.28)+paw_forward*(e.radius*0.55)+paw_side*(side*e.radius*0.6);
    shot.lynx_definition=d.lynx_definition;shot.paw_offset=paw-shot.position;
    if (e.attack_managed) shot.budget.value=budget.token(owner);
    if (const auto result=SlashSystem::emit(r,shot);AttackSystem::get(s,result)) {state.last_fire=s.world_time;state.last_side=int32_t(side);}
}
}
