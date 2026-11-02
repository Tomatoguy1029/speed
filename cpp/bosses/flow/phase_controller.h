#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class PhaseController {
public:
    static EnemyHandle spawn(RunRuntime &,uint32_t definition,godot::Vector2,bool entrance);
    static void step(RunRuntime &,double dt);
    static BossBodyState *find(RunRuntime &,EnemyHandle);
    static const BossBodyState *find(const RunRuntime &,EnemyHandle);
    static bool can_start(const RunRuntime &,EnemyHandle);
    static void damaged(RunRuntime &,EnemyHandle);
    static bool can_defeat(RunRuntime &,EnemyHandle);
    static void defeated(RunRuntime &,const DeathContext &);
    static void cancel(RunRuntime &,EnemyHandle);
    static bool begin_final(RunRuntime &,EnemyHandle,double charge);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &);
};
}
