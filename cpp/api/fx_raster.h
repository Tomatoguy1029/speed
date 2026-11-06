#pragma once
#include <vector>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace godot {
// 論理画素の層へ、粒や画素の多いエフェクトを描く。層の形式は fx_reference_canvas.gd の Painter と同じ。
// 炎の部品は pixelFX fire/_lib.js の式（Sprite Fusion、MIT、Hugo Duprez）。
class SpeedFxRaster : public RefCounted {
    GDCLASS(SpeedFxRaster, RefCounted)
    PackedByteArray colors_,lights_;
    uint8_t *c_=nullptr,*l_=nullptr;
    int w_=0,h_=0;
    double wl_=1;
    Vector2 camera_;
    std::vector<float> mask_;
    Vector2 mask_camera_;
    void put(int x,int y,Color c);
    void blend(float x,float y,Color c,double a);
    void add(int x,int y,Color c,double k);
    void px(float x,float y,Color c) {put(int(std::floor(x)),int(std::floor(y)),c);}
    void glow(float x,float y,float r,Color c,double strength);
    void disc(float x,float y,float r,Color c,double alpha);
    void solid(float x,float y,float r,Color c);
    void soft(float x,float y,float r,Color c,double a);
    void fire_puff(float x,float y,double k,double size,double frac,const Color *H,int n,double glow_k,double tx,double ty);
    void smoke_puff(float x,float y,double k,double size,Color c,double a_mul);
    void blade(float x,float y,float ux,float uy,double length,double w,double bend,double time,double seed,const Color *H,const double (*layers)[3],int count,double jit,double wob);
    void star(Vector2 c,double size,double spin,double a,const Color *pal);
    Vector2 logical(Vector2 world) const {return (world-camera_)*wl_+Vector2(w_,h_)*0.5;}
protected:
    static void _bind_methods();
public:
    void begin(PackedByteArray colors,PackedByteArray lights,int width,int height,double world_scale,Vector2 camera);
    PackedByteArray take_colors();
    PackedByteArray take_lights();
    void dim(double amount,double flash);
    void breath(PackedVector2Array fan,double elapsed,double active,double axis,double sweep,double half_angle,double reach,double fan_angle);
    void light_mask_reset();
    void light_mask(Vector2 mouth,double pull,Vector2 head,double head_reach,double axis,double sweep,double half_angle,double reach,PackedVector2Array rocks,double radius,double strength);
    void exhale(Vector2 at,double angle,double reach,double width,double beam_age,double extend,double life,double time);
    void comet(Vector2 pos,double angle,double age,double speed,double radius,double tail,double shine,double seed,bool with_star);
    void dark_shot(Vector2 pos,double angle,double age,double seed);
};
}
