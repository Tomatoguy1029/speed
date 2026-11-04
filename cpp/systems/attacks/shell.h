#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct ShellParams {
    EnemyHandle source;BudgetToken budget;
    double angle=0,speed=0,radius=0,range=0,burst=0,damage=0;
    std::vector<uint32_t> contents;
};
class ShellSystem {
public:
    static AttackHandle emit(RunRuntime &,const ShellParams &);
    static void burst(RunRuntime &,AttackHandle,godot::Vector2);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
