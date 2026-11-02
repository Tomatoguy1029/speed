#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct RenderBatchBuffer;
struct StarBoltParams {godot::Vector2 position;double angle=0,speed=0,damage=0;EnemyHandle owner;BudgetToken budget;TechniqueHandle technique;uint32_t definition=0;};
class StarBoltSystem {
public:
    static AttackHandle emit(RunRuntime &,const StarBoltParams &);
    static void render(const RunRuntime &,uint32_t,RenderBatchBuffer &,RenderBatchBuffer &);
};
}
