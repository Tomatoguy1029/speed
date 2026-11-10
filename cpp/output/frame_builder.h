#pragma once
#include "../content/generated/combat_ids.h"
#include "metrics_builder.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <deque>

namespace speed {
class RunRuntime;
// 配信状態は戦闘状態から分離し、保持点へ巻き戻さない。
struct Notification {
    int64_t sequence=0,tick=0;
    double time=0,world_time=0;
    EventType type{};
    godot::Dictionary payload;
};
struct FrameWorkspace {
    std::deque<Notification> pending;
    mutable OutputMetrics metrics;
    int64_t next_sequence=1,acked=0,exposed=0,publishing_tick=-1;
    int64_t ui_revision=-1;
    godot::Dictionary previous_ui,ui_delta;
    bool invalid=false;
};
class FrameBuilder {
public:
    static void append(RunRuntime &run,godot::StringName type,const godot::Dictionary &payload);
    // 新規に作った辞書とその内側の可変値を渡し切る内部用。呼出し後は元を再利用しない。
    static void append_owned(RunRuntime &run,godot::StringName type,godot::Dictionary &&payload);
    static godot::Array events(RunRuntime &run);
    static int acknowledge(RunRuntime &run,int64_t epoch,int64_t sequence);
    static godot::Dictionary ui_delta(RunRuntime &run,const godot::Dictionary &ui);
    static godot::Dictionary metrics(const RunRuntime &run);
};
}
