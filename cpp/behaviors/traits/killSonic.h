#pragma once
#include "../../state/combat_types.h"
namespace speed {class RunRuntime;
class KillSonicBehavior {public:static void launch(RunRuntime &);static void end(RunRuntime &);static void kill(RunRuntime &,const DeathContext &);static void step(RunRuntime &,double);};
}
