#pragma once
#include "blast.h"
namespace speed {
struct ZoneParams {
    godot::Vector2 position;
    godot::Color color=godot::Color::html("ffb36b");
    double radius=0,delay=0,damage=0,enemy_damage=0;
    ZoneStyle style=ZoneStyle::Plain;
    EnemyHandle owner;
    bool attached=false;
    BudgetToken budget;
    int64_t source_id=0;uint32_t source_definition=0;
};
class ZoneSystem {
public:
    static bool explode(RunRuntime &,godot::Vector2,double radius,double damage,Cause,double knock,double life,const godot::Color &color=godot::Color::html("ffb36b"),bool no_crit=false);
    static AttackHandle emit(RunRuntime &,const ZoneParams &);
    static bool activate(RunRuntime &,AttackHandle);
    static void end_visual(RunRuntime &,uint32_t definition,bool hit,godot::Vector2);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
    static const char *scene(uint32_t style);
};
}
