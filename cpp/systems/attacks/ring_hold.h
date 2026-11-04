#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct RingHoldParams {EnemyHandle source;uint32_t count=0;double radius=0,wait=0,speed=0,damage=0;BudgetToken budget;};
class RingHoldSystem {public:static std::vector<AttackHandle> emit(RunRuntime &,const RingHoldParams &);};
}
