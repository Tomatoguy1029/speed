#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
#include "state.h"
namespace speed {
// 同じ8bit遮光場を戦闘判定と表示へ渡す。
class CanisNovaField {public:
    static bool update(RunRuntime &,BossBodyState &,CanisNovaState &,godot::Vector2 source,double range);
    static bool safe(const RunRuntime &,const CanisNovaState &,godot::Vector2 source,double range);
};
}
