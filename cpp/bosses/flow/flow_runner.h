#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {
class FlowRunner {
public:
    static bool attach(RunRuntime &,EnemyHandle,uint32_t definition,const std::vector<EnemyHandle> &participants={});
    static void step(RunRuntime &,double dt);
    static void cancel(RunRuntime &,BossFlowState &);
    static void begin_rest(RunRuntime &,BossFlowState &,uint32_t);
    static bool start_reactive(RunRuntime &,BossFlowState &,EnemyHandle,uint32_t,double);
    static bool condition(const RunRuntime &,const BossFlowState &,uint32_t definition,bool filtered_target,uint32_t participant=0);
    static bool validate_content(const ContentBundle &);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &);
};
}
