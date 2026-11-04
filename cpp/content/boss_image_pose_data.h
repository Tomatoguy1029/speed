#pragma once
#include "generated/run_schema.h"
#include <vector>
namespace speed {
struct CentaurusImagePoseData {
    std::vector<CentaurusImageNode> nodes;
    std::vector<CentaurusImageSprite> sprites;
    std::vector<CentaurusImageBow> bows;
    std::vector<CentaurusImageClip> clips;
    std::vector<CentaurusImageKey> keys;
    std::vector<CentaurusImagePose> poses;
};
}
