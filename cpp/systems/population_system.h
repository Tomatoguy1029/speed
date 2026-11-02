#pragma once
namespace speed {
class RunRuntime;
class PopulationSystem {
public:
    static void prepare(RunRuntime &);
    static void sync_attack_budget(RunRuntime &);
};
}
