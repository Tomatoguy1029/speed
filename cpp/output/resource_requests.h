#pragma once
#include <cstdint>
#include <vector>
namespace speed {
enum class ResourceStatus : int32_t { Cancelled=-2,Failed=-1,Pending=0,Ready=1 };
struct ResourceRequest {
    int64_t id=0,offer_id=0,candidate_id=0;
    std::vector<uint32_t> asset_keys;
    ResourceStatus status=ResourceStatus::Pending;
};
// 外部の到着状態と番号は保持点へ戻さず、復帰時に要求し直す。
struct ResourceWorkspace {
    int64_t next_id=1;
    std::vector<ResourceRequest> requests;
};
}
