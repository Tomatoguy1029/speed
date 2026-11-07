#pragma once
#include <memory>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace godot {
// 継続演出の星・花火・紙吹雪を論理画素の層へ描く。pixelfx 0.3.0（MIT, Patch / Hugo Duprez）の
// Painter・Particles・Lights・firework-burst・confetti を同じ式で移したもの。層は composite(frame, out, null) と同じRGBA8で返す。
class SpeedPixelFx : public RefCounted {
    GDCLASS(SpeedPixelFx, RefCounted)
public:
    struct Impl;
private:
    std::unique_ptr<Impl> impl_;
protected:
    static void _bind_methods();
public:
    SpeedPixelFx();
    ~SpeedPixelFx();
    void configure(int width,int height,int seed,PackedColorArray sparks);
    void clear();
    void add_firework(Vector2 at,int seed,PackedColorArray palette,PackedColorArray core);
    void add_confetti(Vector2 at,int seed,bool flip,PackedColorArray palette);
    void spawn(int kind,Vector2 at,Vector2 velocity,double life,Color color,double size);
    void update(double dt);
    bool is_empty() const;
    PackedByteArray render();
};
}
