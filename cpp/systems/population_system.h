#pragma once
#include "../../native/runtime_data.h"
namespace speed {
class RunRuntime;
class PopulationSystem {
public:
    static double sample_curve(const SpawnTimeline::Curve &,double);
    static void prepare(RunRuntime &);
    static void sync_attack_budget(RunRuntime &);
};
}
