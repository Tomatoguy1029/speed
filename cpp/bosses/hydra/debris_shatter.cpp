#include "technique.h"
#include "normal_attack.h"
#include "body.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/attacks/bullet.h"
#include "../../systems/collision_query.h"
#include "../../systems/tracking_policy.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
namespace speed {
namespace {constexpr double STONE_SPEED=220,MOUTH=40;}
// 瓦礫の首は予兆のあいだに岩を吐く扇の真ん中へ向きを変える。
void HydraTechnique::debris_shatter_aim(RunRuntime &r,TechniqueState &t) {auto *b=PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();auto &move=std::get<HydraShatterState>(v.move);auto &debris=*HydraNormalAttack::neck(*b,v.participants[0]);if (!move.faced) {move.faced=true;move.face=debris.angle;}const double k=std::clamp(t.elapsed/std::max(0.001,r.content->boss_techniques[t.definition-1].warn),0.0,1.0);debris.angle=move.face+std::remainder(double((r.state.ship_pos-debris.strike_pos).angle())-move.face,6.283185307179586)*k*k*(3-2*k);}
void HydraTechnique::debris_shatter(RunRuntime &r,TechniqueState &t,double dt) {
    auto *b=PhaseController::find(r,t.actor);auto &v=t.detail.get<HydraTechniqueState>();auto &move=std::get<HydraShatterState>(v.move);
    const auto &p=*std::find_if(r.content->hydra_shatters.begin(),r.content->hydra_shatters.end(),[&](const auto &p){return p.technique==t.definition;});
    auto &debris=*HydraNormalAttack::neck(*b,v.participants[0]);auto &beam=*HydraNormalAttack::neck(*b,v.participants[1]);
    if (!move.initialized) {
        move.initialized=true;const auto &body=r.state.enemies[b->actor.slot];const TrackingPolicy tracking{r.state.draw.tracing,body.held,r.state.enemy_handles.contains(body.pump_owner)};
        move.aim=(tracking.target(beam.strike_pos,b->hydra->separated?beam.look_angle:beam.angle,r.state.ship_pos)-beam.strike_pos).angle();
        for (uint32_t j=0;j<p.count;++j) {
            // 扇の真ん中が機体を狙うように打ち出し、岩は減速せず同じ速さでまっすぐ進む。
            const double offset=(double(j)/std::max(1.0,double(p.count)-1)-0.5)*1.4;const auto mouth=debris.strike_pos+godot::Vector2::from_angle(debris.angle)*MOUTH;
            EnemySpawn spawn;spawn.position=mouth;spawn.origin=SpawnOrigin::BossPart;spawn.has_velocity=true;
            const auto id=EnemySystem::spawn(r,p.enemy-1,spawn);if (id>0) move.rubble.push_back({r.state.enemy_handles.at(r.state.rows_by_id.at(id)),mouth,godot::Vector2::from_angle(debris.angle+offset)*STONE_SPEED,false});
        }
    }
    for (auto &stone:move.rubble) if (!stone.shattered && r.state.enemy_handles.contains(stone.actor)) r.state.enemies[stone.actor.slot].pos+=stone.to*dt;
    if (v.time<p.deploy) beam.angle=move.aim-p.arc*0.5;
    if (v.time>=p.deploy && v.time<p.deploy+p.time) {
        beam.angle=move.aim-p.arc*0.5+p.arc*std::clamp((v.time-p.deploy)/p.time,0.,1.);
        const auto from=beam.strike_pos,to=from+godot::Vector2::from_angle(beam.angle)*p.length;
        if (!AttackSystem::get(r.state,beam.emission)) beam.emission=emit(r,t,beam.actor,{from,to},p.width,0,p.time);
        else {const auto *record=AttackSystem::get(r.state,beam.emission);auto &shape=std::get<HydraShapeHazard>(r.state.hazards[record->row].shape);shape.points={from,to};}
        for (auto &stone:move.rubble) {
            if (stone.shattered) continue;
            if (!r.state.enemy_handles.contains(stone.actor) || r.state.enemies[stone.actor.slot].dead) {stone.shattered=true;continue;}
            const auto enemy=r.state.enemies[stone.actor.slot];
            const auto delta=to-from;const double u=delta.length_squared()>0?std::clamp(double((enemy.pos-from).dot(delta))/delta.length_squared(),0.,1.):0;
            if (enemy.pos.distance_to(from+delta*u)>enemy.radius+p.width*0.5) continue;
            const auto direction=(enemy.pos-from).normalized();const double base=direction==godot::Vector2()?r.state.control.rng.randf()*6.283185307179586:double(direction.angle());
            BulletValues values;values.damage=p.shard_damage;
            for (int k=0;k<6;++k) {const auto handle=BulletSystem::fire_enemy(r,stone.actor,base+(k-2.5)*(direction==godot::Vector2()?6.283185307179586/6:0.45),p.shard_speed,values);if (AttackSystem::get(r.state,handle)) r.state.attacks.records[handle.slot].spec.source_technique=t.definition;}
            EnemySystem::mark_dead(r,stone.actor);stone.shattered=true;HydraNormalAttack::cue(r,*b,beam,"rubble_shattered",t.definition);
        }
    }
}
}
