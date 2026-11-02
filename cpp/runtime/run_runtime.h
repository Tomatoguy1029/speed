#pragma once
#include "../state/run_state.h"
#include "../content/content_bundle.h"
#include <memory>
#include "../output/render_builder.h"
#include "../output/frame_builder.h"
#include "../output/resource_requests.h"
#include "../systems/combat_hooks.h"

namespace speed {
struct DefenderPost {EnemyHandle actor,target;godot::Vector2 position;};
struct RunWorkspace {
    int64_t defender_posts_tick=-1;
    std::vector<DefenderPost> defender_posts;
    std::vector<std::vector<AttackHandle>> friend_birth_batches;
    std::vector<int64_t> avoidance_ids;
    std::vector<godot::Vector2> avoidance_from;
};
class RunRuntime {
public:
    godot::RunState state;
    std::shared_ptr<const ContentBundle> content = std::make_shared<const ContentBundle>();
    RunWorkspace workspace;
    mutable RenderWorkspace render_workspace;
    FrameWorkspace frame_workspace;
    ResourceWorkspace resource_workspace;
    CombatHooks combat_hooks;
    int64_t epoch=1;
    int64_t api_run_id=0, last_command_id=0;
    bool api_configured=false, api_development=false, busy=false;
    godot::Dictionary last_command_response;
    bool full_output_dirty=false, pending_resource_rebuild=false;
    void replace_definitions(std::vector<EnemyDefinition> definitions) {
        auto next = std::make_shared<ContentBundle>();
        next->definitions = std::move(definitions);
        content = std::move(next);
    }
};
}
