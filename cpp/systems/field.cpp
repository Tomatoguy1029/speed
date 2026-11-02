#include "field.h"
#include "collision_query.h"
#include "../output/frame_builder.h"
#include <cmath>
#include <algorithm>
#include <limits>
#include <godot_cpp/core/math.hpp>
namespace speed {
void FieldSystem::initialize(RunRuntime &run) {
    auto &field=run.state.field;field={};field.ready=true;
    for (uint32_t i=0;i<run.content->field_bodies.size();++i) {
        const auto &body=run.content->field_bodies[i];field.bodies.push_back({i,godot::Vector2(body.x,body.y),body.radius});
    }
    auto &rng=run.state.control.rng;
    for (uint32_t k=0;k<run.content->moon_definitions.size();++k) {
        const auto &definition=run.content->moon_definitions[k];
        for (uint32_t i=0;i<definition.count;++i) {
            FieldBody moon;moon.definition=k;moon.moon=true;
            moon.orbit=rng.randf_range(definition.orbit_min,definition.orbit_max);
            moon.a0=double(i)/definition.count*godot::Math::TAU+rng.randf_range(-definition.angle_jitter,definition.angle_jitter);
            moon.direction=rng.randf()<0.5?-1.0:1.0;
            moon.radius=rng.randf_range(definition.radius_min,definition.radius_max);
            field.body_speed_max=std::max(field.body_speed_max,std::abs(definition.angular_speed)*moon.orbit);
            field.bodies.push_back(moon);
        }
    }
    update(run);
    initialize_rocks(run);
}
void FieldSystem::update(RunRuntime &run) {
    for (auto &body:run.state.field.bodies) if (body.moon) {
        const double angle=body.a0+body.direction*run.content->moon_definitions[body.definition].angular_speed*run.state.world_time;
        body.position=godot::Vector2(std::cos(angle),std::sin(angle))*body.orbit;
    }
}
uint32_t FieldSystem::visual(const RunRuntime &run,const FieldBody &body) {
    return body.moon?run.content->moon_definitions[body.definition].visual:run.content->field_bodies[body.definition].visual;
}
void FieldSystem::collide_enemy(RunRuntime &run,uint32_t row,godot::Vector2 from,double dt) {
    auto &enemy=run.state.enemies[row];
    const double margin=enemy.radius+enemy.vel.length()*dt,now=run.state.world_time;
    if (enemy.body_gap>=0 && enemy.body_gap-(enemy.pos.distance_to(enemy.body_gap_pos)+(now-enemy.body_gap_time)*run.state.field.body_speed_max)>margin) return;
    const double gap=body_gap(run,enemy.pos,4.0);
    enemy.body_gap=std::max(gap,0.0);enemy.body_gap_pos=enemy.pos;enemy.body_gap_time=now;
    if (gap>=margin) return;
    const auto hit=first_body_hit(run,from,enemy.pos,enemy.radius);if (!hit) return;
    const auto &body=run.state.field.bodies[hit->body];
    auto normal=hit->point-body.position;
    if (normal.length_squared()<1e-6) normal=from-body.position;
    normal=normal.length_squared()>0?normal.normalized():godot::Vector2(1,0);
    enemy.pos=body.position+normal*(body.radius+enemy.radius+0.01);
    const double vn=enemy.vel.dot(normal);if (vn<0) enemy.vel-=normal*vn;
    if (enemy.shove_time>0) enemy.shove_vel=enemy.vel;
}
std::optional<BodyHit> FieldSystem::first_body_hit(const RunRuntime &run,godot::Vector2 from,godot::Vector2 to,double radius) {
    std::optional<BodyHit> result;
    for (uint32_t i=0;i<run.state.field.bodies.size();++i) {
        const auto &body=run.state.field.bodies[i];
        const double t=CollisionQuery::segment_circle_t(from,to,body.position,body.radius+radius);
        if (t>=0 && (!result || t<result->t)) result=BodyHit{i,t,from.lerp(to,t)};
    }
    return result;
}
double FieldSystem::body_gap(const RunRuntime &run,godot::Vector2 point,double radius) {
    double gap=std::numeric_limits<double>::infinity();
    for (const auto &body:run.state.field.bodies) gap=std::min(gap,double(point.distance_to(body.position))-body.radius-radius);
    return gap;
}
godot::Vector2 FieldSystem::push_out(const RunRuntime &run,godot::Vector2 point,double margin) {
    for (const auto &body:run.state.field.bodies) {
        const auto delta=point-body.position;const double distance=delta.length(),minimum=body.radius+margin;
        if (distance<minimum) point=body.position+(distance>0.001?delta/distance:godot::Vector2(1,0))*minimum;
    }
    return point;
}
godot::Vector2 FieldSystem::boundary_accel(const RunRuntime &run,godot::Vector2 point) {
    const auto &c=run.state.ship_config;const double radius=point.length();
    return radius<=c.field_radius?godot::Vector2():-point/radius*(c.boundary_push+(radius-c.field_radius)*4.0);
}
void FieldSystem::collide_ship(RunRuntime &run) {
    auto &ship=run.state.ship;const auto &c=run.state.ship_config;
    // 機体の天体接触は現行どおり移動後の重なりを解消する。線分の問い合わせとは別にする。
    for (const auto &body:run.state.field.bodies) {
        const auto delta=ship.pos-body.position;const double distance=delta.length(),minimum=body.radius+c.ship_radius;
        if (distance>=minimum || distance==0) continue;
        const auto normal=delta/distance;ship.pos=body.position+normal*minimum;const double vn=ship.vel.dot(normal);
        if (vn<0) {
            ship.glide=false;ship.vel-=normal*vn*(1.0+c.crash_restitution);
            godot::Dictionary event;event["pos"]=ship.pos;event["power"]=-vn;FrameBuilder::append(run,"crash",event);
        }
    }
    const double radius=ship.pos.length(),wall=c.field_radius+500.0;
    if (radius>wall) {
        ship.glide=false;const auto normal=ship.pos/radius;ship.pos=normal*wall;const double vn=ship.vel.dot(normal);
        if (vn>0) ship.vel-=normal*2.0*vn;
    }
}
bool FieldSystem::validate(const godot::RunState &state,const ContentBundle &content) {
    if (!std::isfinite(state.field.body_speed_max) || state.field.body_speed_max<0) return false;
    for (const auto &body:state.field.bodies) if (body.definition>=(body.moon?content.moon_definitions.size():content.field_bodies.size()) ||
        !body.position.is_finite() || !std::isfinite(body.radius) || body.radius<=0 || !std::isfinite(body.orbit) || body.orbit<0 ||
        !std::isfinite(body.a0) || (body.direction!=1 && body.direction!=-1)) return false;
    for (uint32_t i=0;i<state.field.rocks.size();++i) {
        const auto &rock=state.field.rocks[i];
        if (!state.field.rock_handles.contains(state.field.rock_handles.at(i)) || rock.kind>=RockKind::Count || !rock.position.is_finite() || !rock.velocity.is_finite() ||
            !std::isfinite(rock.size) || rock.size<=0 || !std::isfinite(rock.facing) || !std::isfinite(rock.spin) || !std::isfinite(rock.born) || !std::isfinite(rock.gone)) return false;
        if (state.enemy_handles.contains(rock.proxy) && !same_handle(state.enemies[rock.proxy.slot].rock,state.field.rock_handles.at(i))) return false;
    }
    for (const auto &w:state.field.wells) if (!w.position.is_finite() || !std::isfinite(w.born) || !std::isfinite(w.life) || w.life<=0 || !std::isfinite(w.radius) || w.radius<0 || !std::isfinite(w.pull) || w.pull<0) return false;
    return state.field.warp_pos.is_finite() && std::isfinite(state.field.warp_gone) && std::isfinite(state.field.stream_t);
}
std::vector<SightBlocker> FieldSystem::sight_blockers(const RunRuntime &run,godot::Vector2 lens,double length) {
    std::vector<SightBlocker> out;const auto &state=run.state;
    for (const auto &enemy:state.enemies) if (enemy.alive && !enemy.dead && state.field.rock_handles.contains(enemy.rock)) {
        const auto offset=enemy.pos-lens;const float radius=enemy.radius;
        if (offset.length_squared()<=(length+radius)*(length+radius)) out.push_back({offset,radius});
    }
    for (const auto &body:state.field.bodies) if (body.position.distance_to(lens)<length+body.radius) out.push_back({body.position-lens,float(body.radius)});
    return out;
}
double FieldSystem::sight_reach(godot::Vector2 direction,double length,const std::vector<SightBlocker> &blockers) {
    double reach=length;
    for (const auto &b:blockers) {
        const double along=b.offset.dot(direction);if (along<-b.radius) continue;
        const double perpendicular=b.offset.length_squared()-along*along;
        if (perpendicular<=double(b.radius)*b.radius) reach=std::min(reach,std::max(0.0,along-std::sqrt(std::max(0.0,double(b.radius)*b.radius-perpendicular))));
    }
    return reach;
}

namespace {
godot::Vector2 well_pull(godot::Vector2 center,godot::Vector2 at,double reach,double strength) {
    const auto delta=center-at;const double distance=delta.length();if (distance>=reach || distance<1.0) return {};
    return delta/distance*strength*(1.0-distance/reach);
}
}
bool FieldSystem::add_well(RunRuntime &r,godot::Vector2 position,double life,double radius,double pull) {
    if (!position.is_finite() || !std::isfinite(life) || life<=0 || !std::isfinite(radius) || radius<0 || !std::isfinite(pull) || pull<0 || !std::isfinite(float(radius)) || !std::isfinite(float(pull))) return false;
    r.state.field.wells.push_back({position,r.state.world_time,life,radius,pull});return true;
}
bool FieldSystem::spawn_well(RunRuntime &r) {
    auto &s=r.state;godot::Vector2 position;
    for (int attempt=0;attempt<8;++attempt) {
        const double x=s.control.rng.randf_range(-0.7,0.7)*s.view_half.x;const double y=s.control.rng.randf_range(-0.7,0.7)*s.view_half.y;position=s.view_center+godot::Vector2(x,y);
        if (position.distance_to(s.ship.pos)>300 && body_gap(r,position,0)>100) break;
    }
    const auto &p=r.content->gravity;return add_well(r,position,p.life,p.radius,p.pull);
}
void FieldSystem::step_gravity(RunRuntime &r,double dt) {
    if (dt<=0) return;auto &s=r.state;auto &wells=s.field.wells;const double now=s.world_time;
    wells.erase(std::remove_if(wells.begin(),wells.end(),[&](const auto &w){return now-w.born>=w.life;}),wells.end());
    const bool fast=s.draw.tracing || s.ship.glide || s.ship.vel.length()>=s.ship_config.max_speed*s.combat_config.ram_speed_ratio;
    for (const auto &well:wells) {
        const double k=1.0-(now-well.born)/well.life,reach=well.radius*k,strength=well.pull*k*dt;
        if (!fast) s.ship.vel+=well_pull(well.position,s.ship.pos,reach,strength);
        for (auto &e:s.enemies) if (e.alive && !e.dead && !e.is_boss && !s.field.rock_handles.contains(e.rock) && !e.parent.generation) e.vel+=well_pull(well.position,e.pos,reach,strength);
        for (auto &shot:s.hostiles) if (shot.alive) shot.vel+=well_pull(well.position,shot.pos,reach,strength);
    }
}
void FieldSystem::comet_gravity(RunRuntime &r,const DeathContext &death) {
    const auto cause=death.request.cause;
    if (cause==Cause::None || cause==Cause::Wave || cause==Cause::Chain || cause==Cause::PumpBurst || cause==Cause::Marlin || cause==Cause::Collapse || !r.state.enemy_handles.contains(death.target)) return;
    const auto rock=r.state.enemies[death.target.slot].rock;if (!r.state.field.rock_handles.contains(rock)) return;const auto &source=r.state.field.rocks[rock.slot];
    if (source.kind!=RockKind::Comet || source.rare_weapon) return;const auto &p=r.content->gravity;add_well(r,death.corpse.pos,p.life,p.radius,p.pull);
}

void FieldSystem::spawn_warp(RunRuntime &r) {
    auto &s=r.state;const auto &p=r.content->warp;
    for (int attempt=0;attempt<8;++attempt) {
        const auto u=godot::Vector2::from_angle(s.control.rng.randf()*godot::Math::TAU);
        const double edge=std::min(s.view_half.x/std::max(double(std::abs(u.x)),0.001),s.view_half.y/std::max(double(std::abs(u.y)),0.001));
        s.field.warp_pos=s.view_center+u*edge*0.8;
        if (body_gap(r,s.field.warp_pos,p.radius)>50 && s.field.warp_pos.length()<s.ship_config.field_radius-200) break;
    }
    s.field.warp_gone=s.world_time+p.life;
}
bool FieldSystem::take_warp(RunRuntime &r) {
    auto &s=r.state;if (s.field.warp_gone<0) return false;if (s.world_time>=s.field.warp_gone) {s.field.warp_gone=-1;return false;}
    const double reach=r.content->warp.radius+s.ship_config.ship_radius;if (s.ship.pos.distance_squared_to(s.field.warp_pos)>reach*reach) return false;
    s.field.warp_gone=-1;return true;
}

}
