#pragma once
namespace speed {
class GunnerTiming {
public:
    static bool advance(double &remaining,double &charge,double dt,double warn,double interval);
};
}
