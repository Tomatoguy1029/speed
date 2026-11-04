#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
#include <optional>
namespace speed {class HydraTechnique {public:
    static bool supports(uint32_t kind) {return kind==72 || kind==73 || kind==74 || kind==82 || kind==83 || kind==88 || kind==89 || kind==90;}
    static const HydraMajorDefinition &rule(const RunRuntime &,uint32_t);
    static void cue(RunRuntime &,const BossBodyState &,const char *,uint32_t,double=0);
    static bool busy(const RunRuntime &,const BossBodyState &);
    static std::vector<EnemyHandle> participants(const RunRuntime &,const BossBodyState &,std::initializer_list<HydraHeadKind>);
    static bool all_participants_alive(const RunRuntime &,const HydraTechniqueState &);
    static std::vector<EnemyHandle> front_heads(const RunRuntime &,const BossBodyState &,uint32_t);
    static void swarm_prepare(RunRuntime &,TechniqueState &);
    static bool swarm_position(RunRuntime &,TechniqueState &,double);
    static void swarm(RunRuntime &,TechniqueState &,double);
    static void sequence_prepare(RunRuntime &,TechniqueState &);
    static void sequence(RunRuntime &,TechniqueState &,double);
    static void north_prepare(RunRuntime &,TechniqueState &);
    static void front_body(RunRuntime &,BossBodyState &,double);
    static void north_timeline(RunRuntime &,TechniqueState &,double);
    static godot::Array north_targets(const RunRuntime &,const BossBodyState &);
    static void pincer(RunRuntime &,TechniqueState &);
    static void debris_shatter(RunRuntime &,TechniqueState &,double);
    static void tornado(RunRuntime &,TechniqueState &,double);
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
