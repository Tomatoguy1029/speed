#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class TechniqueRunner {
public:
    static double attack_length(const BossTechniqueDefinition &);
    static double attack_length(const RunRuntime &,EnemyHandle,uint32_t);
    static double cooldown(const RunRuntime &,EnemyHandle,uint32_t);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static TechniqueHandle begin(RunRuntime &,EnemyHandle,uint32_t definition,const char *origin="external_forced",int64_t decision_id=0);
    static void step(RunRuntime &,double dt);
    static void begin_part(RunRuntime &,TechniqueState &,uint32_t);
    static bool running(const RunRuntime &,TechniqueHandle);
    static void cancel(RunRuntime &,TechniqueHandle,const char *reason="cancelled");
    static void observe_boundaries(RunRuntime &,const TechniqueState &,const char *interrupted=nullptr);
    static void observe_scripted(RunRuntime &,BossBodyState &,const char *action,const char *origin,ObservationEvent::Step,bool observed_start=false);
    static void finish_scripted(RunRuntime &,BossBodyState &,const char *reason="finished");
    static bool owns(const RunRuntime &,EnemyHandle);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::PackedVector2Array shape(const RunRuntime &,const TechniqueState &,bool warning=false);
    static godot::Array snapshot(const RunRuntime &);
};
}
