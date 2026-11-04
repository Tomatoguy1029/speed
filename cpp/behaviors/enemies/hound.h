#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct TrackingPolicy;
class HoundBehavior {
public:
    static bool running(const godot::RunState &,uint32_t row);
    static godot::Vector2 pack_velocity(const RunRuntime &,uint32_t row);
    static void prepare(RunRuntime &,const std::vector<size_t> &rows);
    static godot::Vector2 pursuit(RunRuntime &,uint32_t row,double dt,const TrackingPolicy &);
    static bool ordered_move(RunRuntime &,uint32_t row,double dt,const TrackingPolicy &);
};
}
