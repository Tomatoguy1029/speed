#include "forward.h"
#include "../../systems/timing.h"
#include "../../systems/equipment.h"
#include "../../systems/progression.h"
#include "../../systems/combat_resolver.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attacks/friend_shot.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
namespace speed {
bool ForwardBehavior::advance(godot::RunState::ForwardWeapon &state,double dt,bool busy) {
    state.recoil=remaining_time(state.recoil,dt);
    if (busy) return false;
    state.fire.advance(dt);
    if (!state.fire.due()) return false;
    state.fire.fired(state.interval);state.fire.skip_missed(state.interval);return true;
}
void ForwardBehavior::set_interval(godot::RunState::ForwardWeapon &state,double interval) {
    state.fire.remaining+=interval-state.interval;state.interval=state.base_interval=interval;
}
void ForwardBehavior::step(RunRuntime &run,double dt) {
    auto &state=run.state;auto &forward=state.forward;
    if (!forward.ready || dt<=0 || state.controls_locked || state.phase!=godot::RunState::Phase::Play) return;
    const auto &effects=state.loadout->effects;
    const double rate=state.draw.gauge<1?1:1+effects.full_gauge_rate*state.draw.gauge;
    const double interval=ProgressionSystem::post_reduced(run,"weapon_interval",forward.base_interval)/rate;
    forward.fire.remaining+=interval-forward.interval;forward.interval=interval;
    if (!advance(forward,dt,state.draw.drawing || state.draw.tracing)) return;
    const int64_t count=EquipmentSystem::shot_count(run,1);
    const double angle=state.ship.heading.angle();
    const auto origin=state.ship.pos+state.ship.heading*16.0*1.82*forward.character_scale;
    for (int64_t i=0;i<count;++i) {
        godot::RunState::Friendly shot;
        shot.pos=origin;shot.vel=godot::Vector2::from_angle(angle+(i-(count-1)/2.0)*forward.spread)*1300.0*(1+ProgressionSystem::post_amount(run,"projectile_speed"));
        shot.radius=5.0*effects.area;
        shot.damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,1)*forward.damage;
        shot.life=forward.life*(1+ProgressionSystem::post_amount(run,"duration"));shot.pierce_left=forward.pierce;shot.knock=forward.knock*(1+ProgressionSystem::post_amount(run,"knockback"));
        shot.color=godot::Color::html("ffe46b");shot.weapon_id="W01";shot.visual="weapon/forward";
        FriendShotSystem::emit(run,std::move(shot));
    }
    forward.recoil=0.12;
    godot::Dictionary event;event["id"]=godot::StringName("W01");event["pos"]=origin;event["angle"]=angle;event["visual_key"]="weapon/forward";
    FrameBuilder::append(run,"weapon_fire",event);
}

}
