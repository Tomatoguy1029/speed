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
// 撃破演出の場面の開始時刻。命中の静止→スロー→ひび→ため→崩壊→余韻と集束→（初回だけ）獲得→CLEAR!。
struct Times {double slow=0,crack=0,hold=0,burst=0,settle=0,cool=0,show=0,take=0,clear=0,end=0;};
// 衝撃の輪が届く速さ（世界単位／秒、キャラクター倍率1のとき）。
constexpr double RING_SPEED=1150;
// 獲得の場面で寄る倍率（通常の見え方に対する倍率）と、名前のために下げる量。
constexpr double RELIC_ZOOM=2.58,RELIC_LOWER=17.5,RELIC_RAISE=6;
bool reveals(const RunRuntime &r) {return !r.state.lifecycle.endless && !r.state.lifecycle.legendary_owned && !r.content->lifecycle.legendary.empty();}
Times times(const RunRuntime &r) {
    const auto &p=r.content->boss_finish.front();Times t;t.slow=p.stop_time;t.crack=t.slow+p.slow_time;t.hold=t.crack+p.crack_time;t.burst=t.hold+p.hold_time;t.settle=t.burst+p.burst_time;t.cool=t.settle+p.settle_time;
    if (r.state.bosses->finish.reveal) {t.show=t.cool+p.relic_appear_time;t.take=t.show+p.relic_hold_time;t.clear=t.take+p.relic_collect_time;} else t.show=t.take=t.clear=t.cool;
    t.end=t.clear+p.clear_time;return t;
}
double clamp01(double v) {return std::clamp(v,0.0,1.0);}
double smooth(double v) {v=clamp01(v);return v*v*(3-2*v);}
double ease_out(double v) {v=clamp01(v);return 1-std::pow(1-v,3);}
double progress(double t,double from,double to) {return clamp01((t-from)/std::max(1e-6,to-from));}
godot::Vector2 relic(const RunRuntime &r) {return r.state.bosses->finish.origin+godot::Vector2(0,-RELIC_RAISE*r.content->config.character_scale);}
void reset(RunRuntime &r) {auto &s=r.state;s.hitstop=0;s.control.world_scale=1;s.draw.drawing=s.draw.tracing=false;s.ship.vel={};s.control.world_real_accum=s.control.world_dt_accum=0;s.control.world_steps=0;}
void cue(RunRuntime &r,const char *type,bool position=false) {godot::Dictionary event;if (position) event["pos"]=r.state.bosses->finish.origin;FrameBuilder::append(r,type,event);}
void kill_enemy(RunRuntime &r,uint32_t row) {
    auto &s=r.state;const auto e=s.enemies[row];EnemySystem::mark_dead(r,s.enemy_handles.at(row));godot::Dictionary event;event["pos"]=e.pos;event["id"]=e.id;event["r"]=e.radius;event["enemy_type"]=godot::String(r.content->definitions[e.definition].id);event["cause"]=symbol_name(Cause::Finale);event["dir"]=(e.pos-s.bosses->finish.origin).normalized();event["silent"]=true;event["color"]=r.content->definitions[e.definition].color;event["facing"]=e.facing;event["meteor_index"]=s.field.rock_handles.contains(e.rock)?int64_t(e.rock.slot):-1;FrameBuilder::append(r,"kill",event);EnemySystem::retire(r,s.enemy_handles.at(row),RetireReason::DeathCleanup);
}
// 崩壊の瞬間にボスを消し、周りの敵は衝撃の輪が届いた順に光へ変える。all は残りを一度に消す。
void sweep(RunRuntime &r,double since_burst,bool all) {
    auto &s=r.state;auto &f=s.bosses->finish;
    if (!f.blasted) {f.blasted=true;cue(r,"boss_explode",true);AttackSystem::clear_hostile(s,AttackEndReason::BossClear);for (auto &b:s.bosses->bodies) {PhaseController::cancel(r,b.actor);if (s.enemy_handles.contains(b.actor)) EnemySystem::retire(r,b.actor,RetireReason::DeathCleanup);}}
    const double reach=RING_SPEED*r.content->config.character_scale;
    for (uint32_t row=0;row<s.enemies.size();++row) {const auto &e=s.enemies[row];if (!e.alive || e.dead || e.is_boss) continue;if (all || since_burst>=0.04+e.pos.distance_to(f.origin)*1.05/reach) kill_enemy(r,row);}
}
void camera(RunRuntime &r) {
    auto &s=r.state;auto &f=s.bosses->finish;auto &c=s.control;const auto &p=r.content->boss_finish.front();const Times t=times(r);const double at=f.elapsed,zb=f.base_zoom,zc=zb*p.zoom;
    double z=zb;godot::Vector2 center=f.origin;
    if (at>=t.slow && at<t.crack) z=zb+(zc-zb)*ease_out(progress(at,t.slow,t.crack));
    else if (at>=t.crack && at<t.burst) z=zc*(1+0.07*(at-t.crack)/std::max(1e-6,t.burst-t.crack));
    else if (at>=t.burst) {const double tb=at-t.burst;z=zc*1.07+(zb*0.9-zc*1.07)*ease_out(tb/0.6);z+=(zb-z)*smooth((tb-0.5)/1.8);}
    if (f.reveal && at>=t.cool) {
        const double scale=r.content->config.character_scale,take=progress(at,t.take,t.clear),e=smooth((take-0.2)/0.8),k=ease_out(progress(at,t.cool,t.show))*(1-e),zs=zb*RELIC_ZOOM;
        const godot::Vector2 point=relic(r),middle=(point+f.ship)*0.5;
        z=z+(zb-z)*e;z=z+(zs*(1+0.05*progress(at,t.show,t.take))-z)*k;
        const godot::Vector2 away=f.origin+(middle-f.origin)*e;center=away+(point+godot::Vector2(0,RELIC_LOWER*scale)-away)*k;
    }
    c.camera_center=center;c.camera_zoom=z;s.view_center=center;s.view_half=c.logical_size/2.0/z;
}
}
bool BossFinish::check(RunRuntime &r) {
    auto &s=r.state;using Phase=godot::RunState::Phase;if (r.content->boss_finish.empty() || s.phase!=Phase::Play || s.ship.hp<=0) return false;auto &f=s.bosses->finish;const auto &p=r.content->boss_finish.front();
    if (s.boss_dead) {
        f.active=true;f.elapsed=0;f.blasted=f.banner=false;f.reveal=reveals(r);f.ship=s.ship_pos;f.origin=s.ship_pos;for (const auto &b:s.bosses->bodies) if (s.enemy_handles.contains(b.actor)) {f.origin=s.enemies[b.actor.slot].pos;break;}
        auto &c=s.control;const double factor=std::pow(c.zoom_ref_speed/std::max(c.zoom_ref_speed,s.ship_config.max_speed),c.zoom_exp);f.base_zoom=std::min(c.logical_size.x,c.logical_size.y)/c.base_view*std::clamp(factor,c.zoom_min,1.0);
        reset(r);cue(r,"boss_finish",true);s.phase=Phase::Finishing;camera(r);
        if (s.control.draco_finish_done) {f.elapsed=times(r).clear;sweep(r,0,true);}
        return true;
    }
    if (s.control.time_limit_reached && !f.final_started) {f.final_started=true;bool started=false;for (auto &b:s.bosses->bodies) if (r.content->bosses[r.content->boss_bodies[b.definition-1].boss-1].kind!=4 && b.mode<BossMode::Final && s.enemy_handles.contains(b.actor) && !s.enemies[b.actor.slot].dead) {started=PhaseController::begin_final(r,b.actor,p.time_up_charge_time);break;}if (!started) {godot::Dictionary event;event["t"]=s.time;FrameBuilder::append(r,"final_strike",event);s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;CombatResolver::ship_damage(r,request);}}
    else if (s.control.time_limit_reached && f.final_started && s.time>=s.control.time_limit+p.time_up_charge_time) {s.invincible=false;s.ship.invuln=s.ship.shield_t=0;ShipDamageRequest request;request.amount=s.ship.hp+1;request.cause=Cause::FinalStrike;CombatResolver::ship_damage(r,request);}
    return false;
}
void BossFinish::step(RunRuntime &r,double dt) {
    auto &s=r.state;if (r.content->boss_finish.empty() || s.phase!=godot::RunState::Phase::Finishing) return;auto &f=s.bosses->finish;const auto &p=r.content->boss_finish.front();f.elapsed+=dt;const Times t=times(r);
    // 敵の弾は命中の瞬間に止まり、スローの途中で消える。
    if (f.elapsed>=t.slow+p.slow_time*0.3125) AttackSystem::clear_hostile(s,AttackEndReason::BossClear);
    if (f.elapsed>=t.burst) sweep(r,f.elapsed-t.burst,f.elapsed>=t.clear);
    camera(r);
    if (f.elapsed>=t.clear && !f.banner) {f.banner=true;cue(r,"clear_banner");}
    if (f.elapsed>=t.end) {f.active=false;Lifecycle::finish(r,ResultKind::Clear);}
}
bool BossFinish::skip(RunRuntime &r) {if (r.content->boss_finish.empty() || r.state.phase!=godot::RunState::Phase::Finishing) return false;auto &f=r.state.bosses->finish;f.elapsed=std::max(f.elapsed,times(r).clear);reset(r);sweep(r,0,true);step(r,0);return true;}
bool BossFinish::abort(RunRuntime &r) {if (r.state.lifecycle.result) return false;for (auto &b:r.state.bosses->bodies) PhaseController::cancel(r,b.actor);r.state.bosses->finish.active=false;return Lifecycle::finish(r,ResultKind::Abort);}
bool BossFinish::validate(const godot::RunState &s) {const auto &f=s.bosses->finish;if (!std::isfinite(f.elapsed) || f.elapsed<0 || !std::isfinite(f.base_zoom) || !f.origin.is_finite() || !f.impact.is_finite() || !f.direction.is_finite() || !f.ship.is_finite()) return false;return f.active==(s.phase==godot::RunState::Phase::Finishing);}
godot::Dictionary BossFinish::snapshot(const RunRuntime &r) {
    godot::Dictionary out;if (r.content->boss_finish.empty()) return out;const auto &f=r.state.bosses->finish;const Times t=times(r);
    out["active"]=f.active;out["elapsed"]=f.elapsed;out["origin"]=f.origin;out["impact"]=f.impact;out["direction"]=f.direction;out["boost"]=f.boost;out["reveal"]=f.reveal;out["ship"]=f.ship;out["relic"]=relic(r);out["blasted"]=f.blasted;out["base_zoom"]=f.base_zoom;
    godot::Dictionary at;at["slow"]=t.slow;at["crack"]=t.crack;at["hold"]=t.hold;at["burst"]=t.burst;at["settle"]=t.settle;at["cool"]=t.cool;at["show"]=t.show;at["take"]=t.take;at["clear"]=t.clear;at["end"]=t.end;out["times"]=at;
    out["slow_end"]=t.crack;out["reveal_start"]=t.cool;out["reveal_duration"]=t.clear-t.cool;out["legendary"]=godot::String(r.content->lifecycle.legendary.c_str());
    return out;
}
}
