#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {class RunRuntime;class AfterimageBehavior {public:static void launch(RunRuntime &);static void end(RunRuntime &);static void trail(RunRuntime &,godot::Vector2,godot::Vector2);static void step(RunRuntime &,double);static void clear(RunRuntime &);};}
