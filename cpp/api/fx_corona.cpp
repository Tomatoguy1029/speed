// みなみのかんむり座の渦。粒の位置・順番・透明度は元の描画と同じ。
#include "fx_raster.h"
#include <cmath>
namespace godot {
namespace {
double hash1(double x) {const double v=std::sin(x*127.1+311.7)*43758.5453;return v-std::floor(v);}
constexpr double TAU=6.28318530717958647692;
}
int SpeedFxRaster::corona_vortex(PackedFloat64Array owners,PackedColorArray palette,double fade) {
    reference_flags_=0;
    if (owners.size()%7!=0 || palette.size()<4) return 0;
    for (int i=0;i<owners.size();i+=7) {
        const Vector2 center=logical(Vector2(owners[i],owners[i+1]));
        const double radius=owners[i+2]*wl_,rotation=owners[i+3];
        for (int particle=0;particle<70;++particle) {
            const double r=radius*(0.55+0.6*hash1(particle));
            const double angle=rotation*(0.8+0.4*hash1(particle+9))+hash1(particle*3)*TAU;
            for (int s=0;s<4;++s) {
                const double x=center.x+std::cos(angle-s*0.08)*r,y=center.y+std::sin(angle-s*0.08)*r;
                reference_dot(Vector2(std::floor(x),std::floor(y)),palette[s<1?3:2],0.55-0.12*s,fade);
            }
        }
    }
    return reference_flags_;
}
}
