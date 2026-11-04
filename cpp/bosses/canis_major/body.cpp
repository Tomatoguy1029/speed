#include "body.h"
#include "image_pose.h"
#include "fire_visual.h"
#include "roar.h"
#include "howl.h"
#include "blaze.h"
#include "nova.h"
#include "relay.h"
#include "../flow/phase_controller.h"
#include "../../systems/enemy_system.h"
#include "../../systems/group_system.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void face(RunRuntime &r,BossBodyState &b,double dt) {auto &e=r.state.enemies[b.actor.slot];const auto &d=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1];const double prior=e.facing;if (!TrackingPolicy{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)}.locked()) e.facing+=std::clamp(angle_difference((r.state.enemy_aim-e.pos).angle()-e.facing),-d.turn*dt,d.turn*dt);b.canis.turn_motion=angle_difference(e.facing-prior)/std::max(dt,0.001);}
bool opens_lane(const RunRuntime &r,const BossBodyState &b) {for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,b.actor) && (t.stage==TechniqueStage::Windup || t.stage==TechniqueStage::Active)) {const auto kind=r.content->boss_techniques[t.definition-1].kind;if (kind==43) return true;if (const auto *v=std::get_if<CanisRelayState>(&t.detail)) return v->aiming;if (const auto *v=std::get_if<CanisHuntState>(&t.detail)) return v->aiming;}return false;}
void resize(godot::RunState::Enemy &e,double hp) {e.hp=hp*e.hp/std::max(0.001,e.max_hp);e.max_hp=hp;}
void scan(RunRuntime &r,BossBodyState &b) {
    auto &s=r.state;const auto &p=CanisMajorBody::rule(r,b);const auto at=s.enemies[b.actor.slot].pos;
    std::vector<std::pair<double,EnemyHandle>> found;
    for (uint32_t i=0;i<s.enemies.size();++i) {const auto &e=s.enemies[i];if (!e.alive || e.dead || r.content->definitions[e.definition].kind!=EnemyDefinition::Kind::Hound) continue;const auto actor=s.enemy_handles.at(i);if (CanisBlaze::burning(b,actor)) continue;const bool was=std::any_of(b.canis.led.begin(),b.canis.led.end(),[&](const auto &v){return same_handle(v.actor,actor);});const double distance=at.distance_squared_to(e.pos);if (!was && (CanisHowl::in_ring(b,actor) || std::any_of(b.canis.lunging.begin(),b.canis.lunging.end(),[&](auto v){return same_handle(v,actor);}))) continue;if (was || distance<=p.lead_radius*p.lead_radius) found.push_back({distance,actor});}
    std::sort(found.begin(),found.end(),[](const auto &a,const auto &b){return a.first==b.first?a.second.slot<b.second.slot:a.first<b.first;});if (found.size()>p.lead_max) found.resize(p.lead_max);
    std::vector<CanisHoundRef> next;for (const auto &entry:found) {const auto actor=entry.second;const auto old=std::find_if(b.canis.led.begin(),b.canis.led.end(),[&](const auto &v){return same_handle(v.actor,actor);});const auto &e=s.enemies[actor.slot];next.push_back(old==b.canis.led.end()?CanisHoundRef{actor,e.max_hp,r.content->definitions[e.definition].color}:*old);}
    for (const auto &old:b.canis.led) if (s.enemy_handles.contains(old.actor) && std::none_of(next.begin(),next.end(),[&](const auto &v){return same_handle(v.actor,old.actor);})) {auto &e=s.enemies[old.actor.slot];resize(e,old.base_hp);}
    std::sort(next.begin(),next.end(),[&](const auto &a,const auto &b){return s.enemy_handles.entity_id(a.actor)<s.enemy_handles.entity_id(b.actor);});b.canis.led=std::move(next);
    const auto &c=s.combat_config;double burst=std::max(1.0,s.loadout.full_charge_maximum);
    const double power=c.base_attack*c.attack_mult*c.atk_scale*burst;for (const auto &v:b.canis.led) {auto &e=s.enemies[v.actor.slot];resize(e,std::max(v.base_hp,power*(std::max(1.0,p.led_hits)-0.5)));}
}
void spawn_pack(RunRuntime &r,BossBodyState &b,bool call) {
    const auto &p=CanisMajorBody::rule(r,b);const auto &e=r.state.enemies[b.actor.slot];const auto at=e.pos;const double facing=e.facing,radius=e.radius;const int count=call?std::max(0,int(p.call_to)-int(b.canis.led.size())):int(p.pack_size);
    for (int k=0;k<count;++k) {EnemySpawn options;options.has_hound_pack=true;options.hound_pack=-r.state.enemy_handles.entity_id(b.actor);options.has_facing=true;options.facing=facing;options.position=call?at+godot::Vector2::from_angle(facing+3.141592653589793+r.state.control.rng.randf_range(-1,1))*120.0:at-godot::Vector2::from_angle(facing+(double(k)/std::max(1,count-1)-0.5)*2.2)*(radius+70);EnemySystem::spawn(r,p.hound-1,options);}
    b.canis.pack_spawned=true;b.canis.lead_scan=0;if (!call) scan(r,b);
}
}
const CanisBodyDefinition &CanisMajorBody::rule(const RunRuntime &r,const BossBodyState &b) {const auto boss=r.content->boss_bodies[b.definition-1].boss;return *std::find_if(r.content->canis_bodies.begin(),r.content->canis_bodies.end(),[&](const auto &p){return p.boss==boss;});}
EnemyHandle CanisMajorBody::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {if (!definition || definition>r.content->boss_bodies.size() || r.content->bosses[r.content->boss_bodies[definition-1].boss-1].kind!=2 || r.content->canis_bodies.empty()) return {};const auto actor=PhaseController::spawn(r,definition,at,entrance);if (auto *b=PhaseController::find(r,actor)) {spawn_pack(r,*b,false);CanisImagePose::update(r,*b);}return actor;}
void CanisMajorBody::call_tick(RunRuntime &r,BossBodyState &b,double dt) {auto &e=r.state.enemies[b.actor.slot];e.vel={};face(r,b,dt);b.canis.call_left-=dt;e.charge=1;if (b.canis.call_left<=0) {if (b.canis.calling) {spawn_pack(r,b,true);b.canis.call_ready_at=b.clock+rule(r,b).call_cd;}b.canis.calling=b.canis.barking=false;e.charge=0;}}
void CanisMajorBody::step(RunRuntime &r,BossBodyState &b,double dt) {auto &e=r.state.enemies[b.actor.slot];const auto &p=rule(r,b);e.charge=0;b.canis.turn_motion=0;if (b.canis.led.size()<p.call_below && b.clock>=b.canis.call_ready_at) {b.canis.calling=true;b.canis.call_left=p.call_time;e.vel={};return;}face(r,b,dt);if (e.pos.distance_to(r.state.enemy_aim)<=e.radius) {e.vel={};return;}const auto from=e.pos;const double speed=b.phase>=2?p.speed_p2:r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].speed;e.pos+=godot::Vector2::from_angle(e.facing)*speed*dt;e.vel=(e.pos-from)/dt;FieldSystem::collide_enemy(r,b.actor.slot,from,dt);}
void CanisMajorBody::lead(RunRuntime &r,BossBodyState &b,double dt) {
    if (!b.canis.pack_spawned) spawn_pack(r,b,false);const auto &p=rule(r,b);auto &s=r.state;const auto &e=s.enemies[b.actor.slot];b.canis.lead_scan-=dt;if (b.canis.lead_scan<=0) {b.canis.lead_scan=p.lead_scan;scan(r,b);}const auto forward=godot::Vector2::from_angle(e.facing),side=forward.orthogonal(),origin=e.pos+forward*(e.radius+20);int rows=0;while ((rows+1)*(rows+4)/2<=b.canis.led.size()) ++rows;rows=std::max(rows+1,1);const double spacing=std::min(p.slot_back,std::max(0.0,double(origin.distance_to(s.enemy_aim))-40)/rows);int row=1,column=0;
    for (const auto &v:b.canis.led) {if (!s.enemy_handles.contains(v.actor) || s.enemies[v.actor.slot].dead) continue;const auto id=s.enemy_handles.entity_id(v.actor);if (!CanisHowl::in_ring(b,v.actor) && std::none_of(b.canis.lunging.begin(),b.canis.lunging.end(),[&](auto a){return same_handle(a,v.actor);})) {auto *order=GroupSystem::order(s,v.actor);if (order && order->canis_howl_rest) {GroupSystem::quiet(s,v.actor,s.world_time+0.3,true,{});order->canis_howl_rest=true;}else {const double phase=std::fmod(id*2.3999632297,6.283185307179586);double lateral=(column-row*0.5)*p.slot_side,ahead=spacing*row;if (opens_lane(r,b)) {lateral+=p.lane_open*(godot::Math::is_zero_approx(lateral)?(column%2==0?1:-1):lateral>0?1:-1);ahead=p.lane_forward+spacing*(row-1);}auto goal=origin+forward*ahead+side*lateral;goal+=godot::Vector2(std::sin(b.clock*1.3+phase),std::cos(b.clock*1.1+phase*1.7))*p.form_wobble;if (b.mode==BossMode::Entrance || b.canis.barking) goal=e.pos-forward*(e.radius+spacing*row)+side*(column-row*0.5)*p.slot_side;const double scale=p.form_speed_min+(p.form_speed_max-p.form_speed_min)*std::fmod(id*0.6180339887,1.0);GroupSystem::follow(s,v.actor,goal,s.world_time+0.3,p.lead_catch_up*scale);}}if (++column>row) {++row;column=0;}}
}
void CanisMajorBody::release(RunRuntime &r,BossBodyState &b) {CanisFireVisualSystem::clear(b);CanisNova::clear(r,b);CanisBlaze::clear(r,b);for (const auto &v:b.canis.ring) GroupSystem::release_order(r.state,v.actor);b.canis.ring.clear();b.canis.ring_started=-1;b.canis.ring_definition=0;for (const auto &v:b.canis.led) if (r.state.enemy_handles.contains(v.actor)) {auto &e=r.state.enemies[v.actor.slot];GroupSystem::release_order(r.state,v.actor);resize(e,v.base_hp);}b.canis.led.clear();b.canis.lunging.clear();b.canis.lunge_hits.clear();b.canis.barking=b.canis.calling=false;}
void CanisMajorBody::reset_trial(RunRuntime &r,BossBodyState &b) {
    const auto group=-r.state.enemy_handles.entity_id(b.actor);release(r,b);
    for (uint32_t row=0;row<r.state.enemies.size();++row) if (r.state.enemies[row].alive && r.state.enemies[row].group_id==group) EnemySystem::retire(r,r.state.enemy_handles.at(row),RetireReason::Development);
    b.canis={};spawn_pack(r,b,false);CanisImagePose::update(r,b);
}
godot::Color CanisMajorBody::color(const RunRuntime &r,EnemyHandle actor,godot::Color base) {for (const auto &b:r.state.bosses.bodies) if (r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].kind==2) if (CanisBlaze::burning(b,actor) || CanisNova::tinted(r,b,actor) || CanisRelay::tinted(r,b,actor)) return godot::Color(0.8117647,0.9372549,1.0,1.0);else for (const auto &v:b.canis.led) if (same_handle(v.actor,actor)) {const auto &p=rule(r,b);return {p.led_r,p.led_g,p.led_b,p.led_a};}return base;}
bool CanisMajorBody::validate(const godot::RunState &s,const ContentBundle &c,const BossBodyState &b) {if (c.bosses[c.boss_bodies[b.definition-1].boss-1].kind!=2) return true;if (!CanisHowl::validate_ring(b,c) || !CanisBlaze::validate_body(s,c,b) || !CanisNova::validate_body(s,c,b) || !CanisRoar::validate(b,c) || !CanisFireVisualSystem::validate(b,c)) return false;for (double x:{b.canis.call_left,b.canis.call_ready_at,b.canis.lead_scan,b.canis.turn_motion}) if (!std::isfinite(x)) return false;for (const auto &v:b.canis.led) if (!std::isfinite(v.base_hp) || v.base_hp<=0 || (s.enemy_handles.contains(v.actor) && c.definitions[s.enemies[v.actor.slot].definition].kind!=EnemyDefinition::Kind::Hound)) return false;return true;}
void CanisMajorBody::snapshot(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &p) {CanisHowl::body_snapshot(r,b,p);CanisBlaze::body_snapshot(r,b,p);CanisNova::body_snapshot(r,b,p);if (b.image_parts.size()==7) p["image_pose"]=CanisImagePose::snapshot(r,b);p["roar"]=CanisRoar::snapshot(r,b);p["fire_visual"]=CanisFireVisualSystem::snapshot(r,b);p["barking"]=b.canis.barking;p["calling"]=b.canis.calling;p["call_left"]=b.canis.call_left;p["turn_motion"]=b.canis.turn_motion;godot::Array led;for (const auto &v:b.canis.led) {if (!r.state.enemy_handles.contains(v.actor) || r.state.enemies[v.actor.slot].dead) continue;godot::Dictionary q;q["id"]=r.state.enemy_handles.entity_id(v.actor);q["hp"]=r.state.enemies[v.actor.slot].hp;q["max_hp"]=r.state.enemies[v.actor.slot].max_hp;q["base_hp"]=v.base_hp;led.push_back(q);}p["led"]=led;}
}
