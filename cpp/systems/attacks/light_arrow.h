#pragma once
#include "../../runtime/run_runtime.h"
#include <optional>
namespace speed {
struct LightArrowParams {godot::Vector2 position;double angle=0,speed=0,radius=0,travel=0,damage=0,length=0;bool cosmic=false;EnemyHandle owner;BudgetToken budget;};
class LightArrowSystem {
public:
    static AttackHandle emit(RunRuntime &,const LightArrowParams &);
    static std::optional<double> contact(RunRuntime &,AttackHandle,godot::Vector2,godot::Vector2,double,std::optional<double>);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
