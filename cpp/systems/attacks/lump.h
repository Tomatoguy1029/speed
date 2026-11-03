#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct LumpParams {EnemyHandle source;double angle=0,speed=0,radius=0,damage=0;BudgetToken budget;};
class LumpSystem {public:static AttackHandle emit(RunRuntime &,const LumpParams &);};
}
