#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
struct MonocerosImagePoseSystem {
    static bool refresh(RunRuntime &,BossBodyState &);
};
}
