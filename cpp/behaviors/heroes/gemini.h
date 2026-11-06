#pragma once
#include <godot_cpp/variant/vector2.hpp>
namespace speed {class RunRuntime;class GeminiBehavior {public:static void launch(RunRuntime &,godot::Vector2,godot::Vector2);static void end(RunRuntime &);static void step(RunRuntime &,double);static bool active(const RunRuntime &);static void follow(RunRuntime &);static void duplicate(RunRuntime &,int64_t);static void weapons(RunRuntime &,double);static double equipment_appear(const RunRuntime &);static bool motion(const RunRuntime &,godot::Vector2 &,godot::Vector2 &,godot::Vector2 &);};}
