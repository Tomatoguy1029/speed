#include "gunner.h"
#include "../../systems/timing.h"
namespace speed {
bool GunnerTiming::advance(double &remaining,double &charge,double dt,double warn,double interval) {
    RemainingTimer timer{remaining};timer.advance(dt);remaining=timer.remaining;
    charge=remaining<warn?1.0-remaining/warn:0;
    if (!timer.due()) return false;
    remaining=interval;return true;
}
}
