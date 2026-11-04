#pragma once
#include "../../runtime/run_runtime.h"
#include "../collision_query.h"
#include <optional>
namespace speed {
struct BeamParams {
    godot::Vector2 position;
    double angle=0,length=0,half_width=0,arc=0,delay=0,active=0,damage=0;
    godot::Color color=godot::Color::html("ff5a6e");
    BeamStyle style=BeamStyle::Plain;
    EnemyHandle owner;
    bool attached=true;
    BudgetToken budget;
    TechniqueHandle technique;
    uint32_t definition=0;
};
class BeamSystem {
public:
    static AttackHandle emit(RunRuntime &,const BeamParams &);
    static bool move(RunRuntime &,AttackHandle,godot::Vector2,double angle,std::optional<double> length={});
    static ContactShape geometry(const HazardState &);
    static void render(const RunRuntime &,uint32_t row,godot::Rect2 view,godot::Array &shapes);
};
}
