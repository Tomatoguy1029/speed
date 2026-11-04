#include "../systems/heroes.h"
#include "../behaviors/weapons/bipolar.h"
#include "../behaviors/weapons/interceptor.h"
#include "../behaviors/weapons/dashRangeDrone.h"
#include "../behaviors/weapons/massTow.h"
#include "run_runner.h"
#include "dev_commands.h"
#include "../output/frame_builder.h"
#include "../bosses/draco/finale.h"
#include "../bosses/canis_major/nova.h"
#include "../systems/boss_image.h"
#include "../behaviors/weapons/flashSlash.h"
#include "../behaviors/weapons/afterimage.h"
#include "../behaviors/enemies/corona_vortex.h"
#include "../bosses/monoceros/finish.h"
#include "../systems/attack_system.h"
#include "../behaviors/weapons/scatter.h"
#include "../behaviors/weapons/rear.h"
#include "../behaviors/weapons/barrier.h"
#include "../behaviors/weapons/contactWave.h"
#include "../behaviors/weapons/sonic.h"
#include "../behaviors/weapons/endBlast.h"
#include "../behaviors/weapons/mines.h"
#include "../behaviors/weapons/knockback.h"
#include "../behaviors/traits/rampage.h"
#include "../behaviors/traits/killSonic.h"
#include "../behaviors/traits/fullBurst.h"
#include "../systems/attacks/light_lances.h"
#include "../behaviors/traits/runUp.h"
#include "../behaviors/traits/vortex.h"
#include "../systems/progression.h"
#include "../systems/field.h"
#include "../systems/boss_ram.h"
#include "../systems/boss_contact.h"
#include "../systems/enemy_system.h"
#include "../systems/encounters.h"
#include "../systems/pickup_system.h"
#include "../api/run_core.h"
#include <algorithm>
#include <cmath>
namespace speed {
void RunRunner::camera(godot::SpeedRunCore &core,double dt,godot::Vector2 size) {
    auto &state=core.runtime.state;auto &control=state.control;
    if (control.cinematic_camera) {control.logical_size=size;state.view_center=control.camera_center;state.view_half=size/(2.0*control.camera_zoom);return;}
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
    if (!state.motion_ready) state.enemy_aim=state.ship_pos;state.motion_ready=true;
}
bool RunRunner::step_play(godot::SpeedRunCore &core,double dt,const InputFrame &raw_input,godot::Vector2 size) {
    auto &state=core.runtime.state;auto &control=state.control;
    auto timed=[&](const char *name,auto &&action) {MetricsDetailTimer measured(core.runtime.frame_workspace.metrics,name);return action();};
    using Phase=godot::RunState::Phase;
    BossRamSystem::cancel_invalid(core.runtime);
    // UIの入口判定を通過するまで、入力も時計も消費しない。
    if (control.ui_overlay || (control.ui_reward && state.phase!=Phase::Finishing)) return true;
    if (state.phase==Phase::LevelUp) {ProgressionSystem::poll(core);return true;}
    if (state.phase==Phase::Finishing) {BossFinish::step(core.runtime,dt);return true;}
    if (state.phase==Phase::Dying) {core.step_death(dt);return true;}
    if (state.phase!=Phase::Play) return true;
    if (core.runtime.api_development && core.runtime.benchmark_boss_hp>0)
        for (auto &enemy:state.enemies) if (enemy.alive && !enemy.dead && enemy.is_boss)
            enemy.hp=enemy.max_hp*core.runtime.benchmark_boss_hp;
    if (DracoFinale::tick(core.runtime,dt,raw_input,size)) {core.check_run_end();return true;}
    if (state.controls_locked || state.encounter_protected) state.hitstop=0;
    // 制作側に乱数や出現判断を置かず、同じ固定tickで予定配置を実行する。
    if (control.lab_mode && !core.attack_guard_active()) for (const auto &entry:control.lab_schedule) {
        if (!entry.enabled || control.tick<entry.start || control.tick>entry.end || (control.tick-entry.start)%entry.interval) continue;
        if (control.rng.randf()>entry.probability) continue;
        const auto at=entry.position+godot::Vector2::from_angle(control.rng.randf()*6.283185307179586)*std::sqrt(control.rng.randf())*entry.radius;
        for (int64_t n=0;n<std::min<int64_t>(entry.count,entry.boss?32:10000);++n) {
            EnemySpawn options;options.origin=SpawnOrigin::DevPlacement;options.facing=entry.facing;options.has_facing=true;options.elite=entry.elite;
            options.position=at+(entry.boss?godot::Vector2(n*400,0):godot::Vector2::from_angle(n*2.399963)*std::sqrt(double(n))*entry.spacing);
            DevCommands::place_lab_actor(core.runtime,entry.definition,options);
        }
        if (!entry.boss) {godot::Dictionary event;event["pos"]=at;event["enemy_type"]=core.runtime.content->definitions[entry.definition].id;FrameBuilder::append(core.runtime,"lab_spawn",event);}
    }
    control.last_input=raw_input;
    InputFrame input=state.steering_locked || state.controls_locked?InputFrame():raw_input;
    if (state.controls_locked) state.ship.vel=godot::Vector2();
    camera(core,0,size);
    state.sim_time+=dt;
    BossImageSystem::refresh(core.runtime);
    if (!timed("draw_input",[&]{return core.handle_draw_input(input,int64_t(std::round(state.sim_time*1000)),control.camera_zoom);})) return false;
    if (state.control.boss_ram.pending && state.draw.tracing) core.end_trace(false);
    if (state.hitstop>0) {state.hitstop=std::max(0.0,state.hitstop-dt);BossRamSystem::advance(core.runtime,dt);return true;}
    if (state.control.boss_ram.pending) BossRamSystem::advance(core.runtime,dt);
    if (!state.draw.tracing && state.dash_stop>0) state.dash_stop=std::max(0.0,state.dash_stop-dt*state.combat_config.kill_hitstop_regen);
    if (!timed("draw",[&]{return core.step_draw(dt);})) return false;
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
        if (state.world.attack_budget.frame_enabled || core.runtime.content->encounter.active) {core.sync_attack_budget();if (!timed("attack_budget",[&]{return core.advance_attack_budget(state.world_time);})) return false;}
        if (control.lab_enemy_ai || !control.lab_mode) {
            timed("field.update",[&]{FieldSystem::update(core.runtime);});
            timed("field.comets",[&]{FieldSystem::step_comets(core.runtime,wd);});
            timed("field.rocks",[&]{FieldSystem::stream_rocks(core.runtime,wd);});
            timed("field.gravity",[&]{FieldSystem::step_gravity(core.runtime,wd);});
            if (!timed("enemies",[&]{return core.advance_enemies(wd);})) return false;
            if (!timed("avoidance",[&]{return core.avoid_strong(wd);})) return false;
            BossImageSystem::refresh(core.runtime);
        }
        if (core.check_run_end()) return true;
        if (!timed("enemy_grid",[&]{return core.rebuild_enemy_grid(state.frame_grid_cell);})) return false;
    }
    if (state.boss_contact_interrupt_trace) {state.boss_contact_interrupt_trace=false;if (state.draw.tracing) core.end_trace(false);}
    if (!timed("ship",[&]{return core.step_ship_input(dt,world_dt,input);})) return false;
    BossContactSystem::clear_landings(core.runtime);
    BossFinish::record_approach(core.runtime);
    if (control.lab_enemy_ai || !control.lab_mode) {
        if (input.hero_press) HeroesSystem::activate(core.runtime);
        timed("heroes",[&]{HeroesSystem::step(core.runtime,dt,world_dt);});
    }
    if (state.phase==Phase::Play && !state.controls_locked) {
        MetricsDetailTimer equipment_time(core.runtime.frame_workspace.metrics,"equipment");
        timed("light_lances",[&]{LightLancesSystem::step(core.runtime,world_dt);});
        for (const auto &owned:state.loadout.weapons) {
            if (core.runtime.content->equipment[owned.definition-1].external_id=="W27") {MetricsDetailTimer measured(core.runtime.frame_workspace.metrics,"equipment.W27");AfterimageBehavior::step(core.runtime,dt);}
            if (state.phase!=Phase::Play) break;
        }
        if (state.phase!=Phase::Play) return true;
        // 取得順で更新し、各武器の後に進行状態を確認する。
        if (state.loadout.ready) {
            for (const auto &owned:state.loadout.weapons) {
                const auto &id=core.runtime.content->equipment[owned.definition-1].external_id;
                if (id=="W27") continue;
                MetricsDetailTimer measured(core.runtime.frame_workspace.metrics,"equipment.",id);
                if (id=="W01") core.step_forward(world_dt);
                else if (id=="W28") FlashSlashBehavior::step(core.runtime,world_dt);
                else if (id=="W26") DashRangeDroneBehavior::step(core.runtime,world_dt);
                else if (id=="W25") InterceptorBehavior::step(core.runtime,world_dt);
                else if (id=="W22") BipolarBehavior::step(core.runtime,world_dt);
                else if (id=="W21") MassTowBehavior::step(core.runtime,world_dt);
                else if (id=="W08") SonicBehavior::step(core.runtime,world_dt);
                else if (id=="W04") ContactWaveBehavior::step(core.runtime,world_dt);
                else if (id=="W05") BarrierBehavior::step(core.runtime,world_dt);
                else if (id=="W23") RearBehavior::step(core.runtime,world_dt);
                else if (id=="W03") KnockbackBehavior::step(core.runtime,world_dt);
                else if (id=="W07") MinesBehavior::step(core.runtime,world_dt);
                else if (id=="W29") EndBlastBehavior::step(core.runtime,world_dt);
                else if (id=="W02") ScatterBehavior::step(core.runtime,world_dt);
                if (state.phase!=Phase::Play) break;
            }
        } else if (state.forward.ready) core.step_forward(world_dt);
        if (state.phase==Phase::Play) for (const auto &owned:state.loadout.traits) {
            const auto &id=core.runtime.content->equipment[owned.definition-1].external_id;
            MetricsDetailTimer measured(core.runtime.frame_workspace.metrics,"equipment.",id);
            if (id=="T05") KillSonicBehavior::step(core.runtime,world_dt);
            else if (id=="T03") VortexBehavior::step(core.runtime,world_dt);
            else if (id=="T32") RunUpBehavior::step(core.runtime,world_dt);
            else if (id=="T33") RampageBehavior::step(core.runtime,world_dt);
            else if (id=="T36") FullBurstBehavior::step(core.runtime);
        }
    }
    if (world_step && state.phase==Phase::Play) {
        if (state.projectile_config.ready && !timed("projectiles.friendly",[&]{return core.step_projectiles(wd);})) return false;
        if (core.check_run_end()) return true;
        if (!CoronaVortex::hit_thrown(core.runtime)) return true;
        if (!state.hostiles.empty() && !timed("projectiles.hostile",[&]{return core.step_hostiles(wd);})) return false;
        if (core.check_run_end()) return true;
        if (!state.hazards.empty() && !timed("projectiles.hazards",[&]{return core.step_hazards(wd);})) return false;
    }
    if (core.check_run_end()) return true;
    auto dead_rows=std::move(state.dead_rows);state.dead_rows.clear();
    for (size_t row:dead_rows) if (state.enemies[row].alive && state.enemies[row].dead) core.remove_enemy(state.enemies[row].id);
    if (state.pickups_ready) timed("pickup_prune",[&]{PickupSystem::prune(core.runtime);});
    if (world_step && (control.lab_enemy_ai || !control.lab_mode)) {
        if (!timed("encounters",[&]{return EncounterSystem::advance(core.runtime);})) return false;
        if (state.population.frame_enabled && !state.population.blocked && !core.attack_guard_active() && !timed("population",[&]{return core.step_population(wd,control.bonus_remaining>0);})) return false;
        if (state.pickups_ready && !timed("pickups",[&]{return core.step_pickups(wd);})) return false;
    }
    state.ship_pos=state.ship.pos;
    if ((control.lab_enemy_ai || !control.lab_mode) && state.phase==Phase::Play && control.bonus_remaining<=0 && FieldSystem::take_warp(core.runtime)) enter_bonus(core);
    camera(core,dt,size);
    BossImageSystem::refresh(core.runtime);
    if (world_step && state.phase==Phase::Play)
        for (auto &body:state.bosses.bodies) CanisNova::field_tick(core.runtime,body);
    if (!core.check_run_end()) {
        if (state.loadout.ready) timed("progression",[&]{ProgressionSystem::open(core);});
        else if (state.legacy_progression.ready) core.open_cards(false);
    }
    return true;
}
void RunRunner::enter_bonus(godot::SpeedRunCore &core) {
    auto &s=core.runtime.state;s.control.bonus_remaining=core.runtime.content->warp.bonus_time;s.draw.gauge=1;
    EnemySystem::clear_regular(core.runtime);AttackSystem::clear_hostile(s,AttackEndReason::BonusClear);
    godot::Dictionary event;event["enter"]=true;event["pos"]=s.ship.pos;core.emit_event("bonus",event);
}
void RunRunner::leave_bonus(godot::SpeedRunCore &core) {
    auto &state=core.runtime.state;state.control.bonus_remaining=0;
    EnemySystem::clear_regular(core.runtime);AttackSystem::clear_hostile(state,AttackEndReason::BonusClear);
    godot::Dictionary event;event["enter"]=false;event["pos"]=state.ship.pos;core.emit_event("bonus",event);
}
}
