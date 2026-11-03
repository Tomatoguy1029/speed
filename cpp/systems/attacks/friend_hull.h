#pragma once
#include "../../runtime/run_runtime.h"
namespace speed {
struct FriendHullParams {godot::Vector2 position,velocity;double radius=0,damage=0,life=0,knock=0,angle=0;uint32_t source_definition=0;int64_t source_id=-1;bool saw=false;};
class FriendHullSystem {public:static AttackHandle emit(RunRuntime &,const FriendHullParams &);static void render(const RunRuntime &,uint32_t,godot::Rect2,godot::Array &,double alpha=1.0);};
}
