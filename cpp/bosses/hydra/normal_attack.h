#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class HydraNormalAttack {public:
    static bool supports(uint32_t kind) {return (kind>=64 && kind<=68) || kind==80 || kind==81;}
    static void step_thrust(RunRuntime &,TechniqueState &,double);
    static void step_blades(RunRuntime &,TechniqueState &,double);
    static void step_fixed(RunRuntime &,TechniqueState &,double);
    static void step_rubble(RunRuntime &,TechniqueState &,double);
    static void step_bolt(RunRuntime &,TechniqueState &,double);
    static void step_sweep(RunRuntime &,TechniqueState &,double);
    static BossBodyState *body(RunRuntime &,EnemyHandle);
    static HydraNeckState *neck(BossBodyState &,EnemyHandle);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static bool reserve(RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static void aim(RunRuntime &,BossBodyState &,HydraNeckState &,double,double);
    static void cue(RunRuntime &,const BossBodyState &,const HydraNeckState &,const char *,uint32_t=0,double=0,double=0);
    static godot::Array shapes(const RunRuntime &,const BossBodyState &);
};}
