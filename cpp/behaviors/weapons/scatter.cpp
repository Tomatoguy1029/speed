#include "../traits/fullBurst.h"
#include "scatter.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/friend_shot.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
void ScatterBehavior::step(RunRuntime &run,double dt) {
    auto &state=run.state;auto &weapon=state.loadout->scatter;
    if (!weapon.ready || dt<=0 || state.controls_locked || state.phase!=godot::RunState::Phase::Play) return;
    weapon.recoil=remaining_time(weapon.recoil,dt);
    if (state.draw.drawing || state.draw.tracing) return;
    const auto &loadout=*state.loadout;const auto &effects=loadout.effects;const auto &post=run.content->scatter_post;
    const double rate=FullBurstBehavior::rate(run);
    const double floor=std::min(weapon.base_interval,std::max(post.minimum_interval,weapon.base_interval*post.minimum_ratio));
    const double interval=std::max(floor,weapon.base_interval*(1-post.interval_increment*double(loadout.post_weapon_interval_stacks)))/rate;
    // Sourceは経過時間を加算してからfmodする。残り時間の減算へ変換すると境界tickがずれる。
    weapon.interval=interval;weapon.elapsed+=dt;weapon.fire.remaining=interval-weapon.elapsed;
    if (weapon.elapsed<interval) return;
    weapon.elapsed=std::fmod(weapon.elapsed,interval);weapon.fire.remaining=interval-weapon.elapsed;
    const int64_t count=EquipmentSystem::shot_count(run,weapon.shots);
    const double angle=state.ship.heading.angle();
    const auto origin=state.ship.pos+state.ship.heading*16.0*1.82*run.content->config.character_scale;
    const double speed=1300.0*(1+post.projectile_increment*double(loadout.post_projectile_speed_stacks));
    const double damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,weapon.definition)*weapon.damage;
    for (int64_t i=0;i<count;++i) {
        godot::RunState::Friendly shot;
        shot.pos=origin;shot.vel=godot::Vector2::from_angle(angle+(i-(count-1)/2.0)*weapon.spread)*speed;
        shot.radius=5.0*effects.area;shot.damage=damage;
        shot.life=weapon.life*(1+post.duration_increment*double(loadout.post_duration_stacks));
        shot.knock=weapon.knock*(1+post.knockback_increment*double(loadout.post_knockback_stacks));
        shot.color=godot::Color::html("d8f6ff");shot.weapon_id="W02";shot.visual="weapon/scatter";
        FriendShotSystem::emit(run,std::move(shot));
    }
    weapon.recoil=0.07;
    godot::Dictionary event;event["id"]=godot::StringName("W02");event["pos"]=origin;event["angle"]=angle;event["visual_key"]="weapon/scatter";
    FrameBuilder::append(run,"weapon_fire",event);
}
}
