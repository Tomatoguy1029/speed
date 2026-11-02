#pragma once
#include "../../runtime/run_runtime.h"
#include "../collision_query.h"
#include <optional>
namespace speed {
struct WallParams {
    godot::Vector2 position;
    double angle=0,length=0,half_width=0,delay=0,active=0,damage=0;
    godot::Color color=godot::Color::html("ffd27a");
    WallStyle style=WallStyle::Plain;
    bool blocking=false,attached=false;
    EnemyHandle owner;
    BudgetToken budget;
};
struct WallHit {double t=0;godot::Vector2 point,normal;};
class WallSystem {
public:
    static AttackHandle emit(RunRuntime &,const WallParams &);
    static bool move(RunRuntime &,AttackHandle,godot::Vector2,double,std::optional<double> length={});
    static ContactShape geometry(const HazardState &);
    static std::optional<WallHit> block_hit(const RunRuntime &,godot::Vector2,godot::Vector2,double);
    static bool bounce_ship(RunRuntime &,godot::Vector2);
    static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &);
};
}
