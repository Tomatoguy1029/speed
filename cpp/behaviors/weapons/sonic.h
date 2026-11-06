#pragma once
namespace speed {class RunRuntime;
class SonicBehavior {public:static void refresh(RunRuntime &);static void launch(RunRuntime &);static void step(RunRuntime &,double);static void emit(RunRuntime &,double,godot::Vector2,godot::Vector2,double,bool,bool twin=false);};
}
