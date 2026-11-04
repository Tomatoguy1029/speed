#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
class CanisRoar {
public:
    // 他の本体姿勢の更新後に1回呼ぶ。開始時刻・番号は本番状態に保存する。
    static const CanisRoarDefinition *settings(const ContentBundle &,uint32_t technique);
    static void update(RunRuntime &,BossBodyState &);
    static godot::Dictionary snapshot(const RunRuntime &,const BossBodyState &);
    static bool validate(const BossBodyState &,const ContentBundle &);
};
}
