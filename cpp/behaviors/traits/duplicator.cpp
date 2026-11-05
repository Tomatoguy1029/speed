#include "duplicator.h"
#include "../../runtime/run_runtime.h"
#include "../../systems/attack_system.h"
#include "../../output/frame_builder.h"
#include "../../state/loadout_state.h"
namespace speed {
FriendlyBirthScope::FriendlyBirthScope(RunRuntime &owner,bool enabled):run(owner),active(enabled) {if (active) run.workspace.friend_birth_batches.emplace_back();}
FriendlyBirthScope::~FriendlyBirthScope() {finish();}
void FriendlyBirthScope::finish() {
    if (!active) return;
    auto originals=std::move(run.workspace.friend_birth_batches.back());run.workspace.friend_birth_batches.pop_back();active=false;
    for (auto source:originals) DuplicatorBehavior::duplicate(run,source);
}
std::vector<godot::Vector2> DuplicatorBehavior::vectors(RunRuntime &run,godot::Vector2 velocity) {
    const auto &d=run.state.loadout->duplicator;const auto &legacy=run.state.projectile_config;
    if (!d.ready && (run.api_configured || !legacy.split)) return {};
    const uint64_t maximum=d.ready?d.maximum:uint64_t(legacy.maximum),count=AttackSystem::flying_count(run.state);
    if (count>maximum || maximum-count<2) return {};
    if (run.state.control.rng.randf()>=(d.ready?d.chance:legacy.chance)) return {};
    std::vector<godot::Vector2> out;
    for (double side:{-1.0,1.0}) {
        const double angle=run.state.control.rng.randf_range(d.ready?d.angle_min:legacy.angle_min,d.ready?d.angle_max:legacy.angle_max)*(godot::Math::PI/180.0)*side;
        out.push_back(velocity.rotated(angle)*run.state.control.rng.randf_range(0.9,1.1));
    }
    return out;
}
double DuplicatorBehavior::damage_factor(const RunRuntime &run) {return run.state.loadout->duplicator.ready?run.state.loadout->duplicator.damage:run.state.projectile_config.damage;}
void DuplicatorBehavior::duplicate(RunRuntime &run,AttackHandle source) {
    const auto *record=AttackSystem::get(run.state,source);
    if (!record || record->pool!=AttackPool::Friendly) return;
    const auto parent=run.state.friends[record->row];const auto spec=record->spec;
    if (parent.kind==1 && run.state.live_debris>=200) return;
    const auto directions=vectors(run,parent.vel);if (directions.empty()) return;
    for (const auto &velocity:directions) {
        if (parent.kind==1 && run.state.live_debris>=200) break;
        auto child=parent;child.vel=velocity;child.damage*=damage_factor(run);child.angle=velocity.angle();child.trail=godot::PackedVector2Array();
        // State版は完成した複製を直接加え、親の出生列へ登録しない。
        AttackSystem::emit_friendly(run.state,std::move(child),spec);
    }
    godot::Array vectors;for (auto value:directions) vectors.push_back(value);
    godot::Dictionary event;event["pos"]=parent.pos;event["directions"]=vectors;FrameBuilder::append(run,"duplicate",event);
}
}
