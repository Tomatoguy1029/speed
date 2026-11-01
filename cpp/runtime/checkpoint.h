#pragma once
#include "run_runtime.h"
#include <unordered_map>

namespace speed {
inline constexpr uint32_t STATE_SCHEMA_VERSION=11;
struct RunCheckpoint {
    uint32_t state_schema_version=STATE_SCHEMA_VERSION;
    std::array<uint8_t,32> payload_sha256{};
    std::shared_ptr<const ContentBundle> content;
    godot::RunState state;
};
// COW型を含む先行経路の複製も同じ入口へ集約する。
godot::RunState clone_state(const godot::RunState &source);
bool rebuild_state_indexes(godot::RunState &state,const ContentBundle &content);
class CheckpointStore {
public:
    static int64_t hold(const RunRuntime &runtime);
    static std::shared_ptr<const RunCheckpoint> find(int64_t id);
    static bool release(int64_t id);
};
}
