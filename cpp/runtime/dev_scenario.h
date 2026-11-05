#pragma once
#include <godot_cpp/variant/dictionary.hpp>
namespace speed {
class RunRuntime;
struct TimelineScenario { double time=0; };
// 開始時と停止境界の途中再生は、同じ入力検査と時計・出現設定を使う。
bool decode_timeline_scenario(const godot::Dictionary &params,TimelineScenario &out);
void apply_timeline_scenario(RunRuntime &run,const TimelineScenario &scenario);
}
