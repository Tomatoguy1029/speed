#pragma once
#include "../runtime/run_runtime.h"
#include "../content/content_bundle.h"
namespace speed {
class HeroesSystem {
public:
    static void initialize(RunRuntime &);
    static void place(RunRuntime &,uint32_t hero);
    static void step(RunRuntime &,double real_dt,double world_dt);
    static void activate(RunRuntime &);
    static void select_power(RunRuntime &,uint32_t);
    static void recovered(RunRuntime &,EnemyHandle);
    static void pass_stars(RunRuntime &,godot::Vector2 from,godot::Vector2 to,int64_t dash);
    static bool captive(const RunRuntime &);
    static godot::Dictionary snapshot(const RunRuntime &);
    static bool validate(const godot::RunState &,const ContentBundle &);
};
}
