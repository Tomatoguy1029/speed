#include "body.h"
#include "squad.h"
#include "regrow.h"
#include "normal_attack.h"
#include "technique.h"
#include "swim.h"
#include "../flow/phase_controller.h"
#include "../flow/technique_runner.h"
#include "../../systems/enemy_system.h"
#include "../../systems/field.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <array>
#include <cmath>
namespace speed {
namespace {
constexpr double pi=3.14159265358979323846,tau=2*pi;
double toward(double from,double to,double step) {return from+std::clamp(to-from,-step,step);}
godot::Vector2 base(const RunRuntime &r,const BossBodyState &b,const HydraNeckState &n) {if (b.hydra.separated) return n.free_pos-godot::Vector2::from_angle(n.angle)*HydraBody::rule(r,b).neck_rest;const auto &e=r.state.enemies[b.actor.slot];return e.pos+godot::Vector2::from_angle(n.base_angle+e.facing)*e.radius;}
godot::Vector2 head(const RunRuntime &r,const BossBodyState &b,const HydraNeckState &n) {
    auto at=n.major && (r.content->boss_techniques[n.major-1].kind!=88 || n.locked)?n.strike_pos:b.hydra.separated?(n.extension || (&n==&b.hydra.bearer && n.locked && n.normal)?n.strike_pos:n.free_pos):n.locked && (n.normal || n.major)?n.strike_pos:base(r,b,n)+godot::Vector2::from_angle(n.angle)*n.length;const double radius=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].radius:40;
    if (r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead) if (auto hit=FieldSystem::first_body_hit(r,r.state.enemies[n.actor.slot].pos,at,radius)) if (hit->body!=UINT32_MAX) {const auto &obstacle=r.state.field.bodies[hit->body];at=obstacle.position+(hit->point-obstacle.position).normalized()*(obstacle.radius+radius+0.1);}
    for (const auto &arena:r.state.field.arenas) if (same_handle(arena.owner,b.actor)) return FieldSystem::safe_point(r,arena.bounds,at,radius);
    return at;
}
void chain(RunRuntime &r,BossBodyState &b,HydraNeckState &n,double dt) {
    const auto &p=HydraBody::rule(r,b);auto &points=n.points;const auto root=base(r,b,n),tip=head(r,b,n);const auto delta=tip-root;const double distance=delta.length();const auto direction=distance>0.001?delta/distance:godot::Vector2(1,0),side=direction.orthogonal();const double rest=n.actor.generation?p.neck_rest:std::min(p.neck_rest,n.length),length=std::max(distance,rest*std::max(1.0,p.neck_slack)),segment=length/p.neck_segments;
    const bool initial=points.size()!=p.neck_segments+1;const auto shift=initial?godot::Vector2():root-points[0];points.resize(p.neck_segments+1);
    if (length-distance<0.001) {for (uint32_t i=0;i<=p.neck_segments;++i) points[i]=root.lerp(tip,double(i)/p.neck_segments);return;}
    const double phase=n.base_angle*2.4,bend=std::sqrt(std::max(0.0,length*length-distance*distance))*0.45,sign=std::sin(phase)>=0?1:-1,amplitude=std::min(p.neck_wave_amplitude,bend*0.6),weight=initial?1:1-std::exp(-p.neck_response*dt);
    points[0]=root;points.back()=tip;for (uint32_t i=1;i<p.neck_segments;++i) {const double f=double(i)/p.neck_segments,wave=std::sin(b.clock*p.neck_wave_speed+phase+f*p.neck_wave_frequency*tau)*amplitude;const auto guide=root.lerp(tip,f)+side*std::sin(f*pi)*(bend*sign+wave);points[i]=initial?guide:(points[i]+shift).lerp(guide,weight);}
    for (uint32_t pass=0;pass<p.neck_iterations;++pass) {points.back()=tip;auto previous=tip;for (int i=int(p.neck_segments)-1;i>=0;--i) {const auto offset=points[i]-previous;const double sq=offset.length_squared();previous+=sq>0.000001?offset*(segment/std::sqrt(sq)):-direction*segment;points[i]=previous;}points[0]=root;previous=root;for (uint32_t i=1;i<=p.neck_segments;++i) {const auto offset=points[i]-previous;const double sq=offset.length_squared();previous+=sq>0.000001?offset*(segment/std::sqrt(sq)):direction*segment;points[i]=previous;}if (points.back().distance_squared_to(tip)<0.0001) break;}
    points.back()=tip;const auto center=r.state.enemies[b.actor.slot].pos;const double radius=r.state.enemies[b.actor.slot].radius;const auto outward=points[0]-center;if ((points[1]-points[0]).dot(outward)<0) points[1]=points[0]+outward.normalized()*std::max(4.0,double(points[1].distance_to(points[0])));for (size_t i=1;i+1<points.size();++i) {const auto offset=points[i]-center;if (offset.length()<radius+12) points[i]=center+offset.normalized()*(radius+12);}
}
}
const HydraBodyDefinition &HydraBody::rule(const RunRuntime &r,const BossBodyState &b) {const auto id=r.content->boss_bodies[b.definition-1].boss;return *std::find_if(r.content->hydra_bodies.begin(),r.content->hydra_bodies.end(),[&](const auto &p){return p.boss==id;});}
EnemyHandle HydraBody::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {if (!definition || definition>r.content->boss_bodies.size() || r.content->bosses[r.content->boss_bodies[definition-1].boss-1].kind!=3) return {};return PhaseController::spawn(r,definition,at,entrance);}
void HydraBody::spawned(RunRuntime &r,BossBodyState &b) {
    auto &s=r.state;const auto &p=rule(r,b);const auto at=s.enemies[b.actor.slot].pos;const auto center=(at+s.ship_pos)*0.5;const auto size=godot::Vector2(p.arena_x,p.arena_y).max((at-s.ship_pos).abs()+godot::Vector2(900,900));const godot::Rect2 bounds(center-size*0.5,size);s.field.arenas.push_back({b.actor,bounds});
    const auto clear=[&](godot::Vector2 point,double radius){return bounds.grow(p.arena_wall_thickness+80+radius).has_point(point)?FieldSystem::safe_point(r,bounds,point,radius+12):point;};
    for (auto &e:s.enemies) {e.body_gap=-1;if (e.alive && !e.dead && e.id!=s.enemy_handles.entity_id(b.actor)) {const auto next=clear(e.pos,e.radius);if (next!=e.pos) {e.pos=next;e.vel={};}}}
    for (auto &shot:s.hostiles) shot.gap=0;
    for (auto &rock:s.field.rocks) if (!rock.destroyed) {const auto pos=FieldSystem::rock_at(r,rock),next=clear(pos,rock.size);if (next!=pos) {rock.position=next;rock.velocity={};}}
    for (size_t row=0;row<s.pickups.gems.size();++row) {auto &v=s.pickups.gems[row];if (v.alive) {const auto next=clear(v.pos,12);if (next!=v.pos) {s.pickups.move_gem(row,next);v.velocity={};}}}
    for (auto &v:s.pickups.coins) if (v.alive) v.pos=clear(v.pos,12);for (auto &v:s.pickups.capsules) v.pos=clear(v.pos,24);
    b.hydra.major_cd=0;for (const auto &v:r.content->hydra_majors) if (r.content->boss_techniques[v.technique-1].boss==r.content->boss_bodies[b.definition-1].boss) b.hydra.major_cd=v.global_cd*0.6;
    HydraRegrow::set_count(r,b,3);
}
void HydraBody::reset_trial(RunRuntime &r,BossBodyState &b,uint32_t stage) {
    release(r,b);b.hydra={};const auto id=r.state.enemy_handles.entity_id(b.actor);b.participants={{b.actor,b.actor,id,true,true}};auto &e=r.state.enemies[b.actor.slot];e.hp=e.max_hp=r.content->definitions[e.definition].hp;e.armor=0;spawned(r,b);
    if (stage>=2) HydraRegrow::set_count(r,b,stage>=3?8:5);
    const auto &regrow=HydraRegrow::rule(r,b);e.hp=e.max_hp*(stage>=3?regrow.growth_second:stage==2?regrow.growth_first:1.0);
    if (stage==4) {HydraSwim::begin(r,b);b.hydra.separation_left=0;}
    b.hydra.growth_left=b.hydra.major_cd=b.hydra.combo_left=b.hydra.recovery_left=b.hydra.major_padding_left=0;b.hydra.separation_pending=false;e.guard=0;
    for (auto &n:b.hydra.necks) {n.cd=0;n.length=rule(r,b).neck_rest;if (HydraRegrow::alive(r,n)) {auto &part=r.state.enemies[n.actor.slot];part.guard=0;part.pos=head(r,b,n);follow_neck(r,b,n,0);}}
    if (stage==4 && HydraRegrow::alive(r,b.hydra.bearer)) r.state.enemies[b.hydra.bearer.actor.slot].guard=0;
    for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) {f.participants={b.actor};for (const auto &n:b.hydra.necks) f.participants.push_back(n.actor);f.suspended=false;}
}
EnemyHandle HydraBody::trial_actor(RunRuntime &r,BossBodyState &b,uint32_t definition) {
    auto actor=b.actor;if (HydraNormalAttack::supports(r.content->boss_techniques[definition-1].kind)) {
        const auto spec=std::find_if(r.content->hydra_normals.begin(),r.content->hydra_normals.end(),[&](const auto &v){return v.technique==definition;});if (spec==r.content->hydra_normals.end()) return {};
        const auto it=std::find_if(b.hydra.necks.begin(),b.hydra.necks.end(),[&](const auto &n){return uint32_t(n.kind)==spec->head_kind && HydraRegrow::alive(r,n);});if (it==b.hydra.necks.end()) return {};auto &n=*it;n.cd=0;actor=n.actor;
        for (const auto &gate:r.content->hydra_normal_gates) if (gate.technique==definition) {const auto origin=gate.distance_origin==1?head(r,b,n):gate.distance_origin==2?base(r,b,n):r.state.enemies[b.actor.slot].pos;const double distance=(gate.minimum+std::min(gate.maximum,std::max(gate.minimum,800.0)))*0.5,angle=r.state.enemies[b.actor.slot].facing+(gate.angle_origin==1?n.base_angle:0)+gate.angle;const auto target=origin+godot::Vector2::from_angle(angle)*distance;r.state.ship.pos=r.state.ship_pos=target;r.state.enemy_aim=target;break;}
    }
    return actor;
}
godot::Vector2 HydraBody::neck_base(const RunRuntime &r,const BossBodyState &b,const HydraNeckState &n) {return base(r,b,n);}
godot::Vector2 HydraBody::head_position(const RunRuntime &r,const BossBodyState &b,const HydraNeckState &n) {return head(r,b,n);}
void HydraBody::follow_neck(RunRuntime &r,BossBodyState &b,HydraNeckState &n,double dt) {if (b.hydra.separated) HydraSwim::follow(r,b,n,dt);else chain(r,b,n,dt);}
void HydraBody::step(RunRuntime &r,BossBodyState &b,double dt) {
    b.hydra.attack_field_advance=false;const bool separating=b.hydra.separation_left>0;
    // 部位の再生成は表示の行番号ではなく、この更新で生きている世代へ接続する。
    for (auto &f:r.state.bosses->flows) if (same_handle(f.actor,b.actor)) {f.participants={b.actor};for (const auto &n:b.hydra.necks) f.participants.push_back(n.actor);}
    if (HydraRegrow::growth_tick(r,b,dt)) return;
    b.hydra.major_cd=std::max(0.0,b.hydra.major_cd-dt);b.hydra.combo_left=std::max(0.0,b.hydra.combo_left-dt);b.hydra.major_padding_left=std::max(0.0,b.hydra.major_padding_left-dt);
    if (HydraSwim::step(r,b,dt)) {b.hydra.attack_field_advance=!separating && b.hydra.separation_left<=0 && b.mode<BossMode::Defeated;if (!separating && b.hydra.separation_left<=0 && b.mode<BossMode::Defeated) for (auto &t:r.state.bosses->techniques) if (HydraNormalAttack::supports(r.content->boss_techniques[t.definition-1].kind) && t.stage<TechniqueStage::Finished && !same_handle(t.actor,b.hydra.bearer.actor) && HydraNormalAttack::body(r,t.actor)==&b) HydraNormalAttack::step(r,t,dt);return;}
    b.hydra.attack_field_advance=true;const auto &p=rule(r,b);auto &e=r.state.enemies[b.actor.slot];const auto &d=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1];const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};const auto delta=r.state.ship_pos-e.pos;const double distance=std::max(1.0,double(delta.length()));const bool swim=distance>p.engage || !godot::Rect2(r.state.view_center-r.state.view_half,r.state.view_half*2).grow(-e.radius).has_point(e.pos);bool resting=false;for (const auto &flow:r.state.bosses->flows) if (same_handle(flow.actor,b.actor) && flow.rest_remaining>0) resting=true;
    const bool major=HydraTechnique::busy(r,b);
    if (!resting && !major && b.hydra.recovery_left<=0) {const auto want=swim?tracking.velocity(e.vel,e.facing,delta/distance*d.speed):godot::Vector2();e.vel+=(want-e.vel)*std::min(1.0,p.accel*dt);if (swim && !tracking.locked()) e.facing+=std::clamp(angle_difference(delta.angle()-e.facing),-d.turn*dt,d.turn*dt);const auto from=e.pos;e.pos+=e.vel*dt;FieldSystem::collide_enemy(r,b.actor.slot,from,dt);for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) {const auto rect=a.bounds.grow(-e.radius-p.neck_rest-80);e.pos=e.pos.clamp(rect.position,rect.get_end());}} else e.vel={};
    b.hydra.recovery_left=std::max(0.0,b.hydra.recovery_left-dt);HydraRegrow::chance_tick(r,b,dt);
    HydraTechnique::front_body(r,b,dt);const double body_facing=r.state.enemies[b.actor.slot].facing;
    std::array<bool,8> normal_before{};for (size_t i=0;i<b.hydra.necks.size();++i) normal_before[i]=b.hydra.necks[i].normal!=0;
    for (auto &t:r.state.bosses->techniques) if (HydraNormalAttack::supports(r.content->boss_techniques[t.definition-1].kind) && t.stage<TechniqueStage::Finished && HydraNormalAttack::body(r,t.actor)==&b) HydraNormalAttack::step(r,t,dt);
    for (auto &n:b.hydra.necks) {if (n.normal || normal_before[size_t(&n-b.hydra.necks.data())]) continue;if (n.major) {if (HydraRegrow::alive(r,n)) {const double hp=r.state.enemies[n.actor.slot].hp;if (hp<n.head_hp) {n.hit_left=0.35;HydraNormalAttack::cue(r,b,n,"hit",n.major,n.head_hp-std::max(0.0,hp));}n.head_hp=hp;}continue;}if (HydraRegrow::tick_dead(r,b,n,dt)) {if (HydraRegrow::alive(r,n)) r.state.enemies[n.actor.slot].pos=head(r,b,n);continue;}if (r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead) {n.cd=std::max(0.0,n.cd-dt);n.aim_wait=std::max(0.0,n.aim_wait-dt);if (!n.has_aim || n.aim_wait<=0) {n.has_aim=true;n.aim_target=r.state.ship_pos;n.aim_wait=p.aim_refresh;}const double facing=n.base_angle+body_facing;const auto offset=n.aim_target-base(r,b,n),forward=godot::Vector2::from_angle(facing);const double local=std::atan2(offset.dot(forward.orthogonal()),std::max(p.aim_deadzone,double(offset.dot(forward)))),desired=facing+std::clamp(local,-0.8,0.8)+std::sin(b.clock+n.base_angle)*0.06;if (!tracking.locked()) {const double diff=angle_difference(desired-n.angle),speed=std::min(p.aim_turn,std::sqrt(2*p.aim_accel*std::abs(diff))),velocity=toward(n.aim_velocity,(diff>0?1:diff<0?-1:0)*speed,p.aim_accel*dt);double move=velocity*dt;if (move*diff>=0 && std::abs(move)>std::abs(diff)) move=diff;n.angle+=move;n.aim_velocity=move/dt;}n.length=toward(n.length,p.neck_rest,p.neck_rest*dt);auto &part=r.state.enemies[n.actor.slot];part.pos=head(r,b,n);part.facing=n.angle;part.vel={};n.head_hp=part.hp;}else n.length=std::max(0.0,n.length-p.neck_rest*dt);}
}
void HydraBody::finish_frame(RunRuntime &r,double dt) {for (auto &b:r.state.bosses->bodies) if (!b.hydra.necks.empty() && b.hydra.attack_field_advance && b.mode<BossMode::Defeated) {for (auto &n:b.hydra.necks) {if (HydraRegrow::alive(r,n)) {auto &e=r.state.enemies[n.actor.slot];e.pos=head(r,b,n);e.facing=b.hydra.separated && !n.major?n.look_angle:n.angle;}if (n.actor.generation || n.length>0) follow_neck(r,b,n,dt);}if (b.hydra.separated) follow_neck(r,b,b.hydra.bearer,dt);}}
void HydraBody::part_defeated(RunRuntime &r,const DeathContext &death) {if (!HydraSwim::bearer_defeated(r,death)) HydraRegrow::part_defeated(r,death);}

