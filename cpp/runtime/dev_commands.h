#pragma once
#include "run_runtime.h"

namespace speed {
struct EnemySpawn;
class DevCommands {
public:
    static int64_t place_lab_actor(RunRuntime &,size_t definition,const EnemySpawn &);
    // 生成・検証済みの同種定義を、固定更新の外でまとめて置き換える。
    static godot::Dictionary replace_definition(RunRuntime &,const godot::Dictionary &,bool append=false);
    static godot::Dictionary set_profile(RunRuntime &,const godot::Dictionary &);
    static godot::Dictionary tuning_saved(RunRuntime &,const godot::Dictionary &);
};
}
