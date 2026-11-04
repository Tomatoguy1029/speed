#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
class CanisFireVisualSystem {
public:
    static const CanisFireFxDefinition *settings(const ContentBundle &,uint32_t technique);
    static void begin(RunRuntime &,BossBodyState &,AttackHandle,uint32_t technique,EnemyHandle hound);
    static void begin_continuous(RunRuntime &,BossBodyState &,const TechniqueState &,double duration);
    // 最終camera更新の後、元の1/60秒ごとに実画素と通過履歴を更新する。
    static void tick(RunRuntime &,BossBodyState &);
    static godot::Array snapshot(const RunRuntime &,const BossBodyState &);
    static void clear(BossBodyState &);
    static bool validate(const BossBodyState &,const ContentBundle &);
};
}
