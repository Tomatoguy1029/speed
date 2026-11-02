#pragma once
#include "../../runtime/run_runtime.h"
#include <optional>
namespace speed {class HydraTechnique {public:
    static bool supports(uint32_t kind) {return kind==72 || kind==73 || kind==74;}
    static const HydraMajorDefinition &rule(const RunRuntime &,uint32_t);
    static void cue(RunRuntime &,const BossBodyState &,const char *,uint32_t,double=0);
    static bool busy(const RunRuntime &,const BossBodyState &);
    static std::vector<EnemyHandle> participants(const RunRuntime &,const BossBodyState &,std::initializer_list<HydraHeadKind>);
    static bool all_participants_alive(const RunRuntime &,const HydraTechniqueState &);
    static void pincer(RunRuntime &,TechniqueState &);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static bool reserve(RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void tick(RunRuntime &,double);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static void finish(RunRuntime &,TechniqueState &,bool);
    static bool validate(const TechniqueState &,const ContentBundle &);
    static std::optional<HydraGridPlan> grid_plan(const RunRuntime &,const BossBodyState &,uint32_t);
    static void grid_prepare(RunRuntime &,TechniqueState &);
    static bool grid_position(RunRuntime &,TechniqueState &,double);
    static void grid(RunRuntime &,TechniqueState &);
    static std::optional<godot::Vector2> bearer_target(const RunRuntime &,const BossBodyState &);
    static godot::Dictionary snapshot(const TechniqueState &,const ContentBundle &);
    static void curve(RunRuntime &,TechniqueState &,double);
    static AttackHandle emit(RunRuntime &,TechniqueState &,EnemyHandle,const std::vector<godot::Vector2> &,double,double,double,Cause=Cause::Beam,bool persistent=false);
};}
