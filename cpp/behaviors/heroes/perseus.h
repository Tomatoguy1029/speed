#pragma once
namespace speed {
class RunRuntime;
class PerseusBehavior {public:static void activate(RunRuntime &);static void step(RunRuntime &,double before,double after);};
}
