#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class FriendShotSystem {
public:
    static AttackHandle emit(RunRuntime &,godot::RunState::Friendly);
};
}
