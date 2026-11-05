#include "boss_ram.h"
#include "field.h"
#include "../bosses/flow/phase_controller.h"
#include "../runtime/run_runtime.h"
#include "../output/frame_builder.h"
#include "../state/boss_states.h"
#include <algorithm>
#include <cmath>
#include <climits>
namespace speed {
namespace {
void notify(RunRuntime &r,const char *kind,godot::Vector2 at) {
    const auto &ram=r.state.control.boss_ram;
    godot::Dictionary event;event["id"]=ram.target_id;event["serial"]=ram.serial;
    event["kind"]=kind;event["pos"]=at;event["direction"]=ram.direction;event["remaining"]=ram.remaining;
    if (r.state.enemy_handles.contains(ram.target)) {
        const auto &enemy=r.state.enemies[ram.target.slot];event["target_position"]=enemy.pos;event["target_radius"]=enemy.radius;
    }
    FrameBuilder::append(r,"boss_ram_contact",event);
}
}
void BossRamSystem::cancel_invalid(RunRuntime &r) {
    auto &s=r.state;auto &ram=s.control.boss_ram;
    if (!ram.pending) return;
    const auto *body=PhaseController::find(r,ram.target);
    if (!body || body->mode>=BossMode::Phase || s.phase!=godot::RunState::Phase::Play || s.controls_locked || s.encounter_protected ||
        !s.enemy_handles.contains(ram.target) || s.enemies[ram.target.slot].dead ||
        s.enemy_handles.entity_id(ram.target)!=ram.target_id) ram={};
}
bool BossRamSystem::begin(RunRuntime &r,EnemyHandle target,const BossImageCut &cut,godot::Vector2 direction,double ship_radius) {
    auto &s=r.state;auto &control=s.control;
    if (control.boss_ram.pending || control.next_boss_ram_serial==INT64_MAX || !s.enemy_handles.contains(target)) return false;
    const auto &enemy=s.enemies[target.slot];
    if (!enemy.is_boss || enemy.dead || !cut.enter.is_finite() || !cut.exit.is_finite() || !direction.is_finite() || direction.length_squared()<0.000001) return false;
    direction=direction.normalized();
    auto &ram=control.boss_ram;
    ram.pending=true;ram.target=target;ram.target_id=enemy.id;ram.serial=control.next_boss_ram_serial++;
    ram.direction=direction;ram.entry=cut.enter;
    ram.exit=cut.exit+direction*(ship_radius+4.0);
    ram.remaining=s.hitstop_enabled?std::max(s.hitstop,control.boss_ram_hitstop):0;ram.started_at=s.sim_time;ram.released_at=-1;
    s.ship.pos=cut.enter-direction*ship_radius;s.ship_pos=s.ship.pos;s.hitstop=std::max(s.hitstop,ram.remaining);
    notify(r,"in",ram.entry);
    return true;
}
void BossRamSystem::advance(RunRuntime &r,double real_dt) {
    cancel_invalid(r);auto &s=r.state;auto &ram=s.control.boss_ram;
    if (!ram.pending) return;
    ram.remaining=std::max(0.0,ram.remaining-real_dt);
    if (ram.remaining>0) return;
    // 世界の地形との接触は、瞬間移動後も通常と同じ解決器へ渡す。
    ram.released_at=s.sim_time;
    s.ship.pos=ram.exit;s.ship_pos=ram.exit;
    FieldSystem::collide_ship(r);
    notify(r,"out",ram.exit-ram.direction*(s.ship_config.ship_radius+4.0));
    ram.pending=false;
}
}
