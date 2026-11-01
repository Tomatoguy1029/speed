#include "run_runner.h"
#include "../systems/attack_system.h"
#include "../api/run_core.h"
#include <algorithm>
#include <cmath>
namespace speed {
void RunRunner::camera(godot::SpeedRunCore &core,double dt,godot::Vector2 size) {
    auto &state=core.runtime.state;auto &control=state.control;
    const double factor=std::pow(control.zoom_ref_speed/std::max(control.zoom_ref_speed,state.ship_config.max_speed),control.zoom_exp);
    const double zoom=std::min(size.x,size.y)/control.base_view*std::clamp(factor,control.zoom_min,1.0);
    if (!control.camera_ready) {control.camera_center=state.ship.pos;control.camera_zoom=zoom;control.camera_ready=true;}
    if (!state.draw.drawing && !state.draw.tracing) {
        auto offset=state.ship.vel*control.look_ahead;
        const double maximum=0.3*std::min(size.x,size.y)/2.0/zoom;
        if (offset.length()>maximum) offset=offset.normalized()*maximum;
        control.camera_center+=(state.ship.pos+offset-control.camera_center)*(1.0-std::exp(-7.0*dt));
        control.camera_zoom+=(zoom-control.camera_zoom)*(1.0-std::exp(-2.2*dt));
    }
    control.logical_size=size;
    state.view_center=control.camera_center;state.view_half=size/2.0/control.camera_zoom;
}
bool RunRunner::step_play(godot::SpeedRunCore &core,double dt,const InputFrame &raw_input,godot::Vector2 size) {
    auto &state=core.runtime.state;auto &control=state.control;
    using Phase=godot::RunState::Phase;
    // UIの入口判定を通過するまで、入力も時計も消費しない。
    if (control.ui_overlay || (control.ui_reward && state.phase!=Phase::Finishing)) return true;
    if (state.phase==Phase::Dying) {core.step_death(dt);return true;}
    if (state.phase!=Phase::Play) return true;
    if (state.controls_locked || state.encounter_protected) state.hitstop=0;
    control.last_input=raw_input;
    InputFrame input=state.steering_locked || state.controls_locked?InputFrame():raw_input;
    if (state.controls_locked) state.ship.vel=godot::Vector2();
    camera(core,0,size);
    state.sim_time+=dt;
    if (!core.handle_draw_input(input,int64_t(std::round(state.sim_time*1000)),control.camera_zoom)) return false;
    if (state.hitstop>0) {state.hitstop=std::max(0.0,state.hitstop-dt);return true;}
    if (!state.draw.tracing && state.dash_stop>0) state.dash_stop=std::max(0.0,state.dash_stop-dt*state.combat_config.kill_hitstop_regen);
    if (!core.step_draw(dt)) return false;
    if (core.check_run_end()) return true;
    control.world_scale=core.world_scale();
    const double world_dt=dt*control.world_scale;
    if (control.bonus_remaining>0) {
        control.bonus_remaining-=dt;
        if (control.bonus_remaining<=0) leave_bonus(core);
    } else state.time+=dt;
    if (!control.time_limit_reached && control.time_limit>=0 && state.time>=control.time_limit) {
        control.time_limit_reached=true;godot::Dictionary event;event["t"]=state.time;core.emit_event("time_limit_reached",event);
    }
    state.world_time+=world_dt;
    control.world_real_accum+=dt;control.world_dt_accum+=world_dt;++control.world_steps;
    const bool world_step=control.world_steps>=std::max<int64_t>(1,control.world_tick_div);
    const double wr=control.world_real_accum,wd=control.world_dt_accum;
    if (world_step) {
        control.world_real_accum=control.world_dt_accum=0;control.world_steps=0;
        control.last_world_real_dt=wr;control.last_world_dt=wd;++control.world_updates;
        if (state.attack_budget.frame_enabled) {core.sync_attack_budget();if (!core.advance_attack_budget(state.world_time)) return false;}
        // 地形・ボスは各種類の移植で、この世界更新区間へ接続する。
        core.advance_enemies(wd);
        if (!core.avoid_strong(wd)) return false;
        if (core.check_run_end()) return true;
        if (!core.rebuild_enemy_grid(state.frame_grid_cell)) return false;
    }
    if (!core.step_ship_input(dt,world_dt,input)) return false;
    if (state.phase==Phase::Play && !state.controls_locked && state.forward.ready) core.step_forward(world_dt);
    if (world_step && state.phase==Phase::Play) {
        if (state.projectile_config.ready && !core.step_projectiles(wd)) return false;
        if (core.check_run_end()) return true;
        if (!state.hostiles.empty() && !core.step_hostiles(wd)) return false;
        if (core.check_run_end()) return true;
        if (state.bite_zone_config.ready && !core.step_hazards(wd)) return false;
    }
    if (core.check_run_end()) return true;
    for (size_t row:state.dead_rows) if (state.enemies[row].alive && state.enemies[row].dead) core.remove_enemy(state.enemies[row].id);
    state.dead_rows.clear();
    if (world_step) {
        if (state.population.frame_enabled && !state.population.blocked && !core.attack_guard_active() && !core.step_population(wd,control.bonus_remaining>0)) return false;
        if (state.pickups_ready && !core.step_pickups(wd)) return false;
    }
    state.ship_pos=state.ship.pos;
    camera(core,dt,size);
    if (!core.check_run_end() && state.progression.ready) core.open_cards(false);
    return true;
}
void RunRunner::leave_bonus(godot::SpeedRunCore &core) {
    auto &state=core.runtime.state;
    state.control.bonus_remaining=0;
    // 現在移行済みの敵は通常敵。ボス・地形の除外は各登録型で接続する。
    for (size_t row=0;row<state.enemies.size();++row) if (state.enemies[row].alive && !state.enemies[row].dead) {
        state.enemies[row].dead=true;state.dead_rows.push_back(row);
    }
    AttackSystem::clear_bonus(state);AttackSystem::clear_hostile(state,AttackEndReason::BonusClear);
    godot::Dictionary event;event["enter"]=false;event["pos"]=state.ship.pos;core.emit_event("bonus",event);
}
}
