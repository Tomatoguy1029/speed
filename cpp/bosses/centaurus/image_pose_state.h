#pragma once
#include <cstdint>
#include <string>
namespace speed {
// 部位の発射アニメーションは戦闘時計で保存し、checkpointでも同じ姿勢へ戻す。
struct CentaurusImagePoseClock {
    std::string clip,technique;
    int64_t technique_id=0;
    uint32_t released=0;
    double elapsed=0,shot_interval=0.4,last_body_clock=-1;
};
}
