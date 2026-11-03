#pragma once
#include "../../runtime/run_runtime.h"
#include "../../systems/tracking_policy.h"
namespace speed {
class DefenderBehavior {
public:
    static bool move(RunRuntime &,EnemyHandle,double dt,const TrackingPolicy &);
    static bool boost(RunRuntime &,EnemyHandle,double speed,double wobble,double until,double phase=0);
    static bool clear_boost(RunRuntime &,EnemyHandle);
    static void gone(RunRuntime &,EnemyHandle);
    static const DefenderPost *post(const RunRuntime &,EnemyHandle);
private:
    static void assign(RunRuntime &);
};
}
