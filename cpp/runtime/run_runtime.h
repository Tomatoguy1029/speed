#pragma once
#include "../state/run_state.h"
#include "../content/content_bundle.h"
#include <memory>

namespace speed {
struct RunWorkspace {
    std::vector<int64_t> avoidance_ids;
    std::vector<godot::Vector2> avoidance_from;
};
class RunRuntime {
public:
    godot::RunState state;
    std::shared_ptr<const ContentBundle> content = std::make_shared<const ContentBundle>();
    RunWorkspace workspace;
    int64_t epoch=1;
    bool full_output_dirty=false, pending_resource_rebuild=false;
    void replace_definitions(std::vector<EnemyDefinition> definitions) {
        auto next = std::make_shared<ContentBundle>();
        next->definitions = std::move(definitions);
        content = std::move(next);
    }
};
}
