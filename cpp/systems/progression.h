#pragma once
#include "../runtime/run_runtime.h"
namespace godot { class SpeedRunCore; }
namespace speed {
class ProgressionSystem {
public:
    static void initialize(RunRuntime &,bool initial);
    static double next_xp(const RunRuntime &);
    static bool add_experience(godot::SpeedRunCore &,double final_xp);
    static bool open(godot::SpeedRunCore &,bool initial=false);
    static bool choose(RunRuntime &,int64_t offer,int64_t candidate);
    static bool cancel(RunRuntime &,int64_t offer);
    static bool reroll(godot::SpeedRunCore &,int64_t offer);
    static bool complete(RunRuntime &,int64_t request,int status);
    static bool retry(RunRuntime &,int64_t request);
    static void rebuild_requests(RunRuntime &);
    static void poll(godot::SpeedRunCore &);
    static godot::Dictionary ui(const RunRuntime &);
    static godot::Array requests(const RunRuntime &);
};
}
