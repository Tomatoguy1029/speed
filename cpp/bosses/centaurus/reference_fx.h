#pragma once
#include "../../state/boss_states.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
class RunRuntime;
struct BossBodyState;
struct TechniqueState;
class CentaurusReferenceFx {
public:
    static void update(RunRuntime &,BossBodyState &);
    static void released(RunRuntime &,const TechniqueState &,godot::Vector2 position,double angle);
    static godot::Dictionary snapshot(const BossBodyState &);
};
}
