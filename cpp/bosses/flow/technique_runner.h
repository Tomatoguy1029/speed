#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class TechniqueRunner {
public:
    static double attack_length(const BossTechniqueDefinition &);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static TechniqueHandle begin(RunRuntime &,EnemyHandle,uint32_t definition);
    static void step(RunRuntime &,double dt);
    static void begin_part(RunRuntime &,TechniqueState &,uint32_t);
    static bool running(const RunRuntime &,TechniqueHandle);
    static void cancel(RunRuntime &,TechniqueHandle);
    static bool owns(const RunRuntime &,EnemyHandle);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &);
};
}
