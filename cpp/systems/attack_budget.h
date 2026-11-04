#pragma once
#include "../state/run_state.h"
namespace speed {
class RunRuntime;
struct BudgetSettings {bool enabled=false;double budget=4,jitter=0.3;};
struct BudgetRequest {
    std::string owner;
    std::vector<AttackCategory> categories;
    EnemyHandle source;
    double duration=0,priority=0,cost=1;
    bool reuse_residual=false;
};
class AttackBudgetSystem {
    RunRuntime &run;
    std::string next_owner() const;
public:
    explicit AttackBudgetSystem(RunRuntime &runtime):run(runtime) {}
    double used_cost() const;
    bool request(const BudgetRequest &);
    bool advance(double at);
    int64_t token(const std::string &owner) const;
    bool owns(const std::string &owner,int64_t id) const;
    void cancel_wait(const std::string &owner,int64_t id);
    void cancel(const std::string &owner,int64_t id);
    int64_t passive(const std::string &owner,EnemyHandle source);
    void external(int64_t token,const std::string &key,bool retain);
    bool guard_active() const;
    static double used_cost(const godot::RunState &);
    static int64_t token(const godot::RunState &,const std::string &owner);
    static bool owns(const godot::RunState &,const std::string &owner,int64_t id);
    static bool guard_active(const godot::RunState &);
    static std::string owner(const godot::RunState &,int64_t entity,int64_t formation);
    static bool configure(godot::RunState &,BudgetSettings);
    static bool set_guard(godot::RunState &,bool active,double until);
    static void set_mode(godot::RunState &,bool enabled,bool from_stage);
    static bool set_formation_mode(godot::RunState &,bool enabled);
    static void apply_stage_budget(godot::RunState &,double capacity);
    static void reset_residuals(godot::RunState &);
    static bool retain(godot::RunState &,BudgetToken);
    static void release(godot::RunState &,BudgetToken);
    static uint32_t retained(const godot::RunState &,BudgetToken);
};
}
