#pragma once
#include "../../runtime/run_runtime.h"
#include "../collision_query.h"
namespace speed {
struct WaveParams {
    godot::Vector2 position;
    double angle=0,arc=0,radius=0,start_radius=0,speed=0,width=0,delay=0,damage=0,gap=0,gap_arc=0,enemy_damage=0;
    godot::Color color=godot::Color::html("9ad8ff");
    WaveStyle style=WaveStyle::Plain;
    EnemyHandle owner;
    BudgetToken budget;
    TechniqueHandle technique;
};
class WaveSystem {
public:
    static AttackHandle emit(RunRuntime &,const WaveParams &);
    static std::vector<AttackHandle> emit_layers(RunRuntime &,const WaveParams &,uint32_t layers,double interval,double gap_step);
    static double radius(const HazardState &);
    static ContactShape geometry(const HazardState &);
    static bool act(RunRuntime &,AttackHandle,double dt);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
