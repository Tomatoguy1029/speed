#include "hercules.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
using godot::Vector2;
Vector2 direction(double angle) {return Vector2(std::cos(angle),std::sin(angle));}
std::vector<size_t> circle_rows(const RunRuntime &r,Vector2 center,double radius) {
    const auto &s=r.state;const double padding=radius+std::max(s.combat_config.max_enemy_radius,s.grid.max_radius);const Vector2 pad(padding,padding);auto rows=CollisionQuery::enemy_rows(s,center-pad,center+pad);
    rows.erase(std::remove_if(rows.begin(),rows.end(),[&](size_t row){const auto &e=s.enemies[row];return center.distance_squared_to(e.pos)>(radius+e.radius)*(radius+e.radius);}),rows.end());return rows;
}
Vector2 target(RunRuntime &r) {
    auto &s=r.state;auto &rng=s.control.rng;const auto half=s.view_half*0.5;const auto rows=circle_rows(r,s.ship.pos,half.length());
    if (rng.randf()<0.35) for (auto row:rows) {const auto &e=s.enemies[row];if (!e.dead && s.enemy_handles.contains(e.parent) && s.enemies[e.parent.slot].is_boss) {const double angle=rng.randf()*6.28318530717958647692,radius=rng.randf()*60;return e.pos+direction(angle)*radius;}}
    for (int i=0;i<6;++i) {if (rows.empty()) break;const auto &e=s.enemies[rows[*rng.randi_range(0,rows.size()-1)]];if (!e.dead && !s.field.rock_handles.contains(e.rock)) {const double angle=rng.randf()*6.28318530717958647692,radius=rng.randf()*40;return e.pos+direction(angle)*radius;}}
    const double x=rng.randf_range(-half.x,half.x),y=rng.randf_range(-half.y,half.y);return s.ship.pos+Vector2(x,y);
}
void burn(RunRuntime &r,Vector2 center,double radius,double damage) {
    auto &s=r.state;const auto rows=circle_rows(r,center,radius);
    for (auto row:rows) {const auto &e=s.enemies[row];if (!e.alive || e.dead || s.field.rock_handles.contains(e.rock) || e.pos.distance_to(center)>radius+e.radius) continue;
        DamageRequest request;request.struck=s.enemy_handles.at(row);request.amount=damage;request.cause=Cause::Fire;request.no_crit=true;request.knock=80;request.direction=(e.pos-center).normalized();request.impact=center;request.has_impact=true;CombatResolver::damage_enemy(r,request);if (s.phase!=godot::RunState::Phase::Play) return;
    }
}
}
void HerculesBehavior::step(RunRuntime &r,double dt) {
    auto &s=r.state;auto &h=s.heroes;auto &fire=h.hercules;
    for (const auto &p:r.content->hercules) {
        if (h.power==p.hero && h.active>0) {fire.fire_time-=dt;if (fire.fire_time<=0) {fire.fire_time=p.interval;fire.falls.push_back({target(r),float(p.fall_time)});}}
        const double damage=CombatResolver::attack_power(r)*p.power;
        for (size_t i=fire.falls.size();i-->0;) {auto &f=fire.falls[i];f.remaining=float(f.remaining-dt);if (f.remaining>0) continue;const auto at=f.position;fire.falls.erase(fire.falls.begin()+i);burn(r,at,p.radius,damage);godot::Dictionary event;event["pos"]=at;event["radius"]=p.radius;event["cause"]=godot::StringName("fire");event["color"]=godot::Color::html("ff7a2e");event["life"]=0.45;EventBuilder::flush_combat(r);FrameBuilder::append(r,"explode",event);fire.burns.push_back({at,float(p.burn_time)});}
        fire.burn_tick-=dt;const bool tick=fire.burn_tick<=0;if (tick) fire.burn_tick=0.25;
        for (size_t i=fire.burns.size();i-->0;) {auto &b=fire.burns[i];b.remaining=float(b.remaining-dt);if (b.remaining<=0) {fire.burns.erase(fire.burns.begin()+i);continue;}if (tick) burn(r,b.position,p.radius*0.8,damage*p.burn_power);}
    }
}
}
