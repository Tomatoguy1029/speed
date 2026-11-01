#pragma once
#include "../../native/runtime_data.h"
#include <vector>

namespace speed {
// ランと保持したランで共有する読み取り専用の定義。
struct ContentBundle {
    std::vector<EnemyDefinition> definitions;
};
}
