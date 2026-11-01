#pragma once
#include "run_runtime.h"
namespace speed {
class Lifecycle {
public:
    static bool finish(RunRuntime &,ResultKind);
    static godot::Variant result(const RunRuntime &);
};
}
