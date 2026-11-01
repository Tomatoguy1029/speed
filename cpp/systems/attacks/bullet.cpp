#include "bullet.h"
#include "../attack_system.h"
#include "../attack_budget.h"
#include "../../output/frame_builder.h"
#include <cmath>
#include <algorithm>
namespace speed {
void BulletSystem::petrify(godot::RunState &state,godot::Rect2 view,double duration) {
    for (auto &shot:state.hostiles) if (shot.alive && view.has_point(shot.pos)) shot.stone=duration;
}
AttackHandle BulletSystem::fire_enemy(RunRuntime &run,EnemyHandle source,double angle,double speed,const BulletValues &values) {
    auto &state=run.state;
    if (!state.started || state.closed || !state.enemy_handles.contains(source) || !std::isfinite(angle) || !std::isfinite(speed) || speed<0 || !std::isfinite(float(speed))) return {};
    for (const auto &value:{values.damage,values.slow,values.turn}) if (value && (!std::isfinite(*value) || *value<0)) return {};
    for (const auto &value:{values.slow,values.turn}) if (value && !std::isfinite(float(*value))) return {};
    const auto found=std::find_if(run.content->hostile_definitions.begin(),run.content->hostile_definitions.end(),[](const auto &value){return value.kind==uint32_t(HostileKind::Bullet);});
    if (found==run.content->hostile_definitions.end()) return {};
    const auto &definition=*found;const auto &enemy=state.enemies[source.slot];const auto direction=godot::Vector2::from_angle(angle);
    godot::RunState::Hostile shot;shot.definition=uint32_t(found-run.content->hostile_definitions.begin()+1);
    shot.kind=definition.kind;shot.pos=enemy.pos+direction*enemy.radius;shot.vel=direction*speed;shot.speed=speed;
    shot.radius=definition.radius;shot.life=definition.life;shot.damage=values.damage.value_or(definition.damage);shot.slow=values.slow.value_or(definition.slow);shot.turn=values.turn.value_or(definition.turn);
    AttackSpec spec;spec.cause=Cause::Bullet;spec.owner.live_source=source;spec.policies=EndPolicy::NaturalLifetime|EndPolicy::ClearWithBonus;
    spec.owner.budget.value=AttackBudgetSystem::token(state,AttackBudgetSystem::owner(state,enemy.id,enemy.attack_group));
    if (!AttackSystem::configure_contact(*run.content,definition.contact,spec)) return {};
    const auto handle=AttackSystem::emit_hostile(state,shot,spec);
    if (AttackSystem::get(state,handle)) {godot::Dictionary event;event["pos"]=enemy.pos;event["kind"]="bullet";FrameBuilder::append(run,"shoot",event);}
    return handle;
}
}
