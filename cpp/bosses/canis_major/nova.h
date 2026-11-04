#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {class CanisNova {public:
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static double attack_length(const RunRuntime &,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static double progress(const RunRuntime &,const TechniqueState &);
    static godot::Dictionary snapshot(const RunRuntime &,const TechniqueState &);
    static void effect_tick(RunRuntime &,BossBodyState &,double);
    static void field_tick(RunRuntime &,BossBodyState &);
    static void clear(RunRuntime &,BossBodyState &);
    static bool tinted(const RunRuntime &,const BossBodyState &,EnemyHandle);
    static bool validate_body(const godot::RunState &,const ContentBundle &,const BossBodyState &);
    static godot::Vector2 image_head_pose(const RunRuntime &,const BossBodyState &);
    static godot::Vector2 image_brace_flash(const RunRuntime &,const BossBodyState &);
    static void body_snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
