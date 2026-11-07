#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <functional>
namespace speed {class RunRuntime;class GeminiBehavior {public:static void launch(RunRuntime &,godot::Vector2,godot::Vector2);static void end(RunRuntime &);using Collide=std::function<bool(godot::Vector2)>;static void step(RunRuntime &,double,const Collide &);static bool active(const RunRuntime &);static void follow(RunRuntime &);static void ram(RunRuntime &,godot::Vector2,const Collide &);static void duplicate(RunRuntime &,int64_t);static void weapons(RunRuntime &,double);static double equipment_appear(const RunRuntime &);static bool motion(const RunRuntime &,godot::Vector2 &,godot::Vector2 &,godot::Vector2 &);};}
