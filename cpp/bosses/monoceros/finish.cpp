#include "finish.h"
#include "../flow/phase_controller.h"
#include "../../runtime/lifecycle.h"
#include "../../systems/attack_system.h"
#include "../../systems/enemy_system.h"
#include "../../systems/combat_resolver.h"
#include "../../output/frame_builder.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
double reveal_duration(const RunRuntime &r) {if (r.state.lifecycle.endless || r.content->lifecycle.legendary.empty()) return 0;const auto &p=r.content->boss_finish.front();return p.relic_appear_time+p.relic_hold_time+p.relic_collect_time;}
void reset(RunRuntime &r) {auto &s=r.state;s.hitstop=0;s.control.world_scale=1;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};s.control.world_real_accum=s.control.world_dt_accum=0;s.control.world_steps=0;}
void cue(RunRuntime &r,const char *type,bool position=false) {godot::Dictionary event;if (position) event["pos"]=r.state.bosses->finish.origin;FrameBuilder::append(r,type,event);}
void blast(RunRuntime &r) {auto &s=r.state;auto &f=s.bosses->finish;if (f.blasted) return;f.blasted=true;cue(r,"boss_explode",true);for (uint32_t row=0;row<s.enemies.size();++row) {const auto e=s.enemies[row];if (!e.alive || e.dead || e.is_boss) continue;EnemySystem::mark_dead(r,s.enemy_handles.at(row));godot::Dictionary event;event["pos"]=e.pos;event["id"]=e.id;event["r"]=e.radius;event["enemy_type"]=godot::String(r.content->definitions[e.definition].id);event["cause"]=symbol_name(Cause::Finale);event["dir"]=(e.pos-f.origin).normalized();event["silent"]=true;event["color"]=r.content->definitions[e.definition].color;event["facing"]=e.facing;event["meteor_index"]=s.field.rock_handles.contains(e.rock)?int64_t(e.rock.slot):-1;FrameBuilder::append(r,"kill",event);EnemySystem::retire(r,s.enemy_handles.at(row),RetireReason::DeathCleanup);}AttackSystem::clear_hostile(s,AttackEndReason::BossClear);for (auto &b:s.bosses->bodies) {PhaseController::cancel(r,b.actor);if (s.enemy_handles.contains(b.actor)) EnemySystem::retire(r,b.actor,RetireReason::DeathCleanup);}}
}
void BossFinish::record_approach(RunRuntime &r) {if (r.content->boss_finish.empty() || !r.state.world.boss_spawned || r.state.phase!=godot::RunState::Phase::Play) return;auto &history=r.state.bosses->finish.approach;history.push_back(r.state.ship_pos);const auto keep=size_t(r.content->boss_finish.front().replay_window*120.0)+1;if (history.size()>keep) history.erase(history.begin(),history.begin()+(history.size()-keep));}
bool BossFinish::check(RunRuntime &r) {
    auto &s=r.state;using Phase=godot::RunState::Phase;if (r.content->boss_finish.empty() || s.phase!=Phase::Play || s.ship.hp<=0) return false;auto &f=s.bosses->finish;const auto &p=r.content->boss_finish.front();
    if (s.boss_dead) {f.active=true;f.elapsed=0;f.blasted=f.banner=false;f.origin=s.ship_pos;for (const auto &b:s.bosses->bodies) if (s.enemy_handles.contains(b.actor)) {f.origin=s.enemies[b.actor.slot].pos;break;}f.replay=f.approach;f.replay.push_back(s.ship_pos);reset(r);AttackSystem::clear_hostile(s,AttackEndReason::BossClear);cue(r,"boss_finish",true);s.phase=Phase::Finishing;if (s.control.draco_finish_done) {f.replay.clear();f.elapsed=p.slow_time+p.blast_time+reveal_duration(r);blast(r);}return true;}
    if (s.control.time_limit_reached && !f.final_started) {f.final_started=true;bool started=false;for (auto &b:s.bosses->bodies) if (r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].kind!=4 && b.mode<BossMode::Final && s.enemy_handles.contains(b.actor) && !s.enemies[b.actor.slot].dead) {started=PhaseController::begin_final(r,b.actor,p.time_up_charge_time);break;}if (!started) {godot::Dictionary event;event["t"]=s.time;FrameBuilder::append(r,"final_strike",event);s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;CombatResolver::ship_damage(r,request);}}
    else if (s.control.time_limit_reached && f.final_started && s.time>=s.control.time_limit+p.time_up_charge_time) {s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;CombatResolver::ship_damage(r,request);}
    return false;
}
void BossFinish::step(RunRuntime &r,double dt) {
    auto &s=r.state;if (r.content->boss_finish.empty() || s.phase!=godot::RunState::Phase::Finishing) return;auto &f=s.bosses->finish;const auto &p=r.content->boss_finish.front();f.elapsed+=dt;
    if (!f.replay.empty()) {const double at=std::clamp(f.elapsed/std::max(p.slow_time,0.001),0.0,1.0)*(f.replay.size()-1);const size_t i=size_t(at);s.ship_pos=f.replay[i].lerp(f.replay[std::min(i+1,f.replay.size()-1)],at-i);}
    auto &c=s.control;const double factor=std::pow(c.zoom_ref_speed/std::max(c.zoom_ref_speed,s.ship_config.max_speed),c.zoom_exp),base=std::min(c.logical_size.x,c.logical_size.y)/c.base_view*std::clamp(factor,c.zoom_min,1.0);const double follow=1.0-std::exp(-10.0*dt);c.camera_center+=(s.ship_pos-c.camera_center)*follow;c.camera_zoom+=(base*(f.elapsed<p.slow_time?p.zoom:1.0)-c.camera_zoom)*follow;s.view_center=c.camera_center;s.view_half=c.logical_size/2.0/c.camera_zoom;
    if (f.elapsed>=p.slow_time) blast(r);const double clear=p.slow_time+p.blast_time+reveal_duration(r);if (f.elapsed>=clear && !f.banner) {f.banner=true;cue(r,"clear_banner");}if (f.elapsed>=clear+p.clear_time) {f.active=false;Lifecycle::finish(r,ResultKind::Clear);}
}
bool BossFinish::skip(RunRuntime &r) {if (r.content->boss_finish.empty() || r.state.phase!=godot::RunState::Phase::Finishing) return false;const auto &p=r.content->boss_finish.front();r.state.bosses->finish.elapsed=std::max(r.state.bosses->finish.elapsed,p.slow_time+p.blast_time+reveal_duration(r));reset(r);step(r,0);return true;}
bool BossFinish::abort(RunRuntime &r) {if (r.state.lifecycle.result) return false;for (auto &b:r.state.bosses->bodies) PhaseController::cancel(r,b.actor);r.state.bosses->finish.active=false;return Lifecycle::finish(r,ResultKind::Abort);}
bool BossFinish::validate(const godot::RunState &s) {const auto &f=s.bosses->finish;if (!std::isfinite(f.elapsed) || f.elapsed<0 || !f.origin.is_finite()) return false;for (const auto &v:f.approach) if (!v.is_finite()) return false;for (const auto &v:f.replay) if (!v.is_finite()) return false;return f.active==(s.phase==godot::RunState::Phase::Finishing);}
godot::Dictionary BossFinish::snapshot(const RunRuntime &r) {godot::Dictionary out;if (r.content->boss_finish.empty()) return out;const auto &f=r.state.bosses->finish;const auto &p=r.content->boss_finish.front();out["active"]=f.active;out["elapsed"]=f.elapsed;out["origin"]=f.origin;out["slow_time"]=p.slow_time;out["reveal_start"]=p.slow_time+p.blast_time;out["reveal_duration"]=reveal_duration(r);out["appear_time"]=p.relic_appear_time;out["hold_time"]=p.relic_hold_time;out["collect_time"]=p.relic_collect_time;out["blasted"]=f.blasted;out["legendary"]=godot::String(r.content->lifecycle.legendary.c_str());return out;}
}
