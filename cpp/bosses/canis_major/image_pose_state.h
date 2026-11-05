#pragma once
#include <array>
#include <godot_cpp/variant/vector2.hpp>

namespace speed {
struct CanisImageNodePose {
    godot::Vector2 position,scale{1,1};
    double rotation=0;
};
// 戦闘更新で進める表示姿勢。保持・復帰でも歩幅と着地時刻を失わない。
struct CanisImagePoseClock {
    std::array<CanisImageNodePose,7> nodes;
    godot::Vector2 previous_position,root_scale{1,1};
    double clock=-1, gait=0, walk_phase=0, landed_at=-1;
};
}
