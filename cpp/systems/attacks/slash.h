#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct SlashParams {
    godot::Vector2 position;
    double angle=0,speed=0,size=0,range=0,damage=0,side=1;
    EnemyHandle owner;
    BudgetToken budget;
};
class SlashSystem {
public:
    static AttackHandle emit(RunRuntime &,const SlashParams &);
    static bool touches(const ContentBundle &,godot::Vector2,double angle,double size,double side,godot::Vector2,double reach);
    static bool contact(RunRuntime &,AttackHandle,godot::Vector2);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
