// りゅう座の尾が通った面。元と同じ順序で画素を重ねる。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
namespace {
double mix1(double a,double b,double t) {return a+(b-a)*t;}
double smooth(double a,double b,double x) {const double t=std::clamp((x-a)/(b-a),0.0,1.0);return t*t*(3-2*t);}
}
int SpeedFxRaster::sweep_wake(PackedVector2Array tails,PackedVector2Array roots,PackedFloat64Array ages,PackedFloat32Array reach,PackedFloat32Array fine,PackedColorArray palette,double time,double fade) {
    reference_flags_=0;
    if (tails.size()<3 || tails.size()!=roots.size() || tails.size()!=ages.size() || reach.size()!=96 || fine.size()!=96 || palette.size()<8) return 0;
    const auto blend_pixel=[&](Vector2 p,Color color,double alpha) {
        const double a=alpha*fade;
        if (color.a<=0 || a<=0.004) return;
        const int x=int(std::floor(p.x)),y=int(std::floor(p.y));
        if (x<0 || x>=w_ || y<0 || y>=h_) return;
        auto *out=c_+(y*w_+x)*4;
        const double da=double(out[3])/255.0,oa=a+da*(1-a),k=a/oa;
        out[0]=uint8_t(int(int(double(color.r)*255.0)*k+out[0]*(1-k)));
        out[1]=uint8_t(int(int(double(color.g)*255.0)*k+out[1]*(1-k)));
        out[2]=uint8_t(int(int(double(color.b)*255.0)*k+out[2]*(1-k)));
        out[3]=uint8_t(int(oa*255.0));
        if (out[3]>0) reference_flags_|=1;
    };
    for (int i=1;i<tails.size();++i) {
        const Vector2 a0=tails[i-1],a1=tails[i],b0=roots[i-1],b1=roots[i];
        const int steps=int(std::ceil(std::max(a0.distance_to(a1),b0.distance_to(b1))+1.0)),span=int(std::ceil(a1.distance_to(b1)+1.0));
        const double f=ages[i],bend=std::sin(i*0.22+time*1.5)*0.02;
        for (int n=0;n<=steps;++n) {
            const double u=double(n)/steps;
            const Vector2 a=a0.lerp(a1,u),b=b0.lerp(b1,u);
            for (int m=0;m<=span;++m) {
                const double v=std::clamp(double(m)/span+bend,0.0,1.0);
                const int slot=int(std::round(v*95.0));
                const double k=f/double(reach[slot]);
                if (k>=1) continue;
                const double end=smooth(0.62,1,k),thin=mix1(1,double(fine[slot])*1.5,end);
                const double heat=std::clamp(1-v*0.8-k*0.45,0.0,1.0),level=mix1(5.6,1.4,heat);
                const int ci=std::min(6,int(std::floor(level)));
                const double alpha=0.82*(1-v*v*0.8)*(1-end)*std::min(1.0,thin+(1-end));
                if (alpha>0.02) blend_pixel(a.lerp(b,double(m)/span),palette[ci].lerp(palette[ci+1],level-ci),alpha);
            }
        }
    }
    return reference_flags_;
}
}
