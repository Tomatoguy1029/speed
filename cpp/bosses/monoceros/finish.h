#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class BossFinish {public:
    static bool check(RunRuntime &);
    static void step(RunRuntime &,double);
    static void record_approach(RunRuntime &);
    static bool skip(RunRuntime &);
    static bool abort(RunRuntime &);
    static bool validate(const godot::RunState &);
    static godot::Dictionary snapshot(const RunRuntime &);
};}
