#pragma once
#include "../state/run_state.h"
#include <memory>
#include "../output/render_builder.h"
#include "../output/frame_builder.h"
#include "../output/resource_requests.h"
#include "../systems/combat_hooks.h"

namespace speed {
struct RunWorkspace {
    std::vector<std::vector<AttackHandle>> friend_birth_batches;
    std::vector<int64_t> avoidance_ids;
    std::vector<godot::Vector2> avoidance_from;
    std::vector<std::pair<int64_t,uint32_t>> crowd_cells;
    std::vector<godot::Vector2> crowd_shift;
};
struct ContentBundle;
class RunRuntime {
public:
    godot::RunState state;
    RunRuntime();
    ~RunRuntime();
    std::shared_ptr<const ContentBundle> content;
    RunWorkspace workspace;
    mutable RenderWorkspace render_workspace;
    FrameWorkspace frame_workspace;
    ResourceWorkspace resource_workspace;
    CombatHooks combat_hooks;
    int64_t epoch=1;
    int64_t api_run_id=0, last_command_id=0;
    bool api_configured=false, api_development=false, api_review=false, busy=false;
    godot::Dictionary last_command_response;
    bool full_output_dirty=false, pending_resource_rebuild=false;
    // 開発計測のHP保持。通常ランと保存状態には含めず、明示命令のときだけ有効にする。
    double benchmark_boss_hp=-1;
    bool benchmark_survive=false;
    void replace_definitions(std::vector<EnemyDefinition> definitions);
};
}
