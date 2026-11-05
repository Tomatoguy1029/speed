#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {
struct HoundLungeSettings {
    double speed=0,duration=0,damage=0,grace=0;
    bool sweep=true,shared_hit=false,overwrite_velocity=true,quiet=true,release_on_cancel=true,release_on_end=true,defer_first_contact=false,track_aim=true,manual_retained=false;
    TechniqueHandle technique;
    uint32_t source_technique=0;
};
class CanisHoundLunge {public:
    static AttackHandle begin(RunRuntime &,BossBodyState &,EnemyHandle,int64_t action,const HoundLungeSettings &);
    static void step(RunRuntime &,BossBodyState &,int64_t action=0);
    static void end_action(RunRuntime &,BossBodyState &,int64_t,bool cancelled);
    static bool action_hit(const BossBodyState &,int64_t);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &,const BossBodyState &);
};}
