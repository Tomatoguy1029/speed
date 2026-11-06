#pragma once
#include "breath.h"
#include "../../state/boss_states.h"
namespace speed {class DracoMeteor {public:
    static constexpr double SPREAD=0.5,SPEED=430,SCALE=1.3,LIFE=9;
    static void begin(RunRuntime &,TechniqueState &);
    static void end(RunRuntime &,TechniqueState &,bool);
    static void launch(RunRuntime &,TechniqueState &,RockHandle,godot::Vector2);
    static void tick(RunRuntime &,BossBodyState &,double);
    static void clear_placed(RunRuntime &,BossBodyState &);
    static bool validate(const godot::RunState &,const DracoBodyState &);
    static void snapshot(const RunRuntime &,const BossBodyState &,godot::Dictionary &);
};}