void HydraBody::release(RunRuntime &r,BossBodyState &b) {for (uint32_t i=0;i<r.state.bosses->techniques.size();++i) if (HydraNormalAttack::body(r,r.state.bosses->techniques[i].actor)==&b) TechniqueRunner::cancel(r,r.state.bosses->handles.at(i));if (HydraRegrow::alive(r,b.hydra.bearer)) EnemySystem::retire(r,b.hydra.bearer.actor,RetireReason::Development);auto &arenas=r.state.field.arenas;arenas.erase(std::remove_if(arenas.begin(),arenas.end(),[&](const auto &a){return same_handle(a.owner,b.actor);}),arenas.end());for (auto &n:b.hydra.necks) if (r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead) EnemySystem::retire(r,n.actor,RetireReason::Development);}
bool HydraBody::passes(const RunRuntime &r,EnemyHandle actor) {for (const auto &b:r.state.bosses->bodies) if (same_handle(b.actor,actor)) return b.hydra.separated;return false;}
bool HydraBody::owns_part(const RunRuntime &r,EnemyHandle actor) {for (const auto &t:r.state.bosses->techniques) if (const auto *v=std::get_if<HydraTechniqueState>(&t.detail)) if (const auto *move=std::get_if<HydraTornadoState>(&v->move)) if (std::any_of(move->rubble.begin(),move->rubble.end(),[&](auto h){return same_handle(h,actor);})) return true;for (const auto &b:r.state.bosses->bodies) {if (same_handle(b.hydra.bearer.actor,actor)) return true;for (const auto &n:b.hydra.necks) if (same_handle(n.actor,actor)) return true;}return false;}
bool HydraBody::validate(const godot::RunState &s,const ContentBundle &c,const BossBodyState &b) {
    if (c.bosses[c.boss_bodies[b.definition-1].boss-1].kind!=3) return true;
    if ((b.hydra.necks.size()!=3 && b.hydra.necks.size()!=5 && b.hydra.necks.size()!=8) || b.participants.size()!=b.hydra.necks.size()+(b.hydra.separated?2:1) || !HydraRegrow::validate(b) || !std::isfinite(b.hydra.separation_left) || b.hydra.separation_left<0) return false;
    if (!HydraSquad::validate(b.hydra)) return false;
    for (const auto &used:b.hydra.major_until) if (!used.first || used.first>c.boss_techniques.size() || !std::isfinite(used.second) || used.second<0) return false;
    const bool active=b.mode<BossMode::Defeated;size_t arenas=0;for (const auto &a:s.field.arenas) if (same_handle(a.owner,b.actor)) ++arenas;if (arenas!=size_t(active)) return false;
    const auto valid=[&](const HydraNeckState &n,const ParticipantState &part) {
        if (n.major>c.boss_techniques.size() || n.kind>=HydraHeadKind::Count || n.id<=0 || n.id!=part.id || part.is_body || !same_handle(part.actor,part.health_target) || n.normal_phase>2 || n.normal>c.boss_techniques.size() || n.trail.size()>256) return false;
        if (active && part.active && (!s.enemy_handles.contains(n.actor) || s.enemies[n.actor.slot].dead || !same_handle(n.actor,part.actor) || !same_handle(s.enemies[n.actor.slot].parent,b.actor))) return false;
        for (const auto v:{n.aim_target,n.free_pos,n.velocity,n.strike_from,n.strike_pos,n.target}) if (!v.is_finite()) return false;
        for (double v:{n.base_angle,n.angle,n.length,n.head_hp,n.cd,n.aim_wait,n.aim_velocity,n.look_angle,n.elapsed,n.glow,n.turn,n.hit_left,n.sweep}) if (!std::isfinite(v)) return false;
        for (double v:n.weights) if (!std::isfinite(v) || v<0 || v>1) return false;
        for (const auto point:n.points) if (!point.is_finite()) return false;for (const auto point:n.trail) if (!point.is_finite()) return false;
        if (n.normal && (!HydraNormalAttack::supports(c.boss_techniques[n.normal-1].kind) || !std::any_of(s.bosses->techniques.begin(),s.bosses->techniques.end(),[&](const auto &t){return same_handle(t.actor,n.actor) && t.definition==n.normal && t.stage<TechniqueStage::Finished;}))) return false;
        return true;
    };
    for (size_t i=0;i<b.hydra.necks.size();++i) if (!valid(b.hydra.necks[i],b.participants[i+1])) return false;
    if (b.hydra.separated && !valid(b.hydra.bearer,b.participants.back())) return false;
    return true;
}
void HydraBody::snapshot(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &out) {out["tactic"]=b.hydra.squad.tactic;out["counter_time"]=b.hydra.squad.counter_time;out["pair_launched"]=b.hydra.squad.pair_launched;out["effects"]=HydraNormalAttack::shapes(r,b);out["north_targets"]=HydraTechnique::north_targets(r,b);out["separation_left"]=b.hydra.separation_left;out["separation_pending"]=b.hydra.separation_pending;out["separated"]=b.hydra.separated;out["growth_left"]=b.hydra.growth_left;out["chance_left"]=b.hydra.chance_left;out["count"]=uint32_t(b.hydra.necks.size());for (const auto &a:r.state.field.arenas) if (same_handle(a.owner,b.actor)) out["arena"]=a.bounds;out["arena_wall_thickness"]=rule(r,b).arena_wall_thickness;godot::Array necks;for (const auto &n:b.hydra.necks) {godot::Dictionary v;v["role"]=uint32_t(HydraSquad::profile(n));v["counter"]=n.motion.counter;v["reserved"]=n.motion.reserved;v["ready"]=n.motion.ready;v["squad_goal"]=n.motion.goal;v["look_on"]=n.motion.look_on;v["look_time"]=n.motion.look_time;v["id"]=n.id;v["kind"]=symbol_name(n.kind);v["mode"]=n.major?godot::String(r.content->boss_techniques[n.major-1].external_id.c_str()):n.normal?godot::String(r.content->boss_techniques[n.normal-1].external_id.c_str()):godot::String("idle");v["elapsed"]=n.elapsed;v["normal_phase"]=n.normal_phase;v["locked"]=n.locked;v["glow"]=n.glow;v["free_pos"]=n.free_pos;v["velocity"]=n.velocity;v["look_angle"]=n.look_angle;v["cd"]=n.cd;v["burned"]=n.burned;v["regrow"]=n.regrow;v["angle"]=n.angle;v["facing"]=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].facing:n.angle;v["hp"]=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].hp:0;v["max_hp"]=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].max_hp:0;v["length"]=n.length;v["head_hp"]=n.head_hp;v["alive"]=r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead;v["position"]=head(r,b,n);v["radius"]=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].radius:40;godot::PackedVector2Array points;for (const auto point:n.points) points.push_back(point);v["points"]=points;necks.push_back(v);}if (b.hydra.separated) {const auto &n=b.hydra.bearer;godot::Dictionary v;v["id"]=n.id;v["kind"]="immortal";v["alive"]=HydraRegrow::alive(r,n);v["position"]=head(r,b,n);v["facing"]=r.state.enemy_handles.contains(n.actor)?r.state.enemies[n.actor.slot].facing:n.look_angle;v["length"]=n.length;v["hp"]=HydraRegrow::alive(r,n)?r.state.enemies[n.actor.slot].hp:0;v["cd"]=n.cd;v["velocity"]=n.velocity;v["glow"]=n.glow;godot::PackedVector2Array points;for (const auto point:n.points) points.push_back(point);v["points"]=points;out["bearer"]=v;}out["necks"]=necks;}
}
