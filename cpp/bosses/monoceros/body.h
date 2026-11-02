#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {class MonocerosBody {public:static EnemyHandle spawn(RunRuntime &,uint32_t,godot::Vector2,bool entrance);static void step(RunRuntime &,BossBodyState &,double);};}
