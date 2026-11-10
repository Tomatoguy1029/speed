#pragma once
namespace speed {
class RunRuntime;
class FullBurstBehavior {
public:
    static void step(RunRuntime &);
    static double rate(const RunRuntime &);
    static double strength(const RunRuntime &);
};
}
