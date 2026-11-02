#pragma once
namespace speed {
class RunRuntime;
class EndBlastBehavior {
public:
    static void end(RunRuntime &);
    static void step(RunRuntime &,double);
};
}
