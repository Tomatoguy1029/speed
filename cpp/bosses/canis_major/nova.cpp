#include "nova.h"
#include "nova_field.h"
#include "sequence.h"
#include "technique_common.h"
#include "../flow/phase_controller.h"
#include "../../systems/group_system.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
namespace speed {
namespace {
const CanisNovaDefinition &rule(const ContentBundle &c,uint32_t technique) {return *std::find_if(c.canis_novas.begin(),c.canis_novas.end(),[&](const auto &p){return p.technique==technique;});}
bool live(const RunRuntime &r,EnemyHandle h) {return r.state.enemy_handles.contains(h) && !r.state.enemies[h.slot].dead;}
struct NovaTimes {double hound_start=0,flash=0,gather_start=0;};
struct NovaHeadPose {double y=42,rotation=0;};
NovaTimes times(const ContentBundle &c) {
    const auto &fx=c.canis_nova_fx.front();const double lives[]={0.24,0.36,0.52};
    const double roar_end=0.4+lives[fx.roar_level-1]*fx.roar_time*fx.timing;
    const double flash=std::max(roar_end+fx.flash_delay,fx.gather_time);
    return {roar_end+fx.hound_delay,flash,flash-fx.gather_time};
}
NovaHeadPose head_pose(const ContentBundle &c,double age) {
    const auto timing=times(c);
    const double u=std::clamp((age-timing.gather_start)/std::max(timing.flash-timing.gather_start,0.001),0.0,1.0);
    const double charge=age<timing.flash?u*u*(3-2*u):0;
    const double release=age>=0.4?std::max(0.0,1.0-(age-0.4)/0.22):0;
    if (release<=0) return {};
    return {42-charge*3+release*4,-0.12*charge+std::sin(release*godot::Math::PI)*0.11};
}
godot::Vector2 mouth(const RunRuntime &r,EnemyHandle actor,double age) {
    const auto &e=r.state.enemies[actor.slot];
    // canisPose: 咆哮の反動時はHead/Siriusの移動と回転も光源へ反映する。
    const auto pose=head_pose(*r.content,age);
    return e.pos+(godot::Vector2(0,pose.y)+godot::Vector2(0,59).rotated(pose.rotation)).rotated(e.facing-godot::Math::PI/2.0)*(e.radius/100.0);
}
double segment_distance(godot::Vector2 p,godot::Vector2 a,godot::Vector2 b) {const auto d=b-a;const double f=d.length_squared()>0?std::clamp(double((p-a).dot(d))/d.length_squared(),0.0,1.0):0;return p.distance_to(a+d*f);}
void release_pairs(RunRuntime &r,TechniqueState &t,BossBodyState &b) {auto &v=std::get<CanisNovaState>(t.detail);if (v.released) return;v.released=true;for (const auto &m:v.pairs) {if (live(r,m.actor)) GroupSystem::release_order(r.state,m.actor);b.canis.lunging.erase(std::remove_if(b.canis.lunging.begin(),b.canis.lunging.end(),[&](auto h){return same_handle(h,m.actor);}),b.canis.lunging.end());}}
void drop_effect(RunRuntime &r,BossBodyState &b) {if (r.state.bosses.handles.contains(b.canis.nova)) {auto &t=r.state.bosses.techniques[b.canis.nova.slot];if (t.ticket_refs) --t.ticket_refs;}b.canis.nova={};}

}
bool CanisNova::ready(const RunRuntime &r,EnemyHandle actor,uint32_t definition) {const auto *b=PhaseController::find(r,actor);return b && !b->canis.barking && !b->canis.calling && b->canis.led.size()>=rule(*r.content,definition).min_hounds;}
double CanisNova::attack_length(const RunRuntime &r,uint32_t) {const auto timing=times(*r.content);return std::max(timing.flash,timing.hound_start)+1.15+0.1;}
void CanisNova::begin(RunRuntime &r,TechniqueState &t) {
    t.detail=CanisNovaState{};auto &v=std::get<CanisNovaState>(t.detail);auto &b=*PhaseController::find(r,t.actor);const auto &p=rule(*r.content,t.definition);v.started=b.clock;r.state.enemies[t.actor.slot].vel={};
    auto rows=CanisSequence::shuffled(r,b);rows.erase(std::remove_if(rows.begin(),rows.end(),[&](auto h){return std::any_of(b.canis.lunging.begin(),b.canis.lunging.end(),[&](auto a){return same_handle(a,h);});}),rows.end());if (rows.size()>p.count) rows.resize(p.count);
    const double base=(r.state.ship_pos-r.state.enemies[t.actor.slot].pos).angle()+(60+r.state.control.rng.randf_range(-17,17))*godot::Math::PI/180.0;
    for (size_t k=0;k<rows.size();++k) {v.pairs.push_back({rows[k],uint32_t(k/2),base+(k/2)*godot::Math::TAU/3.0,k%2==0?1.0:-1.0,false});b.canis.lunging.push_back(rows[k]);}v.ring_hit.resize(p.rings,false);
    drop_effect(r,b);b.canis.nova=r.state.bosses.handles.at(uint32_t(&t-r.state.bosses.techniques.data()));++t.ticket_refs;CanisTechnique::cue(r,t,"nova_windup");
}
void CanisNova::step(RunRuntime &r,TechniqueState &t,double dt) {auto *b=PhaseController::find(r,t.actor);if (!b) {t.stage=TechniqueStage::Failed;return;}r.state.enemies[t.actor.slot].vel={};if (t.stage==TechniqueStage::Recovery) {t.remaining=std::max(0.0,t.remaining-dt);if (t.remaining<=0) t.stage=TechniqueStage::Finished;return;}const auto &v=std::get<CanisNovaState>(t.detail);const auto &base=r.content->boss_techniques[t.definition-1];const auto timing=times(*r.content);if (b->clock-v.started>=std::max(timing.flash,timing.hound_start)+1.15) {release_pairs(r,t,*b);t.stage=TechniqueStage::Recovery;t.remaining=base.recover;t.locked=false;CanisTechnique::cue(r,t,"recovery_started");}}
void CanisNova::cancel(RunRuntime &r,TechniqueState &t) {if (auto *b=PhaseController::find(r,t.actor)) {release_pairs(r,t,*b);if (r.state.bosses.handles.contains(b->canis.nova) && r.state.bosses.techniques[b->canis.nova.slot].id==t.id) drop_effect(r,*b);}}
void CanisNova::effect_tick(RunRuntime &r,BossBodyState &b,double dt) {
    if (!r.state.bosses.handles.contains(b.canis.nova)) return;auto &t=r.state.bosses.techniques[b.canis.nova.slot];auto &v=std::get<CanisNovaState>(t.detail);const auto &p=rule(*r.content,t.definition);const auto &body=r.state.enemies[t.actor.slot];const double age=b.clock-v.started;const auto timing=times(*r.content);const auto source=mouth(r,t.actor,age);
    const HoundSteering config{p.arrive,p.decel,p.face_turn,p.turn_slow,p.turn_fast,p.turn_switch,p.gather_speed,p.accel};
    for (auto &m:v.pairs) {if (!live(r,m.actor) || v.released || age<timing.hound_start) continue;auto &e=r.state.enemies[m.actor.slot];const auto u=godot::Vector2::from_angle(m.angle),side=u.orthogonal()*p.pair_side*m.side,offset=source-body.pos+side;const double clearance=body.radius+e.radius+p.arrive+4,along=offset.dot(u),exit=-along+std::sqrt(std::max(0.0,along*along+clearance*clearance-offset.length_squared()));const auto goal=source+u*std::max(p.pair_dist,exit)+side;
        if (!m.stationed && e.pos.distance_to(goal)<p.arrive && e.vel.length()<80) {m.stationed=true;GroupSystem::release_order(r.state,m.actor);}if (m.stationed) {GroupSystem::quiet(r.state,m.actor,r.state.world_time+0.3,true,{});const TrackingPolicy tracking{r.state.draw.tracing,e.held,r.state.enemy_handles.contains(e.pump_owner)};e.facing=tracking.angle(e.facing,e.facing+std::clamp(angle_difference(m.angle-e.facing),-p.face_turn*dt,p.face_turn*dt));}else {auto route=goal;const double obstacle=body.radius+e.radius+6;if (segment_distance(body.pos,e.pos,goal)<obstacle) {const double current=(e.pos-body.pos).angle(),turn=angle_difference((goal-body.pos).angle()-current);route=body.pos+godot::Vector2::from_angle(current+std::clamp(turn,-0.6,0.6))*(clearance+16);}GroupSystem::steer(r.state,m.actor,route,source+u*1000,r.state.world_time+0.3,config);}}
    if (age>=timing.flash && !v.flashed) {v.flashed=true;t.stage=TechniqueStage::Active;CanisTechnique::cue(r,t,"nova_flash");}
    if (age>std::max(timing.flash,timing.hound_start)+1.15) drop_effect(r,b);
}
void CanisNova::field_tick(RunRuntime &r,BossBodyState &b) {
    if (!r.state.bosses.handles.contains(b.canis.nova) || !live(r,b.actor)) return;
    auto &t=r.state.bosses.techniques[b.canis.nova.slot];auto &v=std::get<CanisNovaState>(t.detail);const auto &p=rule(*r.content,t.definition);
    const double age=b.clock-v.started;const auto timing=times(*r.content);const auto source=mouth(r,t.actor,age);
    if (!CanisNovaField::update(r,b,v,source,p.ring_end)) return;
    if (age>=timing.flash+0.09 && age<timing.flash+0.42 && !CanisNovaField::safe(r,v,source,p.ring_end)) CanisTechnique::hit(r,t,r.content->boss_techniques[t.definition-1].damage,Cause::Nova);
}
void CanisNova::clear(RunRuntime &r,BossBodyState &b) {if (r.state.bosses.handles.contains(b.canis.nova)) release_pairs(r,r.state.bosses.techniques[b.canis.nova.slot],b);drop_effect(r,b);}
bool CanisNova::tinted(const RunRuntime &r,const BossBodyState &b,EnemyHandle actor) {if (!r.state.bosses.handles.contains(b.canis.nova)) return false;const auto &v=std::get<CanisNovaState>(r.state.bosses.techniques[b.canis.nova.slot].detail);return !v.released && std::any_of(v.pairs.begin(),v.pairs.end(),[&](const auto &m){return same_handle(m.actor,actor);});}
bool CanisNova::validate(const TechniqueState &t,const ContentBundle &c) {const auto *v=std::get_if<CanisNovaState>(&t.detail);if (!v || !std::isfinite(v->started) || v->started<0 || v->ring_hit.size()!=rule(c,t.definition).rings) return false;std::unordered_set<uint64_t> seen;for (const auto &m:v->pairs) if (!seen.insert(handle_key(m.actor)).second || !std::isfinite(m.angle) || (m.side!=1 && m.side!=-1)) return false;for (const auto &s:v->shadows) if (!std::isfinite(s.angle) || !std::isfinite(s.half) || !std::isfinite(s.near) || s.half<0 || s.near<0) return false;if (!v->field_alpha.empty() && (!v->field_origin.is_finite() || !std::isfinite(v->field_cell) || v->field_cell<=0 || v->field_width==0 || v->field_height==0 || uint64_t(v->field_width)*v->field_height!=v->field_alpha.size() || v->field_frame<0 || v->field_revision==0)) return false;return true;}
bool CanisNova::validate_body(const godot::RunState &s,const ContentBundle &c,const BossBodyState &b) {if (!b.canis.nova.generation) return true;if (!s.bosses.handles.contains(b.canis.nova)) return false;const auto &t=s.bosses.techniques[b.canis.nova.slot];return same_handle(t.actor,b.actor) && t.ticket_refs>0 && c.boss_techniques[t.definition-1].kind==49 && validate(t,c);}
double CanisNova::progress(const RunRuntime &r,const TechniqueState &t) {const auto *b=PhaseController::find(r,t.actor);const auto timing=times(*r.content);if (!b || t.stage!=TechniqueStage::Windup) return 0;const double u=std::clamp((b->clock-std::get<CanisNovaState>(t.detail).started-timing.gather_start)/std::max(timing.flash-timing.gather_start,0.001),0.0,1.0);return u*u*(3-2*u);}
godot::Dictionary CanisNova::snapshot(const RunRuntime &r,const TechniqueState &t) {
    const auto &v=std::get<CanisNovaState>(t.detail);const auto &p=rule(*r.content,t.definition);const auto *b=PhaseController::find(r,t.actor);
    const double age=(b?b->clock:0)-v.started;const auto timing=times(*r.content);const auto pose=head_pose(*r.content,age);
    godot::Dictionary out;out["age"]=age;out["started"]=v.started;out["flashed"]=v.flashed;out["released"]=v.released;
    out["windup_progress"]=progress(r,t);out["glow"]=age<timing.flash?progress(r,t):std::max(0.0,1.0-(age-timing.flash)/1.15);
    out["source"]=mouth(r,t.actor,age);out["radius"]=r.state.enemies[t.actor.slot].radius;out["head_y"]=pose.y;out["head_rotation"]=pose.rotation;out["warn"]=timing.flash;out["gather_start"]=timing.gather_start;out["hound_start"]=timing.hound_start;out["after"]=1.15;out["ring_end"]=p.ring_end;
    godot::PackedByteArray alpha;alpha.resize(v.field_alpha.size());if (!v.field_alpha.empty()) std::copy(v.field_alpha.begin(),v.field_alpha.end(),alpha.ptrw());
    out["field_alpha"]=alpha;out["field_origin"]=v.field_origin;out["field_cell"]=v.field_cell;out["field_width"]=v.field_width;out["field_height"]=v.field_height;out["field_revision"]=int64_t(v.field_revision);
    out["ship_position"]=r.state.ship_pos;out["hit_visual"]=age>=timing.flash+0.09 && age<timing.flash+0.42 && !CanisNovaField::safe(r,v,mouth(r,t.actor,age),p.ring_end);
    godot::Array pairs;for (const auto &m:v.pairs) {godot::Dictionary q;q["actor"]=r.state.enemy_handles.entity_id(m.actor);q["group"]=m.group;q["angle"]=m.angle;q["side"]=m.side;q["stationed"]=m.stationed;q["position"]=live(r,m.actor)?r.state.enemies[m.actor.slot].pos:godot::Vector2();pairs.push_back(q);}out["pairs"]=pairs;
    return out;
}
void CanisNova::body_snapshot(const RunRuntime &r,const BossBodyState &b,godot::Dictionary &out) {out["nova"]=r.state.bosses.handles.contains(b.canis.nova)?snapshot(r,r.state.bosses.techniques[b.canis.nova.slot]):godot::Dictionary();}
}
