#pragma once
#include <vector>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
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
    int reference_flags_=0;
    void reference_dot(Vector2 p,Color color,double alpha,double fade);
    void reference_blend(Vector2 p,Color color,double alpha,double fade);
    void reference_light(Vector2 p,Color color,double strength);
    void reference_glow(Vector2 p,double radius,Color color,double strength,double fade=1,double light_strength=1);
    void reference_glow_line(Vector2 a,Vector2 b,double radius,Color color,double strength,double fade=1,double light_strength=1);
    bool color_used_=false,light_used_=false;
    std::vector<float> density_;
    void reference_dot(double x,double y,Color c,double alpha);
    void reference_add(int x,int y,Color c,double strength);
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
    void begin_painter(Object *painter,double world_scale,Vector2 camera,bool colors,bool lights);
    PackedByteArray take_colors();
    PackedByteArray take_lights();
    bool has_color() const {return color_used_;}
    bool has_light() const {return light_used_;}
    void nova_field(PackedByteArray alpha,PackedFloat32Array emission,Dictionary state,bool front);
    void reference_beam(Vector2 a,Vector2 b,PackedColorArray palette,Dictionary settings);
    void corona_selection(Vector2 from,Vector2 to,double charge,double radius,double intensity,PackedColorArray palette,double clock);
    void corona_trail(Vector2 center,Vector2 direction,double trail,double age,double clock,double seed_angle,PackedColorArray palette);
    int ruler_beam(Vector2 a,Vector2 b,double width,double time,Color color,double alpha,double fade,double light_strength);
    int ruler_rail(Vector2 a,Vector2 b,Dictionary options,double fade,double light_strength);
    int auriga_trail(PackedVector2Array points,PackedFloat64Array strengths,double width,PackedColorArray palette,double clock,double fade,double light_strength);
    int lynx_scratch(Vector2 origin,double angle,double side,double size,double span,double cut,PackedColorArray palette,Dictionary settings,double fade,double light_strength);
    int dolphin_band(Vector2 center,double radius,double a0,double a1,double width,PackedColorArray palette,double alpha,double dissolve,double fade);
    int dolphin_arc(Vector2 center,double radius,double a0,double a1,Color color,double alpha,double fade);
    int canvas_glow(Vector2 center,double radius,Color color,double strength,double fade,double light_strength);
    int corona_vortex(PackedFloat64Array owners,PackedColorArray palette,double fade);
    int density_field(PackedVector2Array points,PackedFloat64Array radii,PackedByteArray layers,Vector2i origin,int width,int height,Dictionary settings,PackedColorArray palette,double fade,double light_strength);
    int sweep_wake(PackedVector2Array tails,PackedVector2Array roots,PackedFloat64Array ages,PackedFloat32Array reach,PackedFloat32Array fine,PackedColorArray palette,double time,double fade);
    PackedFloat32Array phoenix_stamp_scorch(PackedFloat32Array field,int size,int radius,Array particles);
    int phoenix_scorch(PackedFloat32Array field,int size,int radius,double age,PackedColorArray palette,Dictionary settings);
    int aquila_cracks(Array paths,Vector2 center,double heat,PackedColorArray colors,double fade);
    int aquila_wake(Array history,double clock,double strength,PackedColorArray colors,double fade,double light_strength);
    int lightning_ink(Array paths,double strength,PackedColorArray colors,double scale,bool thin,double glow_strength,double fade,double light_strength);
    int canvas_glow_line(Vector2 a,Vector2 b,double radius,Color color,double strength,double fade,double light_strength);
    int canvas_glow_ring(Vector2 center,double radius,double width,Color color,double strength,double fade,double light_strength);
    int canvas_circle(double x,double y,double radius,Color color,double alpha,double fade,bool blended);
    int canvas_beam(double x0,double y0,double x1,double y1,double width,Color color,double alpha,double fade);
    int canvas_flame_blade(Dictionary shape,PackedColorArray palette,Array layers,double fade);
    int draco_dark_fall(Vector2 center,double age,double warning,double radius,double clock,PackedColorArray palette,double fade);
    int canis_pixels(PackedInt32Array pixels,Vector2 origin,double cell,PackedColorArray palette,double fade,double light_strength);
    int canis_hound_trails(Array trails,double clock,PackedColorArray palette,double fade,double light_strength);
    int monoceros_burns(Array burns,double clock,double radius,PackedColorArray palette,double fade);
    int monoceros_crescent(Array points,double head,double tail,double width,PackedColorArray ramp,double age,double radius_scale,double fade,double light_strength);
    void dim(double amount,double flash);
    void breath(PackedVector2Array fan,double elapsed,double active,double axis,double sweep,double half_angle,double reach,double fan_angle);
    void light_mask_reset();
    void light_mask(Vector2 mouth,double pull,Vector2 head,double head_reach,double axis,double sweep,double half_angle,double reach,PackedVector2Array rocks,double radius,double strength);
    void exhale(Vector2 at,double angle,double reach,double width,double beam_age,double extend,double life,double time);
    void comet(Vector2 pos,double angle,double age,double speed,double radius,double tail,double shine,double seed,bool with_star);
    void dark_shot(Vector2 pos,double angle,double age,double seed);
    void tornado(Vector2 center,double radius,double fade,double grow,double t);
    void wind_band(Vector2 mouth,double angle,double length,double elapsed,double active);
    void wind_blade(Vector2 center,double angle,double age,double life,double size,double side,double seed);
    void rock_comet(Vector2 head,double angle,double speed,double age,double radius,double seed,double pace);
    void sweep_band(PackedVector2Array path,double start,double rel,double active,double radius,Color color);
    void bolt_bar(Vector2 tail,double angle,double age,double life,double speed,double length,double width,Color color,double time);
};
}
