#include "bomber.h"
#include "pursuit.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/zone.h"
#include "../../output/frame_builder.h"
#include <algorithm>
namespace speed {
void BomberBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &d=r.content->definitions[e.definition];const auto &p=r.content->bombers[d.bomber_definition-1];
    const auto self=s.enemy_handles.at(row);const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    if (e.attack_managed && !(budget.owns(owner,e.id) && EnemySystem::attack_active(s,self)) && EnemySystem::attack_due(r,self,dt)) {
        if (!budget.request({owner,{AttackCategory::Zone},self,p.admission_duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:d.attack_weight})) {e.charge=0;e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);return;}
    }
    if (e.mode==EnemyMode::Move) {
        e.vel=PursuitBehavior::velocity(e,s.ship_pos,d.turn,dt,tracking);
        if (e.pos.distance_squared_to(s.ship_pos)<=p.trigger*p.trigger) {e.mode=EnemyMode::Windup;e.timer=p.blast_delay;}return;
    }
    EnemyMotion::steer(e,s.ship_pos,e.speed*p.rush,p.accel*2.0,dt,tracking);
    const double weight=r.content->config.enemy_face_move*std::min(1.0,double(e.vel.length())/std::max(e.speed,1.0));
    const auto face=e.vel.normalized()*weight+(s.enemy_aim-e.pos).normalized()*(1.0-weight);
    if (face.length_squared()>0.0025) EnemyMotion::turn(e,face.angle(),d.turn*2.0,dt,tracking);
    e.timer-=dt;e.charge=std::clamp(1.0-e.timer/std::max(p.blast_delay,0.001),0.0,1.0);
    if (e.timer>0) return;
    ZoneParams zone;zone.position=e.pos;zone.radius=p.blast_radius;zone.damage=p.blast_damage;zone.style=ZoneStyle::Bomber;zone.color=d.color;zone.owner=self;if (e.attack_managed) zone.budget.value=budget.token(owner);
    ZoneSystem::emit(r,zone);EnemySystem::mark_dead(r,self);godot::Dictionary ev;ev["pos"]=e.pos;FrameBuilder::append(r,"bomber_explode",ev);
}
}
