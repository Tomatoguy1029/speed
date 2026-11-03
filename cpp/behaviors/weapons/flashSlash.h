#pragma once
#include "../../state/entity_store.h"
namespace speed {class RunRuntime;class FlashSlashBehavior {public:static void contact(RunRuntime &,EnemyHandle,double);static void end(RunRuntime &);static void step(RunRuntime &,double);static void dispose(RunRuntime &);};}
