#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
struct HydraNormalContext {BossBodyState *boss;HydraNeckState *neck;TechniqueHandle parent;double neck_rest;uint32_t damage_source;};
class HydraNormalAttack {public:
    static BossBodyState *body(RunRuntime &,EnemyHandle,const HydraNormalContext *);
    static HydraNeckState *neck(BossBodyState &,EnemyHandle,const HydraNormalContext *);
    static godot::Vector2 head_position(const RunRuntime &,const BossBodyState &,const HydraNeckState &,const HydraNormalContext *);
    static godot::Vector2 neck_base(const RunRuntime &,const BossBodyState &,const HydraNeckState &,const HydraNormalContext *);
    static TechniqueHandle ticket(const RunRuntime &,const TechniqueState &,const HydraNormalContext *);
    static void context_spec(const RunRuntime &,AttackSpec &,const HydraNormalContext *);
    static void finish(RunRuntime &,TechniqueState &,const HydraNormalContext *);
    static void step_inner(RunRuntime &,TechniqueState &,double,const HydraNormalContext &);
    static bool supports(uint32_t kind) {return (kind>=64 && kind<=68) || kind==80 || kind==81 || kind==75 || kind==91 || kind==92;}
    static void step_thunder(RunRuntime &,TechniqueState &,double,const HydraNormalContext * = nullptr);
    static void lightning(RunRuntime &,BossBodyState &,TechniqueState &,godot::Vector2,double,const HydraThunderDefinition &,const HydraNormalContext * = nullptr);
    static void step_headbutt(RunRuntime &,TechniqueState &,double);
    static void step_thrust(RunRuntime &,TechniqueState &,double,const HydraThunderDefinition * = nullptr,const HydraNormalContext * = nullptr);
    static void step_wind(RunRuntime &,TechniqueState &,double,const HydraNormalContext * = nullptr);
    static void step_blades(RunRuntime &,TechniqueState &,double);
    static void step_fixed(RunRuntime &,TechniqueState &,double,const HydraNormalContext * = nullptr);
    static void step_rubble(RunRuntime &,TechniqueState &,double,const HydraNormalContext * = nullptr);
    static void step_bolt(RunRuntime &,TechniqueState &,double,const HydraNormalContext * = nullptr);
    static void step_sweep(RunRuntime &,TechniqueState &,double);
    static BossBodyState *body(RunRuntime &,EnemyHandle);
    static HydraNeckState *neck(BossBodyState &,EnemyHandle);
    static bool ready(const RunRuntime &,EnemyHandle,uint32_t);
    static bool reserve(RunRuntime &,EnemyHandle,uint32_t);
    static void begin(RunRuntime &,TechniqueState &);
    static void step(RunRuntime &,TechniqueState &,double);
    static void cancel(RunRuntime &,TechniqueState &);
    static void aim(RunRuntime &,BossBodyState &,HydraNeckState &,double,double,const HydraNormalContext * = nullptr);
    static void cue(RunRuntime &,const BossBodyState &,const HydraNeckState &,const char *,uint32_t=0,double=0,double=0,const HydraNormalContext * = nullptr);
    static godot::Array shapes(const RunRuntime &,const BossBodyState &);
};}
