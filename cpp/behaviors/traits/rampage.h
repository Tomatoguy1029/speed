#pragma once
#include "../../state/combat_types.h"
namespace speed {
class RunRuntime;
class RampageBehavior {
public:
    static void launch(RunRuntime &);
    static void kill(RunRuntime &,const DeathContext &);
    static void end(RunRuntime &);
    static void step(RunRuntime &,double dt);
};
}
