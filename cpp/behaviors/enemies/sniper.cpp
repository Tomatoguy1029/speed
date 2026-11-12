#include "sniper.h"
#include "../../systems/enemy_motion.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/field.h"
#include "../../systems/attack_budget.h"
#include "../../systems/attacks/beam.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include "../../content/content_bundle.h"
#include <cmath>
#include <algorithm>
namespace speed {
namespace {
const SniperDefinition &definition(const RunRuntime &r,uint32_t row) {return r.content->snipers[r.content->definitions[r.state.enemies[row].definition].sniper_definition-1];}
void event(RunRuntime &r,const char *name,uint32_t row) {godot::Dictionary d;d["id"]=r.state.enemies[row].id;if (std::string(name)=="enemy_laser_charge") d["row"]=int64_t(row);FrameBuilder::append(r,name,d);}
void search(RunRuntime &r,uint32_t row,double dt) {
    auto &e=r.state.enemies[row];const auto &p=definition(r,row);const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};
    const double sway=std::sin(e.age*2.0*godot::Math::PI/p.search_period+double(e.id))*p.search_sway;
    EnemyMotion::turn(e,(r.state.ship_pos-e.pos).angle()+sway,p.search_turn,dt,tracking);
}
void cancel(RunRuntime &r,uint32_t row,double dt) {
    auto &e=r.state.enemies[row];if (e.mode==EnemyMode::Windup) event(r,"enemy_laser_cancel",row);
    AttackBudgetSystem(r).cancel(AttackBudgetSystem::owner(r.state,e.id,e.attack_group),e.id);
    e.mode=EnemyMode::Move;e.timer=0;e.charge=std::max(0.0,e.charge-dt*definition(r,row).lock_decay);std::get<SniperState>(e.behavior_state).rays.clear();
}
bool in_range(const RunRuntime &r,uint32_t row) {const double d=SniperBehavior::lens(r.state.enemies[row]).distance_to(r.state.ship_pos);return d>=1.0 && d<=definition(r,row).band_len;}
void cast(RunRuntime &r,uint32_t row,bool target_only) {
    auto &e=r.state.enemies[row];const auto &p=definition(r,row);const auto lens=SniperBehavior::lens(e);const double half=SniperBehavior::half(r,row);
    const auto forward=godot::Vector2::from_angle(e.facing);auto blockers=FieldSystem::sight_blockers(r,lens,p.band_len);std::vector<SightBlocker> candidates;
    for (auto b:blockers) {const double along=b.offset.dot(forward);if (along<-b.radius || std::abs(b.offset.cross(forward))*std::cos(half)-along*std::sin(half)>b.radius) continue;candidates.push_back(b);}
    auto &rays=std::get<SniperState>(e.behavior_state).rays;rays.assign(48,float(p.band_len));int first=0,last=48;
    if (target_only) {const double offset=angle_difference(double((r.state.ship_pos-lens).angle())-e.facing);const double f=std::clamp((offset+half)/(2.0*half),0.0,1.0)*47.0;first=std::min(int(f),46);last=first+2;}
    for (int n=first;n<last;++n) rays[n]=float(FieldSystem::sight_reach(godot::Vector2::from_angle(e.facing-half+2.0*half*n/47.0),p.band_len,candidates));
}
}
godot::Vector2 SniperBehavior::lens(const Enemy &e) {return e.pos+godot::Vector2::from_angle(e.facing)*e.radius*0.9;}
double SniperBehavior::half(const RunRuntime &r,uint32_t row) {const auto &p=definition(r,row);return p.band_width+(p.band_narrow-p.band_width)*r.state.enemies[row].charge;}
double SniperBehavior::reach(const RunRuntime &r,uint32_t row,double angle) {
    const auto &e=r.state.enemies[row];const auto &rays=std::get<SniperState>(e.behavior_state).rays;const auto &p=definition(r,row);if (rays.empty()) return p.band_len;
    const double h=half(r,row),f=std::clamp((angle_difference(angle-e.facing)+h)/(2.0*h),0.0,1.0)*47.0;const int n=std::min(int(f),46);return double(rays[n])+(double(rays[n+1])-rays[n])*(f-n);
}
int SniperBehavior::sight(const RunRuntime &r,uint32_t row,godot::Vector2 at) {
    const auto &e=r.state.enemies[row];if (e.mode==EnemyMode::Recover) return 0;const auto d=at-lens(e);const double distance=d.length();
    if (distance>definition(r,row).band_len || distance<1.0 || std::abs(angle_difference(double(d.angle())-e.facing))>half(r,row)+std::atan(r.state.ship_config.ship_radius/distance)) return 0;
    return distance<=reach(r,row,d.angle())?1:2;
}
bool SniperBehavior::aiming(const RunRuntime &r,uint32_t row) {
    const auto &e=r.state.enemies[row];return in_range(r,row) && (e.charge>0 || e.mode==EnemyMode::Windup) && (!r.state.world.attack_budget.enabled || AttackBudgetSystem::token(r.state,AttackBudgetSystem::owner(r.state,e.id,e.attack_group))>0);
}
void SniperBehavior::died(RunRuntime &r,const DeathContext &d) {if (auto *s=std::get_if<SniperState>(&r.state.enemies[d.target.slot].behavior_state)) s->rays.clear();}
void SniperBehavior::step(RunRuntime &r,uint32_t row,double dt) {
    auto &s=r.state;auto &e=s.enemies[row];const auto &p=definition(r,row);const auto handle=s.enemy_handles.at(row);const auto aim=s.enemy_aim;
    const auto d=e.pos-aim,u=d/std::max(1.0,double(d.length()));const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};
    const double hold=p.laser_delay+p.laser_time+0.5,recovery=std::max(p.cooldown,hold);
    if (e.mode==EnemyMode::Recover && e.timer>recovery-hold) e.vel={};
    else EnemyMotion::steer(e,aim+u*p.keep+godot::Vector2(-u.y,u.x)*150.0*(e.id%2?1.0:-1.0),e.speed,p.accel,dt,tracking);
    if (e.mode==EnemyMode::Recover) {e.timer=e.timer-dt;search(r,row,dt);std::get<SniperState>(e.behavior_state).rays.clear();if (e.timer<=0) e.mode=EnemyMode::Move;return;}
    if (!in_range(r,row)) {cancel(r,row,dt);search(r,row,dt);return;}
    cast(r,row,true);if (sight(r,row,s.ship_pos)!=1) {cancel(r,row,dt);search(r,row,dt);return;}
    const auto owner=AttackBudgetSystem::owner(s,e.id,e.attack_group);AttackBudgetSystem budget(r);
    if (e.attack_managed && !((e.mode==EnemyMode::Windup || e.charge>0) && budget.owns(owner,e.id))) {
        const double duration=std::max(0.0,1.0-e.charge)*p.lock_fill+p.laser_charge+p.laser_delay+p.laser_time+0.1;
        const auto &def=r.content->definitions[e.definition];
        if (!budget.request({owner,{AttackCategory::Aimed},handle,duration,e.attack_priority,s.world.attack_formation_mode?e.attack_value:def.attack_weight})) {
            if (e.mode==EnemyMode::Windup) event(r,"enemy_laser_cancel",row);e.mode=EnemyMode::Move;e.charge=0;std::get<SniperState>(e.behavior_state).rays.clear();search(r,row,dt);return;
        }
    }
    e.vel={};
    cast(r,row,false);EnemyMotion::turn(e,(s.ship_pos-e.pos).angle(),p.track_turn,dt,tracking);
    if (e.mode==EnemyMode::Windup) {
        e.timer=e.timer-dt;if (e.timer>0) return;
        BeamParams beam;beam.position=lens(e);beam.angle=e.facing;beam.length=reach(r,row,e.facing);beam.half_width=p.laser_half_width;
        beam.delay=p.laser_delay;beam.active=p.laser_time;beam.damage=p.damage;beam.color=godot::Color(1.0,0.3,0.25);beam.style=BeamStyle::Telescope;beam.owner=handle;beam.attached=false;if (e.attack_managed) beam.budget.value=budget.token(owner);
        const auto emitted=BeamSystem::emit(r,beam);if (AttackSystem::get(s,emitted)) event(r,"enemy_laser_fire",row);
        godot::Dictionary out;out["pos"]=beam.position;out["angle"]=beam.angle;out["length"]=beam.length;out["width"]=p.laser_half_width*2.0;FrameBuilder::append(r,"telescope_fire",out);
        e.charge=0;e.mode=EnemyMode::Recover;e.timer=recovery;return;
    }
    e.charge=std::min(1.0,e.charge+dt/p.lock_fill);if (e.charge>=1.0) {e.mode=EnemyMode::Windup;e.timer=p.laser_charge;godot::Dictionary out;out["pos"]=lens(e);FrameBuilder::append(r,"telescope_charge",out);event(r,"enemy_laser_charge",row);}
}
}
