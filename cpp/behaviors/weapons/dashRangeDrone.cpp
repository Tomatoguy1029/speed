#include "dashRangeDrone.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
godot::Vector2 orthogonal(godot::Vector2 v) {return {v.y,-v.x};}
godot::Vector2 idle(const RunRuntime &r,size_t i) {const auto &s=r.state;const auto &w=s.loadout.escort;const double rank=i/2+1,side=i%2?1:-1;return s.ship.pos+(orthogonal(s.ship.heading)*side*w.idle_spacing*rank-s.ship.heading*(w.idle_back+rank*7))*r.content->config.character_scale;}
void sync(RunRuntime &r) {auto &w=r.state.loadout.escort;while (w.drones.size()<w.count) {EscortDrone d;d.pos=idle(r,w.drones.size());d.dir=r.state.ship.heading;w.drones.push_back(d);}w.drones.resize(w.count);}
godot::Vector2 offset(const RunRuntime &r,size_t i,godot::Vector2 normal,godot::Vector2 dir,double distance) {const auto &w=r.state.loadout.escort;const double scale=r.content->config.character_scale,rank=i/2+1,side=i%2?1:-1;double deploy=std::clamp(distance/(w.deploy_distance*scale),0.0,1.0);deploy=deploy*deploy*(3-2*deploy);return (orthogonal(dir)*side*w.idle_spacing*rank-dir*(w.idle_back+rank*7)).lerp(normal*side*13*1.82*rank-dir*9*1.82*rank,deploy)*scale;}
}
void DashRangeDroneBehavior::launch(RunRuntime &r) {auto &s=r.state;auto &w=s.loadout.escort;if (!w.ready) return;sync(r);w.active=true;w.hits.clear();w.dash_id=s.draw.dash_id;w.distance=0;w.normals.clear();const auto &pts=s.draw.path;
    for (int64_t i=0;i<pts.size();++i) {const auto before=(i?pts[i]-pts[i-1]:pts[1]-pts[0]).normalized();const auto after=i<pts.size()-1?(pts[i+1]-pts[i]).normalized():before;w.normals.push_back((orthogonal(before)+orthogonal(after))*0.5);}
    godot::Array targets;for (size_t i=0;i<w.drones.size();++i) targets.push_back(s.ship.pos+offset(r,i,orthogonal(s.ship.heading),s.ship.heading,w.deploy_distance*r.content->config.character_scale));godot::Dictionary event;event["pos"]=s.ship.pos;event["targets"]=targets;FrameBuilder::append(r,"escort_deploy",event);for (auto &d:w.drones) {d.trail.clear();d.break_trail=true;}
}
void DashRangeDroneBehavior::end(RunRuntime &r) {r.state.loadout.escort.active=false;}
void DashRangeDroneBehavior::step(RunRuntime &r,double dt) {auto &s=r.state;auto &w=s.loadout.escort;if (!w.ready || dt<=0) return;sync(r);w.active=w.active && s.draw.tracing && s.phase==godot::RunState::Phase::Play;
    for (size_t i=0;i<w.drones.size();++i) {auto &d=w.drones[i];for (auto &p:d.trail) p.life-=dt;d.trail.erase(std::remove_if(d.trail.begin(),d.trail.end(),[](const auto &p){return p.life<=0;}),d.trail.end());if (!w.active) {d.pos=d.pos.lerp(idle(r,i),1-std::exp(-w.return_rate*dt));d.dir=d.dir.lerp(s.ship.heading,1-std::exp(-12*dt)).normalized();}}
}
void DashRangeDroneBehavior::trail(RunRuntime &r,godot::Vector2 p0,godot::Vector2 p1) {auto &s=r.state;auto &w=s.loadout.escort;if (!w.ready || !s.draw.tracing || s.phase!=godot::RunState::Phase::Play) return;if (w.dash_id!=s.draw.dash_id) launch(r);const auto &pts=s.draw.path;const auto seg=s.draw.segment;if (seg>=pts.size()-1 || w.normals.size()!=size_t(pts.size())) return;
    const auto a=pts[seg],b=pts[seg+1];const double length=a.distance_to(b);if (length<0.001) return;const auto dir=(b-a)/length;const double moved=p0.distance_to(p1),start_t=std::clamp(double((p0-a).dot(dir))/length,0.0,1.0),end_t=std::clamp(double((p1-a).dot(dir))/length,0.0,1.0);
    for (size_t i=0;i<w.drones.size();++i) {const auto start=p0+offset(r,i,w.normals[seg].lerp(w.normals[seg+1],start_t),dir,w.distance),end=p1+offset(r,i,w.normals[seg].lerp(w.normals[seg+1],end_t),dir,w.distance+moved);auto &d=w.drones[i];if (d.break_trail || d.pos.distance_to(start)>4*r.content->config.character_scale) d.trail.push_back({start,0.22,false});d.trail.push_back({end,0.22,true});if (d.trail.size()>96) d.trail.erase(d.trail.begin(),d.trail.end()-96);d.pos=end;d.dir=dir;d.break_trail=false;
        const double radius=w.hit_radius*(1+w.area_increment*double(s.loadout.post_area_stacks))*s.loadout.effects.area*r.content->config.character_scale;const double query_radius=radius+std::max(s.combat_config.max_enemy_radius,s.grid.max_radius);const godot::Vector2 pad(query_radius,query_radius);const auto lo=godot::Vector2(std::min(start.x,end.x),std::min(start.y,end.y))-pad,hi=godot::Vector2(std::max(start.x,end.x),std::max(start.y,end.y))+pad;
        for (auto row:CollisionQuery::enemy_rows(s,lo,hi)) {const auto &e=s.enemies[row];if (e.dead || w.hits.count(e.id)) continue;const double t=CollisionQuery::segment_circle_t(start,end,e.pos,e.radius+radius);if (t<0) continue;w.hits.insert(e.id);const auto hit=start.lerp(end,t);godot::Dictionary event;event["pos"]=hit;event["dir"]=dir;FrameBuilder::append(r,"escort_slash",event);DamageRequest request;request.struck=s.enemy_handles.at(uint32_t(row));request.amount=CombatResolver::attack_power(r)*EquipmentSystem::weapon_damage_factor(r,w.definition)*w.damage;request.cause=Cause::DashRangeDrone;request.weapon_id=w.definition;request.direction=dir;request.impact=hit;request.has_impact=true;request.knock=0;request.no_crit=true;CombatResolver::damage_enemy(r,request);EventBuilder::flush_combat(r);if (s.phase!=godot::RunState::Phase::Play) return;}
    }w.distance+=moved;
}
}
