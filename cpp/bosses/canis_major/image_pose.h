#pragma once
#include "image_pose_state.h"
#include "../../content/boss_image_data.h"
#include "../../state/boss_states.h"
#include <godot_cpp/variant/array.hpp>
#include <vector>

namespace speed {
struct RunRuntime;
struct BossBodyState;

class CanisImagePose {
public:
    // 本体移動・技更新後、画像接触判定を使う前に呼ぶ。
    static void update(RunRuntime &,BossBodyState &);
    static godot::Vector2 mouth(const RunRuntime &,const BossBodyState &);
    // 保存済みの部位姿勢を描画側に渡す。
    static godot::Array snapshot(const RunRuntime &,const BossBodyState &);
};
}
