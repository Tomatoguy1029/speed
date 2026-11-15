#pragma once
#include "../state/enemy_states.h"
#include <cstdint>
namespace speed {
class RunRuntime;
/// 敵の行動の段階から、種類ごとの音の欄を鳴らす合図を出す。
class EnemyAudio {
public:
    /// 行動の段階（構え・突進・戻り）が変わったときに、種類ごとの予兆・発動の欄を鳴らす。
    static void mode_changed(RunRuntime &,uint32_t row,EnemyMode before);
    /// 生まれて最初の更新で、いる間ずっと鳴る欄を鳴らし始める。止めるのは撃破・退場の通知を受けた Godot 側。
    static void spawned(RunRuntime &,uint32_t row);
};
}
