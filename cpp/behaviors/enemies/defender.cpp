#include "defender.h"
#include "../../systems/enemy_motion.h"
#include <algorithm>
#include <cmath>
#include <map>
namespace speed {
void DefenderBehavior::assign(RunRuntime &r) {
    auto &s=r.state;auto &w=r.workspace;w.defender_posts_tick=s.ticks;w.defender_posts.clear();w.defender_posts.resize(s.enemies.size());
    std::vector<uint32_t> strong,ordered;
    for (uint32_t row=0;row<s.enemies.size();++row) {
        const auto &e=s.enemies[row];if (!e.alive || e.dead) continue;const auto &d=r.content->definitions[e.definition];
        if (!e.parent.generation && !e.held && !s.field.rock_handles.contains(e.rock) && (e.is_boss || (d.rank>=3 && d.rank<=5))) strong.push_back(row);
        if (d.kind==EnemyDefinition::Kind::Defender && !e.held) ordered.push_back(row);
    }
    std::sort(ordered.begin(),ordered.end(),[&](auto a,auto b){return s.enemies[a].id<s.enemies[b].id;});
    std::map<uint32_t,std::vector<uint32_t>> groups;
    for (auto row:ordered) {
        const auto &e=s.enemies[row];const auto &p=r.content->defenders[r.content->definitions[e.definition].defender_definition-1];
        double distance=std::pow(std::max(0.0,p.guard_radius),2);uint32_t nearest=UINT32_MAX;
        for (auto target:strong) {const double d=e.pos.distance_squared_to(s.enemies[target].pos);if (d<distance) {distance=d;nearest=target;}}
        if (nearest!=UINT32_MAX) groups[nearest].push_back(row);
    }
    for (const auto &[target,members]:groups) {
        const auto &guarded=s.enemies[target];const auto to_ship=s.ship_pos-guarded.pos;const auto forward=to_ship.length_squared()>0.001?to_ship.normalized():godot::Vector2::from_angle(guarded.facing);const godot::Vector2 side(-forward.y,forward.x);
        double spacing=0,offset=0;
        for (auto row:members) {const auto &e=s.enemies[row];const auto &p=r.content->defenders[r.content->definitions[e.definition].defender_definition-1];spacing=std::max(spacing,std::max(p.guard_spacing,e.radius*2));offset=std::max(offset,guarded.radius+e.radius+std::max(0.0,p.guard_distance));}
        offset=std::min(offset,double(to_ship.length())*0.5);
        for (size_t k=0;k<members.size();++k) {const auto row=members[k];w.defender_posts[row]={s.enemy_handles.at(row),s.enemy_handles.at(target),guarded.pos+forward*offset+side*(double(k)-double(members.size()-1)*0.5)*spacing};}
    }
}
const DefenderPost *DefenderBehavior::post(const RunRuntime &r,EnemyHandle h) {
    const auto &w=r.workspace;if (w.defender_posts_tick!=r.state.ticks || h.slot>=w.defender_posts.size()) return nullptr;
    const auto &p=w.defender_posts[h.slot];return same_handle(p.actor,h)?&p:nullptr;
}
bool DefenderBehavior::move(RunRuntime &r,EnemyHandle h,double dt,const TrackingPolicy &tracking) {
    if (r.workspace.defender_posts_tick!=r.state.ticks) assign(r);const auto *p=post(r,h);if (!p) return false;
    auto &e=r.state.enemies[h.slot];auto goal=p->position;double top=e.speed;auto &boost=std::get<DefenderState>(e.behavior_state).boost;
    e.mode=EnemyMode::Move;e.timer=e.charge=0;
    if (boost.active) {
        if (boost.until>r.state.world_time) {top=boost.speed;goal+=godot::Vector2(std::sin(r.state.world_time*1.3+boost.phase),std::cos(r.state.world_time*1.1+boost.phase))*boost.wobble;}
        else boost={};
    }
    const auto &cfg=r.content->defenders[r.content->definitions[e.definition].defender_definition-1];
    const double speed=top*std::min(double(e.pos.distance_to(goal))/std::max(cfg.guard_arrive,0.001),1.0);
    EnemyMotion::steer(e,goal,speed,cfg.accel,dt,tracking);EnemyMotion::turn(e,(r.state.ship_pos-e.pos).angle(),r.content->definitions[e.definition].turn,dt,tracking);return true;
}
bool DefenderBehavior::boost(RunRuntime &r,EnemyHandle h,double speed,double wobble,double until,double phase) {
    if (!r.state.enemy_handles.contains(h) || r.state.enemies[h.slot].dead || !std::holds_alternative<DefenderState>(r.state.enemies[h.slot].behavior_state) || !std::isfinite(speed) || !std::isfinite(wobble) || !std::isfinite(until) || !std::isfinite(phase)) return false;
    std::get<DefenderState>(r.state.enemies[h.slot].behavior_state).boost={true,speed,wobble,until,phase};return true;
}
bool DefenderBehavior::clear_boost(RunRuntime &r,EnemyHandle h) {
    if (!r.state.enemy_handles.contains(h) || !std::holds_alternative<DefenderState>(r.state.enemies[h.slot].behavior_state)) return false;
    std::get<DefenderState>(r.state.enemies[h.slot].behavior_state).boost={};return true;
}
void DefenderBehavior::gone(RunRuntime &r,EnemyHandle h) {r.workspace.defender_posts_tick=-1;clear_boost(r,h);}
}
