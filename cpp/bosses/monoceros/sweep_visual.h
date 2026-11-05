#pragma once
#include "../../runtime/run_runtime.h"
#include "../../state/boss_states.h"
namespace speed {
struct MonocerosSweepVisualSystem {
    // 本番の角を組み立てた直後に固定更新ごとに呼ぶ。
    static void step(RunRuntime &,BossBodyState &,const TechniqueState *,godot::Vector2 center,godot::Vector2 tip);
};
}
