#pragma once
namespace speed {
class RunRuntime;
class VortexBehavior {
public:
    static void end(RunRuntime &);
    static void step(RunRuntime &,double);
};
}
