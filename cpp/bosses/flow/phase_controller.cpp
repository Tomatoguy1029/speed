#include "phase_controller.h"
#include "../monoceros/body.h"
#include "../centaurus/body.h"
#include "../centaurus/finish.h"
#include "../canis_major/body.h"
#include "../canis_major/flames.h"
#include "../canis_major/hound_lunge.h"
#include "../monoceros/horn_wave.h"
#include "flow_runner.h"
#include "technique_runner.h"
#include "../../systems/enemy_system.h"
#include "../../systems/attack_system.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/tracking_policy.h"
#include "../../systems/motion_math.h"
#include "../../output/frame_builder.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
void event(RunRuntime &r,const char *type,const BossBodyState &b) {godot::Dictionary p;p["id"]=r.state.enemy_handles.entity_id(b.actor);p["boss"]=godot::String(r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].external_id.c_str());if (std::string(type)=="boss_phase") {p["phase"]=b.phase;p["reason"]="hp_threshold";}FrameBuilder::append(r,type,p);}
bool busy(const RunRuntime &r,EnemyHandle actor) {for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,actor) && t.stage<TechniqueStage::Finished) return true;return false;}
void end_actions(RunRuntime &r,BossBodyState &b) {
    CanisMajorBody::release(r,b);b.centaurus.leaping=false;
    for (auto &f:r.state.bosses.flows) if (same_handle(f.actor,b.actor)) {FlowRunner::cancel(r,f);f.selection_enabled=false;f.blocked=true;}
    for (uint32_t row=0;row<r.state.bosses.techniques.size();++row) if (same_handle(r.state.bosses.techniques[row].actor,b.actor)) TechniqueRunner::cancel(r,r.state.bosses.handles.at(row));
    if (r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];e.vel={};e.charge=e.guard=0;}
    const auto handle=r.state.bosses.body_handles.at(uint32_t(&b-r.state.bosses.bodies.data()));AttackSystem::end_boss(r.state,handle);
}
}
BossBodyState *PhaseController::find(RunRuntime &r,EnemyHandle actor) {for (auto &b:r.state.bosses.bodies) if (same_handle(b.actor,actor)) return &b;return nullptr;}
const BossBodyState *PhaseController::find(const RunRuntime &r,EnemyHandle actor) {for (const auto &b:r.state.bosses.bodies) if (same_handle(b.actor,actor)) return &b;return nullptr;}
bool PhaseController::can_start(const RunRuntime &r,EnemyHandle actor) {for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,actor) && t.reposition>0) return false;const auto *body=find(r,actor);return !body || (body->mode==BossMode::Idle && body->initial_wait<=0 && (!body->phase_pending || r.content->bosses[r.content->boss_bodies[body->definition-1].boss-1].kind==1) && !body->centaurus.leaping);}
EnemyHandle PhaseController::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {
    auto &s=r.state;if (!definition || definition>r.content->boss_bodies.size() || !at.is_finite() || s.bosses.next_body_id==INT64_MAX) return {};
    const auto &p=r.content->boss_bodies[definition-1];EnemySpawn options;options.position=at;options.facing=(s.ship_pos-at).angle();options.has_facing=true;options.is_boss=true;
    const auto id=EnemySystem::spawn_base(r,p.enemy-1,options);if (id<0) return {};const auto actor=s.enemy_handles.at(s.rows_by_id.at(id));
    BossBodyState body;body.id=s.bosses.next_body_id++;body.definition=definition;body.actor=actor;body.initial_wait=p.initial_wait;body.entrance_target=at;body.participants.push_back({actor,actor,id,true,true});
    s.bosses.body_handles.attach(s.bosses.bodies.size(),body.id);s.bosses.bodies.push_back(body);
    if (r.content->bosses[p.boss-1].kind==1) CentaurusBody::spawned(r,s.bosses.bodies.back());
    if (entrance) {auto &created=s.bosses.bodies.back();created.mode=BossMode::Entrance;created.entrance_from=at-godot::Vector2(std::max(1000.0,double(s.view_half.x)*2.0),0);s.enemies[actor.slot].pos=created.entrance_from;s.enemies[actor.slot].facing=0;}
    for (const auto &flow:r.content->boss_flows) if (flow.boss==p.boss) {FlowRunner::attach(r,actor,flow.id);s.bosses.flows.back().suspended=entrance || p.initial_wait>0;break;}
    // 登場を確定した入口だけで立てる。撃破や取消では戻さない。
    s.world.boss_spawned=true;godot::Dictionary e;e["pos"]=at;FrameBuilder::append(r,"boss_spawn",e);return actor;
}
void PhaseController::damaged(RunRuntime &r,EnemyHandle actor) {
    auto *b=find(r,actor);if (!b || b->phase!=1) return;auto &e=r.state.enemies[actor.slot];const auto &p=r.content->boss_bodies[b->definition-1];
    if (e.hp/e.max_hp<=p.phase_threshold) {if (p.hp_floor_enabled) e.hp=e.max_hp*p.phase_threshold;b->phase_pending=true;}
}
bool PhaseController::can_defeat(const RunRuntime &r,EnemyHandle actor) {const auto *b=find(r,actor);return !b || b->phase!=1 || !r.content->boss_bodies[b->definition-1].hp_floor_enabled;}
void PhaseController::defeated(RunRuntime &r,const DeathContext &death) {
    auto *b=find(r,death.target);if (!b || b->mode==BossMode::Defeated || b->mode==BossMode::Cancelled) return;end_actions(r,*b);b->mode=BossMode::Defeated;for (auto &p:b->participants) p.active=false;r.state.enemies[death.target.slot].hp=0;r.state.boss_dead=true;
    godot::Dictionary p;p["pos"]=death.corpse.pos;p["id"]=death.corpse.id;p["dir"]=death.request.direction;p["cause"]=symbol_name(death.request.cause);FrameBuilder::append(r,"boss_defeated",p);
}
void PhaseController::cancel(RunRuntime &r,EnemyHandle actor) {
    auto *b=find(r,actor);if (!b || b->mode==BossMode::Cancelled || b->mode==BossMode::Defeated) return;end_actions(r,*b);b->mode=BossMode::Cancelled;for (auto &p:b->participants) p.active=false;event(r,"boss_cancelled",*b);
}
bool PhaseController::begin_final(RunRuntime &r,EnemyHandle actor,double charge) {
    auto *b=find(r,actor);if (!b || !std::isfinite(charge) || b->mode==BossMode::Final || b->mode==BossMode::Defeated || b->mode==BossMode::Cancelled) return false;
    end_actions(r,*b);b->mode=BossMode::Final;b->final_started=r.state.time;b->final_charge=std::max(0.1,charge);b->final_elapsed=0;godot::Dictionary p;FrameBuilder::append(r,"final_strike",p);return true;
}
void PhaseController::step(RunRuntime &r,double dt) {
    if (dt<=0) return;auto &s=r.state;
    for (auto &b:s.bosses.bodies) {
        if (b.mode==BossMode::Defeated || b.mode==BossMode::Cancelled) continue;
        if (!s.enemy_handles.contains(b.actor) || s.enemies[b.actor.slot].dead) {cancel(r,b.actor);continue;}
        auto &e=s.enemies[b.actor.slot];const auto &p=r.content->boss_bodies[b.definition-1];const auto &definition=r.content->bosses[p.boss-1];b.clock+=dt;if (definition.kind==2) b.canis.turn_motion=0;
        if (definition.kind==1) CentaurusBody::pre_step(r,b,dt);
        e.flash=std::max(0.0,e.flash-dt);e.hit_cd=std::max(0.0,e.hit_cd-dt);bool suspend=true;
        if (b.mode==BossMode::Entrance) {
            b.entrance_elapsed+=dt;const double progress=std::clamp(b.entrance_elapsed/std::max(0.05,p.entrance_time),0.0,1.0);const auto prior=e.pos;e.pos=b.entrance_from.lerp(b.entrance_target,1.0-std::pow(1.0-progress,3.0));e.vel=(e.pos-prior)/dt;
            if (progress>=1) {b.mode=BossMode::Idle;e.vel={};if (definition.kind==2) {b.canis.barking=true;b.canis.call_left=CanisMajorBody::rule(r,b).entrance_bark;}}
        } else if (definition.kind==2 && (b.canis.barking || b.canis.calling)) {
            CanisMajorBody::call_tick(r,b,dt);
        } else if (b.mode==BossMode::Phase) {
            b.phase_remaining=std::max(0.0,b.phase_remaining-dt);
            if (definition.kind==1 || definition.kind==2) {e.vel={};const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};if (!tracking.locked()) e.facing+=std::clamp(angle_difference((s.enemy_aim-e.pos).angle()-e.facing),-definition.turn*dt,definition.turn*dt);}
            if (b.phase_remaining<=0) b.mode=BossMode::Idle;
        } else if (b.mode==BossMode::Final) {
            b.final_elapsed=std::max(0.0,s.time-b.final_started);const auto aim=TrackingPolicy{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,s.ship_pos);const auto direction=aim-e.pos;
            e.vel={};e.facing+=std::clamp(angle_difference(direction.angle()-e.facing),-definition.turn*dt,definition.turn*dt);e.guard=1;e.charge=std::clamp(b.final_elapsed/b.final_charge,0.0,1.0);
            b.final_to=e.pos+direction.normalized()*p.final_reach;const double widen=std::clamp((b.final_elapsed-(b.final_charge-p.final_widen_time))/p.final_widen_time,0.0,1.0);b.final_width=p.final_warn_width+(p.final_beam_width-p.final_warn_width)*widen*widen;
            if (!b.final_landed && b.final_elapsed>=b.final_charge) {b.final_landed=true;s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;request.source=e.definition+1;CombatResolver::ship_damage(r,request);}
        } else if (definition.kind==1 && b.centaurus.leaping) {
            CentaurusFinish::leap_tick(r,b,dt);
        } else if (!busy(r,b.actor)) {
            if (b.phase_pending) {b.phase_pending=false;b.phase=2;b.mode=BossMode::Phase;b.phase_remaining=p.phase_time;event(r,"boss_phase",b);}
            else {b.initial_wait=std::max(0.0,b.initial_wait-dt);suspend=b.initial_wait>0;if (definition.kind==0) MonocerosBody::step(r,b,dt);else if (definition.kind==1) {CentaurusBody::step(r,b,dt);suspend=suspend || b.centaurus.leaping;}else if (definition.kind==2) {CanisMajorBody::step(r,b,dt);suspend=suspend || b.canis.calling;}}
        } else suspend=false;
        for (auto &f:s.bosses.flows) if (same_handle(f.actor,b.actor)) {f.phase=b.phase;f.suspended=suspend;}
    }
}
bool PhaseController::validate(const godot::RunState &s,const ContentBundle &c) {
    for (uint32_t row=0;row<s.bosses.bodies.size();++row) {const auto &b=s.bosses.bodies[row];if (b.id<=0 || b.id>=s.bosses.next_body_id || s.bosses.body_handles.entity_id(s.bosses.body_handles.at(row))!=b.id || !b.definition || b.definition>c.boss_bodies.size() || b.mode>BossMode::Cancelled || b.phase<1 || b.phase>2 || !b.entrance_from.is_finite() || !b.entrance_target.is_finite() || !b.final_to.is_finite() || !b.slash_from.is_finite() || !b.slash_to.is_finite()) return false;
        if ((b.sweep_side!=1 && b.sweep_side!=-1) || b.participants.size()!=1 || b.participants[0].id<=0 || !same_handle(b.participants[0].actor,b.actor) || !same_handle(b.participants[0].health_target,b.actor) || !b.participants[0].is_body || b.participants[0].active!=(b.mode<BossMode::Defeated)) return false;
        if (!CanisMajorBody::validate(s,c,b)) return false;
        for (double value:{b.clock,b.initial_wait,b.entrance_elapsed,b.phase_remaining,b.final_elapsed,b.final_charge,b.final_width}) if (!std::isfinite(value) || value<0) return false;
        if (!CentaurusBody::validate(s,c,b)) return false;
        if (!std::isfinite(b.final_started) || (b.mode<BossMode::Defeated && (!s.enemy_handles.contains(b.actor) || s.enemies[b.actor.slot].dead))) return false;
    }return true;
}
godot::Array PhaseController::snapshot(const RunRuntime &r) {
    godot::Array out;for (const auto &b:r.state.bosses.bodies) {godot::Dictionary p;p["id"]=b.id;p["definition"]=b.definition;p["actor"]=r.state.enemy_handles.entity_id(b.actor);p["mode"]=int(b.mode);p["phase"]=b.phase;p["pending"]=b.phase_pending;p["clock"]=b.clock;p["initial_wait"]=b.initial_wait;p["phase_remaining"]=b.phase_remaining;p["final_elapsed"]=b.final_elapsed;p["final_landed"]=b.final_landed;p["final_to"]=b.final_to;p["final_width"]=b.final_width;p["boss_spawned"]=r.state.world.boss_spawned;p["boss_dead"]=r.state.boss_dead;
        const auto &definition=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1];p["kind"]=int(definition.kind);if (definition.kind==2) {CanisMajorBody::snapshot(r,b,p);p["flames"]=CanisFlames::snapshot(r,b);p["lunges"]=CanisHoundLunge::snapshot(r,b);}p["phase_progress"]=b.phase>=2?(b.mode==BossMode::Phase?1.0-b.phase_remaining/std::max(0.001,r.content->boss_bodies[b.definition-1].phase_time):1.0):0.0;
        godot::Array participants;for (const auto &part:b.participants) {godot::Dictionary v;v["id"]=part.id;v["health_target"]=part.id;v["is_body"]=part.is_body;v["active"]=part.active;participants.push_back(v);}p["participants"]=participants;
        if (definition.kind==1) {const auto &v=b.centaurus;p["guard_point"]=v.guard_point;p["has_guard_point"]=v.has_guard_point;p["guard_scan"]=v.guard_scan;p["guard_refill"]=v.guard_refill;p["path_hold"]=v.path_hold;p["turn_motion"]=v.turn_motion;p["leaping"]=v.leaping;p["leap_elapsed"]=v.leap_elapsed;p["leap_progress"]=std::clamp(v.leap_elapsed/std::max(0.001,std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &entry){return entry.body==b.definition;})->leap_time),0.0,1.0);p["leap_from"]=v.leap_from;p["leap_to"]=v.leap_to;p["leap_ready_at"]=v.leap_ready_at;p["retreat_ready_at"]=v.retreat_ready_at;p["cooldowns"]=int64_t(v.cooldowns.size());godot::Array guards;for (const auto &g:v.guards) {godot::Dictionary q;q["id"]=r.state.enemy_handles.entity_id(g.actor);q["scale"]=g.scale;q["phase"]=g.phase;guards.push_back(q);}p["guards"]=guards;}
        if (r.state.enemy_handles.contains(b.actor)) {const auto &e=r.state.enemies[b.actor.slot];p["velocity"]=e.vel;p["flash"]=e.flash;p["horn_length"]=e.radius*(definition.horn_length_ratio+(definition.horn_length_ratio_p2-definition.horn_length_ratio)*double(p["phase_progress"]));p["position"]=e.pos;p["facing"]=e.facing;p["radius"]=e.radius;p["hp"]=e.hp;p["max_hp"]=e.max_hp;p["charge"]=e.charge;p["horn_waves"]=MonocerosHornWave::waves(r,b.actor);godot::PackedVector2Array slash;if (b.has_slash) {slash.push_back(b.slash_from);slash.push_back(b.slash_to);}p["last_slash"]=slash;}out.push_back(p);
    }return out;
}
}
