#include "swim.h"
#include "squad.h"
#include "body.h"
#include "regrow.h"
#include "normal_attack.h"
#include "technique.h"
#include "../flow/phase_controller.h"
#include "../flow/technique_runner.h"
#include "../flow/flow_runner.h"
#include "../../systems/field.h"
#include "../../systems/enemy_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attack_system.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include "state.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
godot::Rect2 bounds(const RunRuntime &r,const BossBodyState &b) {for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) return a.bounds;return {};}
bool locked(const RunRuntime &r,const BossBodyState &b) {const auto &e=r.state.enemies[b.actor.slot];return TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked();}
}
const HydraSwimDefinition &HydraSwim::rule(const RunRuntime &r,const BossBodyState &b) {const auto boss=r.content->boss_bodies[b.definition-1].boss;return *std::find_if(r.content->hydra_swim.begin(),r.content->hydra_swim.end(),[&](const auto &p){return p.boss==boss;});}
bool HydraSwim::begin(RunRuntime &r,BossBodyState &b) {
    if (b.hydra->separated) return false;for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) FlowRunner::cancel(r,f);
    for (uint32_t i=0;i<r.state.bosses->techniques.size();++i) {const auto actor=r.state.bosses->techniques[i].actor;if (same_handle(actor,b.actor) || HydraNormalAttack::body(r,actor)==&b) TechniqueRunner::cancel(r,r.state.bosses->handles.at(i));}
    const auto boss_handle=r.state.bosses->body_handles.at(uint32_t(&b-r.state.bosses->bodies.data()));AttackSystem::end_boss(r.state,boss_handle);
    HydraRegrow::set_count(r,b,b.hydra->necks.size());for (auto &n:b.hydra->necks) {n.free_pos=HydraBody::head_position(r,b,n);n.look_angle=n.angle;}
    b.hydra->separated=true;b.hydra->separation_pending=false;b.hydra->chance_left=0;const auto &p=rule(r,b);b.hydra->separation_left=p.separation_time;
    HydraNeckState n;n.free_pos=r.state.enemies[b.actor.slot].pos;n.angle=(n.free_pos-r.state.ship_pos).angle();if (locked(r,b)) n.angle=r.state.enemies[b.actor.slot].facing;n.look_angle=n.angle;n.cd=HydraBody::rule(r,b).attack_cd;
    const auto id=EnemySystem::spawn_part(r,b.actor,p.immortal-1,n.free_pos);if (id<0) {b.hydra->separated=false;b.hydra->separation_pending=true;b.hydra->separation_left=0;return false;}n.actor=r.state.enemy_handles.at(r.state.rows_by_id.at(id));n.id=id;auto &e=r.state.enemies[n.actor.slot];e.hp=e.max_hp=p.immortal_hp*r.content->definitions[r.content->boss_bodies[b.definition-1].enemy-1].scaling.hp_mult;e.armor=0;e.guard=p.separation_time;e.facing=n.angle;n.head_hp=0;b.hydra->bearer=n;b.participants.push_back({n.actor,n.actor,id,false,true});r.state.enemies[b.actor.slot].hp=r.state.enemies[b.actor.slot].max_hp=e.max_hp;
    HydraSquad::init(r,b);HydraNormalAttack::cue(r,b,b.hydra->bearer,"separation_started",0,0,p.separation_time);return true;
}
bool HydraSwim::step(RunRuntime &r,BossBodyState &b,double dt) {
    if (b.hydra->separation_pending) begin(r,b);if (!b.hydra->separated) return false;
    if (b.hydra->separation_left>0) {b.hydra->separation_left=std::max(0.0,b.hydra->separation_left-dt);r.state.enemies[b.actor.slot].guard=b.hydra->separation_left;for (const auto &n:b.hydra->necks) if (HydraRegrow::alive(r,n)) r.state.enemies[n.actor.slot].guard=b.hydra->separation_left;if (HydraRegrow::alive(r,b.hydra->bearer)) r.state.enemies[b.hydra->bearer.actor.slot].guard=b.hydra->separation_left;for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) f.suspended=true;return true;}
    for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) f.suspended=b.mode!=BossMode::Idle;
    auto &n=b.hydra->bearer;if (!HydraRegrow::alive(r,n)) {DamageRequest death=b.hydra->bearer_death;death.struck=b.actor;CombatResolver::kill_enemy(r,death);return true;}
    auto &part=r.state.enemies[n.actor.slot];if (part.hp<n.head_hp) {n.hit_left=0.35;HydraNormalAttack::cue(r,b,n,"hit",0,n.head_hp-std::max(0.0,part.hp));}const bool major=HydraTechnique::busy(r,b);const bool alone=std::none_of(b.hydra->necks.begin(),b.hydra->necks.end(),[&](const auto &v){return HydraRegrow::alive(r,v);});
    if (alone && n.normal) {for (auto &t:r.state.bosses->techniques) if (same_handle(t.actor,n.actor) && t.stage<TechniqueStage::Finished) {HydraNormalAttack::step(r,t,dt);break;}}else {if (alone && n.cd<=0) {for (const auto &normal:r.content->hydra_normals) if (r.content->boss_techniques[normal.technique-1].kind==64) {TechniqueRunner::begin(r,n.actor,normal.technique,"natural_ai");break;}}
        else if (!alone && !major && b.mode==BossMode::Idle) {n.cd=std::max(0.0,n.cd-dt);HydraSquad::tick_bearer(r,b,dt);}else {n.cd=std::max(0.0,n.cd-dt);const auto &p=rule(r,b);auto away=(n.free_pos-r.state.ship_pos).normalized();if (away==godot::Vector2()) away={-1,0};auto target=r.state.ship_pos+away.rotated(std::sin(b.clock*0.7)*0.6)*p.solo_bearer_distance;const auto grid=HydraTechnique::bearer_target(r,b);if (grid) target=*grid;if (grid && n.free_pos.distance_to(target)<45) {n.free_pos=n.free_pos.lerp(target,1-std::exp(-4*dt));n.velocity={};}else steer(r,b,n,target,dt,p.bearer_speed/p.snake_speed,grid.has_value());}}
    if (!alone && !major && b.mode==BossMode::Idle) HydraSquad::update_look(r,b,n,dt,HydraSquadRole::Bearer,false);
    const auto at=HydraBody::head_position(r,b,n);part.pos=at;part.facing=alone || major?n.angle:n.look_angle;part.vel=n.velocity;r.state.enemies[b.actor.slot].pos=at;r.state.enemies[b.actor.slot].hp=part.hp;r.state.enemies[b.actor.slot].vel={};n.head_hp=part.hp;
    HydraSquad::tick(r,b,dt);
    for (auto &v:b.hydra->necks) {if (!HydraRegrow::alive(r,v)) {HydraRegrow::tick_dead(r,b,v,dt);continue;}auto &head=r.state.enemies[v.actor.slot];if (head.hp<v.head_hp) {v.hit_left=0.35;HydraSquad::watch_player(r,b,v,HydraSquad::profile(v));HydraNormalAttack::cue(r,b,v,"hit",v.normal,v.head_hp-std::max(0.0,head.hp));}v.head_hp=head.hp;if (!v.normal) v.cd=std::max(0.0,v.cd-dt);head.pos=HydraBody::head_position(r,b,v);head.facing=v.look_angle;head.vel=v.velocity;}
    b.hydra->recovery_left=std::max(0.0,b.hydra->recovery_left-dt);return true;
}
godot::Vector2 HydraSwim::destination(const RunRuntime &r,const BossBodyState &b,const HydraNeckState &n,godot::Vector2 target,bool formation) {
    const double radius=r.state.enemies[n.actor.slot].radius;const auto rect=bounds(r,b);const auto from=FieldSystem::safe_point(r,rect,n.free_pos,radius+1);auto destination=FieldSystem::safe_point(r,rect,target,formation?radius+12:HydraBody::rule(r,b).neck_rest+radius+24);
    for (const auto &obstacle:r.state.field.bodies) {const double clearance=obstacle.radius+radius+60;if (from.distance_to(obstacle.position)<clearance+120 && CollisionQuery::segment_circle_t(from,destination,obstacle.position,clearance)>=0) {auto outward=(from-obstacle.position).normalized();if (outward==godot::Vector2()) outward={1,0};const double cross=outward.cross(destination-obstacle.position),turn=cross<0?-1:1;destination=FieldSystem::safe_point(r,rect,obstacle.position+outward.rotated(turn*0.6)*clearance,radius+1);break;}}
    return destination;
}
void HydraSwim::steer(RunRuntime &r,BossBodyState &b,HydraNeckState &n,godot::Vector2 target,double dt,double scale,bool formation) {
    const auto &p=rule(r,b);const auto from=FieldSystem::safe_point(r,bounds(r,b),n.free_pos,r.state.enemies[n.actor.slot].radius+1);n.free_pos=from;const auto offset=destination(r,b,n,target,formation)-n.free_pos;const double prior=n.angle;const bool lock=locked(r,b);if (offset.length()>1 && !lock) n.angle+=std::clamp(angle_difference(offset.angle()-n.angle),-p.snake_turn*dt,p.snake_turn*dt);const double speed=p.snake_speed*scale*std::clamp(double(offset.length())/100,0.0,1.0)*(0.3+0.7*std::max(0.0,std::cos(angle_difference(offset.angle()-n.angle))));n.velocity=n.velocity.lerp(godot::Vector2::from_angle(n.angle)*speed,1-std::exp(-p.snake_accel*dt));if (lock) n.velocity=godot::Vector2::from_angle(n.angle)*n.velocity.length();n.free_pos+=n.velocity*dt;n.turn=angle_difference(n.angle-prior)/std::max(dt,0.001);finish_step(r,b,n,from,dt);
}
void HydraSwim::finish_step(RunRuntime &r,BossBodyState &b,HydraNeckState &n,godot::Vector2 from,double dt) {auto &e=r.state.enemies[n.actor.slot];e.pos=n.free_pos;e.vel=n.velocity;FieldSystem::collide_enemy(r,n.actor.slot,from,dt);n.free_pos=FieldSystem::safe_point(r,bounds(r,b),e.pos,e.radius+1);n.velocity=e.vel;const auto rect=bounds(r,b).grow(-e.radius);const auto inside=n.free_pos.clamp(rect.position,rect.get_end());if (inside!=n.free_pos) {const auto inward=(inside-n.free_pos).normalized();n.velocity-=inward*std::min(0.0,double(n.velocity.dot(inward)));n.free_pos=inside;}}
void HydraSwim::follow(RunRuntime &r,BossBodyState &b,HydraNeckState &n,double dt) {
    if (dt<=0) return;const auto &p=HydraBody::rule(r,b);const auto &swim=rule(r,b);const auto head=HydraBody::head_position(r,b,n);if (n.trail.empty()) {n.trail=n.points;std::reverse(n.trail.begin(),n.trail.end());if (n.trail.size()<2) for (uint32_t i=0;i<=p.neck_segments;++i) n.trail.push_back(head-godot::Vector2::from_angle(n.angle)*p.neck_rest*double(i)/p.neck_segments);std::fill(std::begin(n.weights),std::end(n.weights),0);n.hit_left=0;}
    if (n.trail.empty() || head.distance_to(n.trail.front())>=4) n.trail.insert(n.trail.begin(),head);if (n.trail.size()>256) n.trail.resize(256);n.hit_left=std::max(0.0,n.hit_left-dt);const double weight=1-std::exp(-8*dt);const double goals[]={std::clamp(n.velocity.length()/swim.snake_speed,0.0,1.0),std::clamp(std::abs(n.turn)/swim.snake_turn,0.0,1.0),n.hit_left>0?1.:0.,n.normal && n.normal_phase==0?1.:0.,n.normal && n.normal_phase==1?1.:0.,n.normal && n.normal_phase==2?1.:0.};for (int i=0;i<6;++i) n.weights[i]+=(goals[i]-n.weights[i])*weight;
    std::vector<godot::Vector2> path{head};path.insert(path.end(),n.trail.begin(),n.trail.end());n.points.resize(p.neck_segments+1);n.points.back()=head;size_t cursor=1;auto at=head;for (uint32_t i=1;i<=p.neck_segments;++i) {double needed=p.neck_rest/p.neck_segments;while (cursor<path.size() && at.distance_to(path[cursor])<needed) {needed-=at.distance_to(path[cursor]);at=path[cursor++];}const auto direction=cursor<path.size()?(path[cursor]-at).normalized():-godot::Vector2::from_angle(n.angle);at+=direction*needed;const double f=double(i)/p.neck_segments,amplitude=p.neck_wave_amplitude*(0.3+0.7*n.weights[0]),wave=std::sin(b.clock*p.neck_wave_speed*2-f*6.283185307179586*p.neck_wave_frequency+n.base_angle)*amplitude*std::sin(f*3.141592653589793),recoil=std::sin(f*3.141592653589793)*std::sin(b.clock*35-f*5)*n.weights[2]*12;n.points[p.neck_segments-i]=at+direction.orthogonal()*(wave+recoil);}
    const auto rect=bounds(r,b);for (auto &point:n.points) point=FieldSystem::safe_point(r,rect,point,24);
}
bool HydraSwim::bearer_defeated(RunRuntime &r,const DeathContext &death) {for (auto &b:r.state.bosses->bodies) if (b.hydra->separated && same_handle(b.hydra->bearer.actor,death.target)) {b.hydra->bearer_death=death.request;r.state.enemies[b.actor.slot].hp=0;for (auto &p:b.participants) if (same_handle(p.actor,death.target)) p.active=false;return true;}return false;}
}
