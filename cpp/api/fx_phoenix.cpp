// 鳳凰の焦げ跡。phoenix_particle_draw.gd の pixelFX 由来の式・帰属に従う。
#include "fx_raster.h"
#include <algorithm>
#include <cmath>
namespace godot {
int SpeedFxRaster::phoenix_scorch(PackedFloat32Array field,int size,int radius,double age,PackedColorArray palette,Dictionary settings) {
    reference_flags_=0;
    if (size<=0 || field.size()!=int64_t(size)*size || palette.size()<6) return 0;
    const double t=std::clamp((age-1.6)/(3.2-1.6),0.0,1.0),fade=1-t*t*(3-2*t);
    if (fade<=0) return 0;
    const double tx=settings["x"],ty=settings["y"],painter_fade=settings["fade"],light_strength=settings["light_strength"];
    const Color dark(20/255.0f,10/255.0f,14/255.0f),light(34/255.0f,19/255.0f,26/255.0f);
    for (int y=0;y<size;++y) for (int x=0;x<size;++x) {
        const double m=field[y*size+x];
        if (m<0.35) continue;
        const int lx=x-radius,ly=y-radius;
        const double hashed=std::sin((lx*31.7+ly*7.3)*127.1+311.7)*43758.5453,k=hashed-std::floor(hashed);
        if (k>fade*std::min(1.0,(m-0.35)*2.5)) continue;
        const double heat=std::pow(std::clamp(1-age/1.4,0.0,1.0),1.3)*std::min(1.2,m*0.5)-k*0.4;
        const Vector2 cell(tx+lx+0.5,ty+ly+0.5);
        if (heat>0.08) {
            const int index=std::min(int(palette.size()-1),int(std::floor((1-std::min(1.0,heat))*(palette.size()-1))));
            reference_dot(cell,palette[palette.size()-1-index],1,painter_fade);
            if ((lx&3)==0 && (ly&3)==0) reference_glow(Vector2(tx+lx,ty+ly),5,palette[palette.size()-1-5],0.2*heat*fade,painter_fade,light_strength);
        } else reference_blend(cell,k<0.5?dark:light,0.7,painter_fade);
    }
    return reference_flags_;
}
PackedFloat32Array SpeedFxRaster::phoenix_stamp_scorch(PackedFloat32Array field,int size,int radius,Array particles) {
    if (size<=0 || field.size()!=int64_t(size)*size) return field;
    float *values=field.ptrw();
    for (int i=0;i<particles.size();++i) {
        const Dictionary particle=particles[i];
        if (int(particle["kind"])!=9 || double(particle["delay"])>0) continue;
        const double r=double(particle["size"])*0.9;
        const Vector2 center=Vector2(particle["pos"])+Vector2(radius,radius);
        for (int y=std::max(0,int(std::floor(center.y-r)));y<=std::min(size-1,int(std::ceil(center.y+r)));++y) {
            for (int x=std::max(0,int(std::floor(center.x-r)));x<=std::min(size-1,int(std::ceil(center.x+r)));++x) {
                const double d2=Vector2(x+0.5,y+0.5).distance_squared_to(center)/(r*r);
                if (d2<1) values[y*size+x]=float(double(values[y*size+x])+(1-d2)*0.08);
            }
        }
    }
    return field;
}

}
