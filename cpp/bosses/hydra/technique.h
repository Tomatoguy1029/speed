#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class HydraTechnique {public:
    static bool supports(uint32_t kind) {return kind==72;}
    static const HydraMajorDefinition &rule(const RunRuntime &,uint32_t);
    static void cue(RunRuntime &,const BossBodyState &,const char *,uint32_t,double=0);
    static bool busy(const RunRuntime &,const BossBodyState &);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static bool reserve(RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void tick(RunRuntime &,double);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static void finish(RunRuntime &,TechniqueState &,bool);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static void curve(RunRuntime &,TechniqueState &,double);
    static AttackHandle emit(RunRuntime &,TechniqueState &,EnemyHandle,const std::vector<godot::Vector2> &,double,double,double,Cause=Cause::Beam);
};}
