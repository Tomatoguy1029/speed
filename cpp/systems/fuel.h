#pragma once
namespace godot { struct RunState; }
namespace speed {
class RunRuntime;
// 燃料の絶対量と通知を一か所で更新する。割合は表示のためだけに求める。
class FuelSystem {
public:
    static bool valid(const godot::RunState &);
    static double maximum(const godot::RunState &);
    static double amount(const godot::RunState &);
    static double draw_limit(const godot::RunState &);
    static double speed_ratio(const godot::RunState &);
    static void set(RunRuntime &, double fuel, bool silent=false);
    static void add(RunRuntime &, double fuel, bool gain_multiplier=true);
    static void step(RunRuntime &, double world_dt, bool flying);
};
}
