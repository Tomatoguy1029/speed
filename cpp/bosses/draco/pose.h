#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class DracoPose {public:
    static std::vector<godot::Vector2> samples(const std::vector<godot::Vector2> &,uint32_t);
    static void update(RunRuntime &,BossBodyState &);
    static void reset(RunRuntime &,BossBodyState &);
    static void depth(RunRuntime &,BossBodyState &,double,double);
    static std::vector<godot::Vector2> points(const RunRuntime &,const BossBodyState &);
    static bool contains(const RunRuntime &,const BossBodyState &,godot::Vector2,double);
};}
