#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct CentaurusImagePoseSystem {
    // 接触と表示の直前に呼ぶ。同じ戦闘時計での複数回呼出は時計を進めない。
    static bool refresh(RunRuntime &, BossBodyState &);
};
}
