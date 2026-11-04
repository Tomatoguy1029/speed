#include "phase_controller.h"
#include "../monoceros/body.h"
#include "../centaurus/body.h"
#include "../centaurus/finish.h"
#include "../canis_major/body.h"
#include "../hydra/body.h"
#include "../hydra/finish.h"
#include "../hydra/regrow.h"
#include "../draco/body.h"
#include "../draco/intro.h"
#include "../draco/cycle.h"
#include "../draco/picaro.h"
#include "../draco/rifts.h"
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
    if (r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].kind==4) DracoBody::cancel(r,b);
    CanisMajorBody::release(r,b);b.centaurus.leaping=false;
    for (auto &f:r.state.bosses.flows) if (same_handle(f.actor,b.actor)) {FlowRunner::cancel(r,f);f.selection_enabled=false;f.blocked=true;}
    for (uint32_t row=0;row<r.state.bosses.techniques.size();++row) if (same_handle(r.state.bosses.techniques[row].actor,b.actor)) TechniqueRunner::cancel(r,r.state.bosses.handles.at(row));
    if (r.state.enemy_handles.contains(b.actor)) {auto &e=r.state.enemies[b.actor.slot];e.vel={};e.charge=e.guard=0;}
    const auto handle=r.state.bosses.body_handles.at(uint32_t(&b-r.state.bosses.bodies.data()));AttackSystem::end_boss(r.state,handle);
}
}
BossBodyState *PhaseController::find(RunRuntime &r,EnemyHandle actor) {for (auto &b:r.state.bosses.bodies) if (same_handle(b.actor,actor)) return &b;return nullptr;}
const BossBodyState *PhaseController::find(const RunRuntime &r,EnemyHandle actor) {for (const auto &b:r.state.bosses.bodies) if (same_handle(b.actor,actor)) return &b;return nullptr;}
bool PhaseController::can_start(const RunRuntime &r,EnemyHandle actor) {for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,actor) && t.reposition>0) return false;const auto *body=find(r,actor);return !body || (body->mode==BossMode::Idle && body->draco.cycle.stage==DracoCycleStage::None && body->draco.closing_walls.empty() && body->initial_wait<=0 && (!body->phase_pending || r.content->bosses[r.content->boss_bodies[body->definition-1].boss-1].kind==1) && !body->centaurus.leaping);}
bool PhaseController::automatic(RunRuntime &r) {
    auto &s=r.state;auto &c=s.control;
    if (r.content->stage_boss.empty() || (c.lab_mode && s.world.boss_spawned)) return true;
    const auto &p=r.content->stage_boss.front();
    if (c.boss_at<0) {c.boss_at=p.start;if (p.spread>0) c.boss_at+=c.rng.randf()*p.spread;}
    if (s.lifecycle.endless || s.world.boss_spawned || s.time<c.boss_at) return true;
    const double distance=std::min(1000.0,double(s.view_half.length())*0.65);
    auto at=s.ship_pos+godot::Vector2::from_angle(c.rng.randf()*godot::Math::TAU)*distance;
    for (const auto &body:s.field.bodies) if (!body.moon) {
        if (at.distance_to(body.position)<body.radius+180.0) at=body.position+(s.ship_pos-body.position).normalized()*(body.radius+220.0);
        break;
    }
    if (at.length()>s.ship_config.field_radius-160.0) at=at.normalized()*(s.ship_config.field_radius-160.0);
    const auto &body=r.content->boss_bodies[p.body-1];
    const auto actor=r.content->bosses[body.boss-1].kind==4?DracoBody::spawn(r,p.body,at,true):spawn(r,p.body,at,true);
    return s.enemy_handles.contains(actor);
}
EnemyHandle PhaseController::spawn(RunRuntime &r,uint32_t definition,godot::Vector2 at,bool entrance) {
    auto &s=r.state;if (!definition || definition>r.content->boss_bodies.size() || !at.is_finite() || s.bosses.next_body_id==INT64_MAX) return {};
    const auto &p=r.content->boss_bodies[definition-1];EnemySpawn options;options.position=at;options.facing=(s.ship_pos-at).angle();options.has_facing=true;options.is_boss=true;
    const auto id=EnemySystem::spawn_base(r,p.enemy-1,options);if (id<0) return {};const auto actor=s.enemy_handles.at(s.rows_by_id.at(id));
    BossBodyState body;body.id=s.bosses.next_body_id++;body.definition=definition;body.actor=actor;body.initial_wait=p.initial_wait;body.entrance_target=at;body.participants.push_back({actor,actor,id,true,true});
    s.bosses.body_handles.attach(s.bosses.bodies.size(),body.id);s.bosses.bodies.push_back(body);
    if (r.content->bosses[p.boss-1].kind==3) HydraBody::spawned(r,s.bosses.bodies.back());
    if (r.content->bosses[p.boss-1].kind==1) CentaurusBody::spawned(r,s.bosses.bodies.back());
    if (entrance && r.content->bosses[p.boss-1].kind!=3) {auto &created=s.bosses.bodies.back();created.mode=BossMode::Entrance;created.entrance_from=at-godot::Vector2(std::max(1000.0,double(s.view_half.x)*2.0),0);s.enemies[actor.slot].pos=created.entrance_from;s.enemies[actor.slot].facing=0;}
    for (const auto &flow:r.content->boss_flows) if (flow.boss==p.boss) {FlowRunner::attach(r,actor,flow.id);s.bosses.flows.back().suspended=entrance || p.initial_wait>0;break;}
    // 登場を確定した入口だけで立てる。撃破や取消では戻さない。
    s.world.boss_spawned=true;godot::Dictionary e;e["pos"]=at;FrameBuilder::append(r,"boss_spawn",e);return actor;
}
void PhaseController::damaged(RunRuntime &r,EnemyHandle actor) {
    auto *b=find(r,actor);if (b && r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==4) {DracoBody::damaged(r,*b);return;}if (!b || b->phase!=1) return;if (r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==3) {HydraRegrow::damaged(r,*b);if (!b->hydra.separated && r.state.enemies[actor.slot].hp<=0) b->hydra.separation_pending=true;return;}auto &e=r.state.enemies[actor.slot];const auto &p=r.content->boss_bodies[b->definition-1];
    if (e.hp/e.max_hp<=p.phase_threshold) {if (p.hp_floor_enabled) e.hp=e.max_hp*p.phase_threshold;b->phase_pending=true;}
}
bool PhaseController::can_defeat(RunRuntime &r,EnemyHandle actor) {auto *b=find(r,actor);if (b && r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==4) return false;if (b && r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==3) {if (b->hydra.separated) return !HydraRegrow::alive(r,b->hydra.bearer);b->hydra.separation_pending=true;return false;}return !b || b->phase!=1 || !r.content->boss_bodies[b->definition-1].hp_floor_enabled;}
void PhaseController::defeated(RunRuntime &r,const DeathContext &death) {
    auto *b=find(r,death.target);if (!b || b->mode==BossMode::Defeated || b->mode==BossMode::Cancelled) return;TechniqueRunner::finish_scripted(r,*b);end_actions(r,*b);HydraBody::release(r,*b);b->mode=BossMode::Defeated;for (auto &p:b->participants) p.active=false;r.state.enemies[death.target.slot].hp=0;r.state.boss_dead=true;
    godot::Dictionary p;p["pos"]=death.corpse.pos;p["id"]=death.corpse.id;p["dir"]=death.request.direction;p["cause"]=symbol_name(r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==3?Cause::Ram:death.request.cause);FrameBuilder::append(r,"boss_defeated",p);
}
void PhaseController::cancel(RunRuntime &r,EnemyHandle actor) {
    auto *b=find(r,actor);if (!b || b->mode==BossMode::Cancelled || b->mode==BossMode::Defeated) return;TechniqueRunner::finish_scripted(r,*b,"actor_end");end_actions(r,*b);HydraBody::release(r,*b);b->mode=BossMode::Cancelled;for (auto &p:b->participants) p.active=false;event(r,"boss_cancelled",*b);
}
bool PhaseController::begin_final(RunRuntime &r,EnemyHandle actor,double charge) {
    auto *b=find(r,actor);if (!b || !std::isfinite(charge) || b->mode==BossMode::Final || b->mode==BossMode::Defeated || b->mode==BossMode::Cancelled) return false;
    end_actions(r,*b);b->mode=BossMode::Final;b->final_started=r.state.time;b->final_charge=std::max(0.1,charge);b->final_elapsed=0;TechniqueRunner::observe_scripted(r,*b,"final_strike","final_strike_replay",ObservationEvent::Warning,true);if (r.content->bosses[r.content->boss_bodies[b->definition-1].boss-1].kind==3) HydraFinish::begin(r,*b);godot::Dictionary p;FrameBuilder::append(r,"final_strike",p);return true;
}
void PhaseController::step(RunRuntime &r,double dt) {
    if (dt<=0) return;auto &s=r.state;
    for (auto &b:s.bosses.bodies) {
        if (b.mode==BossMode::Defeated || b.mode==BossMode::Cancelled) continue;
        if (!s.enemy_handles.contains(b.actor) || s.enemies[b.actor.slot].dead) {cancel(r,b.actor);continue;}
        const auto &p=r.content->boss_bodies[b.definition-1];const auto &definition=r.content->bosses[p.boss-1];b.clock+=dt;if (definition.kind==4) {DracoPicaro::tick(r,b);if (!b.draco.intro.active) DracoRifts::tick_closing(r,b,dt);}auto &e=s.enemies[b.actor.slot];if (definition.kind==2) b.canis.turn_motion=0;
        b.monoceros_slashes.erase(std::remove_if(b.monoceros_slashes.begin(),b.monoceros_slashes.end(),[&](const auto &slash){return b.clock-slash.started>r.content->config.fx_monoceros_slash_life;}),b.monoceros_slashes.end());
        if (definition.kind==3 && b.mode!=BossMode::Final) {e.flash=std::max(0.0,e.flash-dt);e.hit_cd=std::max(0.0,e.hit_cd-dt);HydraBody::step(r,b,dt);continue;}
        if (definition.kind==1) CentaurusBody::pre_step(r,b,dt);
        e.flash=std::max(0.0,e.flash-dt);e.hit_cd=std::max(0.0,e.hit_cd-dt);bool suspend=true;
        if (definition.kind==4 && b.draco.intro.active) {DracoIntro::tick(r,b,dt);
        } else if (definition.kind==4 && DracoCycle::tick(r,b,dt)) {
        } else if (b.mode==BossMode::Entrance) {
            b.entrance_elapsed+=dt;const double progress=std::clamp(b.entrance_elapsed/std::max(0.05,p.entrance_time),0.0,1.0);const auto prior=e.pos;e.pos=b.entrance_from.lerp(b.entrance_target,1.0-std::pow(1.0-progress,3.0));e.vel=(e.pos-prior)/dt;
            if (progress>=1) {b.mode=BossMode::Idle;e.vel={};if (definition.kind==2) {b.canis.barking=true;b.canis.call_left=CanisMajorBody::rule(r,b).entrance_bark;}}
        } else if (definition.kind==2 && (b.canis.barking || b.canis.calling)) {
            CanisMajorBody::call_tick(r,b,dt);
        } else if (b.mode==BossMode::Phase) {
            b.phase_remaining=std::max(0.0,b.phase_remaining-dt);
            if (definition.kind==1 || definition.kind==2) {e.vel={};const TrackingPolicy tracking{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)};if (!tracking.locked()) e.facing+=std::clamp(angle_difference((s.enemy_aim-e.pos).angle()-e.facing),-definition.turn*dt,definition.turn*dt);}
            if (b.phase_remaining<=0) {b.mode=BossMode::Idle;if (definition.kind==4) {e.guard=0;s.encounter_protected=false;}}
        } else if (b.mode==BossMode::Final) {
            if (definition.kind!=4 && !b.final_landed) TechniqueRunner::observe_scripted(r,b,"final_strike","final_strike_replay",b.final_landed?ObservationEvent::Execute:ObservationEvent::Warning);
            if (definition.kind==4) {DracoBody::update(r,b);continue;}
            if (definition.kind==3) {HydraFinish::tick(r,b,dt);continue;}
            b.final_elapsed=std::max(0.0,s.time-b.final_started);const auto aim=TrackingPolicy{s.draw.tracing,e.held,s.enemy_handles.contains(e.pump_owner)}.target(e.pos,e.facing,s.ship_pos);const auto direction=aim-e.pos;
            e.vel={};e.facing+=std::clamp(angle_difference(direction.angle()-e.facing),-definition.turn*dt,definition.turn*dt);e.guard=1;e.charge=std::clamp(b.final_elapsed/b.final_charge,0.0,1.0);
            b.final_to=e.pos+direction.normalized()*p.final_reach;const double widen=std::clamp((b.final_elapsed-(b.final_charge-p.final_widen_time))/p.final_widen_time,0.0,1.0);b.final_width=p.final_warn_width+(p.final_beam_width-p.final_warn_width)*widen*widen;
            if (!b.final_landed && b.final_elapsed>=b.final_charge) {b.final_landed=true;TechniqueRunner::observe_scripted(r,b,"final_strike","final_strike_replay",ObservationEvent::Execute);s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.observation_id=b.final_observation_id;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;request.source=e.definition+1;CombatResolver::ship_damage(r,request);TechniqueRunner::finish_scripted(r,b);}
        } else if (definition.kind==1 && b.centaurus.leaping) {
            CentaurusFinish::leap_tick(r,b,dt);
        } else if (!busy(r,b.actor)) {
            if (b.phase_pending) {b.phase_pending=false;b.phase=2;b.mode=BossMode::Phase;b.phase_remaining=p.phase_time;event(r,"boss_phase",b);}
            else {b.initial_wait=std::max(0.0,b.initial_wait-dt);suspend=b.initial_wait>0;if (definition.kind==0) MonocerosBody::step(r,b,dt);else if (definition.kind==1) {CentaurusBody::step(r,b,dt);suspend=suspend || b.centaurus.leaping;}else if (definition.kind==2) {CanisMajorBody::step(r,b,dt);suspend=suspend || b.canis.calling;}else if (definition.kind==4) DracoBody::step(r,b,dt);}
        } else suspend=false;
        if (definition.kind==4 && b.mode!=BossMode::Idle) DracoBody::update(r,b);
        for (auto &f:s.bosses.flows) if (same_handle(f.actor,b.actor)) {f.phase=b.phase;f.suspended=suspend;}
    }
}
bool PhaseController::validate(const godot::RunState &s,const ContentBundle &c) {
    for (uint32_t row=0;row<s.bosses.bodies.size();++row) {const auto &b=s.bosses.bodies[row];if (b.id<=0 || b.id>=s.bosses.next_body_id || s.bosses.body_handles.entity_id(s.bosses.body_handles.at(row))!=b.id || !b.definition || b.definition>c.boss_bodies.size() || b.mode>BossMode::Cancelled || b.phase<1 || b.phase>(c.bosses[c.boss_bodies[b.definition-1].boss-1].kind==4?3u:2u) || !b.entrance_from.is_finite() || !b.entrance_target.is_finite() || !b.final_to.is_finite() || !b.slash_from.is_finite() || !b.slash_to.is_finite()) return false;
        if ((b.sweep_side!=1 && b.sweep_side!=-1) || b.participants.empty() || (c.bosses[c.boss_bodies[b.definition-1].boss-1].kind!=3 && c.bosses[c.boss_bodies[b.definition-1].boss-1].kind!=4 && b.participants.size()!=1) || b.participants[0].id<=0 || !same_handle(b.participants[0].actor,b.actor) || !same_handle(b.participants[0].health_target,b.actor) || !b.participants[0].is_body || b.participants[0].active!=(b.mode<BossMode::Defeated)) return false;
        if (!HydraBody::validate(s,c,b)) return false;
        if (!DracoBody::validate(s,c,b)) return false;
        if (!CanisMajorBody::validate(s,c,b)) return false;
        for (double value:{b.clock,b.initial_wait,b.entrance_elapsed,b.phase_remaining,b.final_elapsed,b.final_charge,b.final_width}) if (!std::isfinite(value) || value<0) return false;
        if (!CentaurusBody::validate(s,c,b)) return false;
        if (!std::isfinite(b.final_started) || (b.mode<BossMode::Defeated && (!s.enemy_handles.contains(b.actor) || s.enemies[b.actor.slot].dead))) return false;
    }return true;
}
godot::Array PhaseController::snapshot(const RunRuntime &r) {
    godot::Array out;for (const auto &b:r.state.bosses.bodies) {godot::Dictionary p;p["id"]=b.id;p["definition"]=b.definition;p["actor"]=r.state.enemy_handles.entity_id(b.actor);p["mode"]=int(b.mode);p["phase"]=b.phase;p["pending"]=b.phase_pending;p["clock"]=b.clock;p["initial_wait"]=b.initial_wait;p["phase_remaining"]=b.phase_remaining;p["final_elapsed"]=b.final_elapsed;p["final_landed"]=b.final_landed;p["final_to"]=b.final_to;p["final_width"]=b.final_width;p["final_warning"]=b.final_elapsed<b.final_charge-r.content->boss_bodies[b.definition-1].final_widen_time;p["final_clock"]=r.state.time;p["final_alpha"]=r.state.phase==godot::RunState::Phase::Play?1.0:r.state.phase==godot::RunState::Phase::Dying?std::max(0.0,1.0-r.state.sequence_t/std::max(0.01,r.state.death_freeze)):0.0;p["boss_spawned"]=r.state.world.boss_spawned;p["boss_dead"]=r.state.boss_dead;
        const auto &definition=r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1];p["kind"]=int(definition.kind);if (definition.kind==4) DracoBody::snapshot(r,b,p);if (definition.kind==3) HydraBody::snapshot(r,b,p);if (definition.kind==2) {CanisMajorBody::snapshot(r,b,p);p["flames"]=CanisFlames::snapshot(r,b);p["lunges"]=CanisHoundLunge::snapshot(r,b);}p["phase_progress"]=b.phase>=2?(b.mode==BossMode::Phase?1.0-b.phase_remaining/std::max(0.001,r.content->boss_bodies[b.definition-1].phase_time):1.0):0.0;
        godot::Array image_parts;for (const auto &part:b.image_parts) {godot::Dictionary v;v["part"]=part.part;v["region"]=part.region;v["pixel_to_world"]=part.pixel_to_world;v["visible"]=part.visible;image_parts.push_back(v);}p["image_parts"]=image_parts;
        godot::Array sword_slashes;for (const auto &slash:b.monoceros_slashes) {godot::Dictionary v;v["from"]=slash.from;v["to"]=slash.to;v["width"]=slash.width;v["started"]=slash.started;v["seed"]=slash.seed;sword_slashes.push_back(v);}p["sword_slashes"]=sword_slashes;
        godot::Array participants;for (const auto &part:b.participants) {godot::Dictionary v;v["id"]=part.id;v["health_target"]=same_handle(part.actor,part.health_target)?part.id:r.state.enemy_handles.entity_id(part.health_target);v["is_body"]=part.is_body;v["active"]=part.active;participants.push_back(v);}p["participants"]=participants;
        if (definition.kind==1) {const auto &v=b.centaurus;p["guard_point"]=v.guard_point;p["has_guard_point"]=v.has_guard_point;p["guard_scan"]=v.guard_scan;p["guard_refill"]=v.guard_refill;p["path_hold"]=v.path_hold;p["turn_motion"]=v.turn_motion;p["leaping"]=v.leaping;p["leap_elapsed"]=v.leap_elapsed;p["leap_progress"]=std::clamp(v.leap_elapsed/std::max(0.001,std::find_if(r.content->centaurus_bodies.begin(),r.content->centaurus_bodies.end(),[&](const auto &entry){return entry.body==b.definition;})->leap_time),0.0,1.0);p["leap_from"]=v.leap_from;p["leap_to"]=v.leap_to;p["leap_ready_at"]=v.leap_ready_at;p["retreat_ready_at"]=v.retreat_ready_at;p["cooldowns"]=int64_t(v.cooldowns.size());godot::Array guards;for (const auto &g:v.guards) {godot::Dictionary q;q["id"]=r.state.enemy_handles.entity_id(g.actor);q["scale"]=g.scale;q["phase"]=g.phase;guards.push_back(q);}p["guards"]=guards;}
        if (r.state.enemy_handles.contains(b.actor)) {const auto &e=r.state.enemies[b.actor.slot];p["velocity"]=e.vel;p["flash"]=e.flash;p["horn_length"]=e.radius*(definition.horn_length_ratio+(definition.horn_length_ratio_p2-definition.horn_length_ratio)*double(p["phase_progress"]));p["position"]=e.pos;p["facing"]=e.facing;p["radius"]=e.radius;p["hp"]=e.hp;p["max_hp"]=e.max_hp;p["charge"]=e.charge;p["horn_waves"]=MonocerosHornWave::waves(r,b.actor);godot::PackedVector2Array slash;if (b.has_slash) {slash.push_back(b.slash_from);slash.push_back(b.slash_to);}p["last_slash"]=slash;}out.push_back(p);
    }return out;
}
}
