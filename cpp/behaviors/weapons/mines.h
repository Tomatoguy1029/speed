#pragma once
namespace speed {
class RunRuntime;
class MinesBehavior {
public:
    static void end(RunRuntime &);
    static void step(RunRuntime &,double);
};
}
