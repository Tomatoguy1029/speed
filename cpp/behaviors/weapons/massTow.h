#pragma once
#include "../../state/combat_types.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/rect2.hpp>
namespace speed {class RunRuntime;class MassTowBehavior {public:static bool capture(RunRuntime &,const DeathContext &);static void end(RunRuntime &);static void step(RunRuntime &,double);static void render(const RunRuntime &,godot::Rect2,godot::Array &);};}
