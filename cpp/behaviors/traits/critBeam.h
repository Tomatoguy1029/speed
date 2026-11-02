#pragma once
#include "../../state/combat_types.h"
namespace speed {
class RunRuntime;
class CritBeamBehavior {
public:
    static void critical(RunRuntime &,const DamageRequest &,const DamageResult &);
};
}
