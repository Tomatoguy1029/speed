#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class FlowRunner {
public:
    static bool attach(RunRuntime &,EnemyHandle,uint32_t definition,const std::vector<EnemyHandle> &participants={});
    static void step(RunRuntime &,double dt);
    static void cancel(RunRuntime &,BossFlowState &);
    static bool condition(const RunRuntime &,const BossFlowState &,uint32_t definition,bool filtered_target,uint32_t participant=0);
    static bool validate_content(const ContentBundle &);
    static bool validate(const godot::RunState &,const ContentBundle &);
    static godot::Array snapshot(const RunRuntime &);
};
}
