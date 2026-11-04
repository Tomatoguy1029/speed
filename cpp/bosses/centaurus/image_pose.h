#pragma once
#include "../../content/boss_image_data.h"
#include "../../content/boss_image_pose_data.h"
#include "image_pose_state.h"
#include <string>
#include <vector>

namespace speed {
struct CentaurusImagePoseEvaluator {
    // root は parts のローカル原点から world への変換。結果のpartはSpriteの固定ID。
    static bool evaluate(const CentaurusImagePoseData &, const std::string &clip, double time,
                         const godot::Transform2D &root, std::vector<BossImagePart> &out);
    static double duration(const CentaurusImagePoseData &, const std::string &clip);
    // technique/mode は従来の set_bow_pose と同じ名前。delta は戦闘時計の差。
    static bool step(const CentaurusImagePoseData &, CentaurusImagePoseClock &, int64_t technique_id,
                     const std::string &technique, const std::string &mode, double progress,
                     double delta, double pose_time, uint32_t released, double interval,
                     const godot::Transform2D &root, std::vector<BossImagePart> &out);
};
}
