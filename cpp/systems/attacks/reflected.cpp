#include "reflected.h"
#include "../attack_system.h"
#include "../../output/frame_builder.h"
#include "../../output/event_builder.h"
#include <algorithm>
namespace speed {
void ReflectedSystem::reflect(RunRuntime &run,EnemyHandle source,godot::Vector2 impact,godot::Vector2 velocity,double radius) {
    auto &state=run.state;if (!state.enemy_handles.contains(source)) return;
    auto &target=state.enemies[source.slot];if (target.fire_t>0) return;
    const auto &definition=run.content->definitions[target.definition];
    auto normal=(impact-target.pos).normalized();if (normal.is_zero_approx()) normal=godot::Vector2::from_angle(target.facing);
    const auto direction=(velocity-normal*2.0*velocity.dot(normal)).normalized();
    godot::RunState::Hostile reflected;reflected.kind=int64_t(HostileKind::Reflected);reflected.definition=definition.reflected_definition;
    reflected.pos=impact+normal*2.0;reflected.vel=direction*definition.reflect_speed;reflected.speed=definition.reflect_speed;
    reflected.radius=std::clamp(radius,5.0,10.0);reflected.life=definition.reflect_life;reflected.damage=definition.reflect_damage;
    AttackSpec spec;spec.cause=Cause::Reflected;spec.owner.live_source=source;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    if (reflected.definition) AttackSystem::configure_contact(*run.content,run.content->hostile_definitions[reflected.definition-1].contact,spec);
    else if (!run.content->contacts.empty()) AttackSystem::configure_contact(*run.content,1,spec);
    AttackSystem::emit_hostile(state,reflected,spec);
    target.fire_t=std::max(0.01,definition.reflect_interval);target.flash=0.1;
    godot::Dictionary event;event["pos"]=impact;event["normal"]=normal;EventBuilder::flush_combat(run);FrameBuilder::append(run,"shield_reflect",event);
}
}
