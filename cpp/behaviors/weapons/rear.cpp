#include "rear.h"
#include "forward.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/equipment.h"
#include "../../systems/combat_resolver.h"
#include "../../systems/attacks/friend_shot.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
#include "../../content/content_bundle.h"
#include <algorithm>
namespace speed {
void RearBehavior::step(RunRuntime &run,double dt) {
    auto &state=run.state;auto &weapon=state.loadout->rear;
    if (!weapon.ready || dt<=0 || state.controls_locked || state.phase!=godot::RunState::Phase::Play) return;
    const auto &loadout=*state.loadout;const auto &effects=loadout.effects;const auto &post=run.content->rear_post;
    const double rate=state.draw.gauge<1?1:1+effects.full_gauge_rate*state.draw.gauge;
    const double floor=std::min(weapon.base_interval,std::max(post.minimum_interval,weapon.base_interval*post.minimum_ratio));
    const double interval=std::max(floor,weapon.base_interval*(1-post.interval_increment*double(loadout.post_weapon_interval_stacks)))/rate;
    weapon.fire.remaining+=interval-weapon.interval;weapon.interval=interval;
    if (!ForwardBehavior::advance(weapon,dt,state.draw.drawing || state.draw.tracing)) return;
    const int64_t count=EquipmentSystem::shot_count(run,1);
    const auto backwards=-state.ship.heading;
    const auto mount=state.ship.pos+godot::Vector2(weapon.mount_x,weapon.mount_y).rotated(state.ship.heading.angle()+godot::Math::PI/2.0)*weapon.character_scale;
    const auto origin=mount+backwards*weapon.muzzle_distance*weapon.character_scale;
    const double angle=backwards.angle();
    const double speed=1300.0*(1+post.projectile_increment*double(loadout.post_projectile_speed_stacks));
    const double damage=CombatResolver::attack_power(run)*EquipmentSystem::weapon_damage_factor(run,weapon.definition)*weapon.damage;
    for (int64_t i=0;i<count;++i) {
        godot::RunState::Friendly shot;
        shot.pos=origin;shot.vel=godot::Vector2::from_angle(angle+(i-(count-1)/2.0)*weapon.spread)*speed;
        shot.radius=5.0*effects.area;shot.damage=damage;shot.pierce_left=weapon.pierce;
        shot.life=weapon.life*(1+post.duration_increment*double(loadout.post_duration_stacks));
        shot.knock=weapon.knock*(1+post.knockback_increment*double(loadout.post_knockback_stacks));
        shot.color=godot::Color::hex(weapon.color);shot.weapon_id="W23";shot.visual="weapon/rear";
        FriendShotSystem::emit(run,std::move(shot));
    }
    weapon.recoil=0.12;
    godot::Dictionary event;event["id"]=godot::StringName("W23");event["pos"]=origin;event["angle"]=angle;event["visual_key"]="weapon/rear";
    FrameBuilder::append(run,"weapon_fire",event);
}
}
