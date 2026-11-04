#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "../../content/content_bundle.h"
namespace speed {class CentaurusBody {public:static EnemyHandle spawn(RunRuntime &,uint32_t,godot::Vector2,bool entrance);static void spawned(RunRuntime &,BossBodyState &);static void step(RunRuntime &,BossBodyState &,double);static void position_tick(RunRuntime &,BossBodyState &,double);static void pre_step(RunRuntime &,BossBodyState &,double);static bool validate(const godot::RunState &,const ContentBundle &,const BossBodyState &);};}
