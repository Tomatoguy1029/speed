#pragma once
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <string>
namespace speed {
// 長さを確認した後にだけ読み込み、ホストのバイト順には依存しない。
class BinaryReader {
    const uint8_t *data;
    uint64_t length, cursor = 0;
public:
    BinaryReader(const uint8_t *bytes, uint64_t size): data(bytes), length(size) {}
    uint64_t remaining() const { return length - cursor; }
    bool read_u64(uint64_t &out, unsigned width = 8) {
        if (remaining() < width) return false;
        out = 0;
        for (unsigned i = 0; i < width; ++i) out |= uint64_t(data[cursor++]) << (8 * i);
        return true;
    }
    bool read_u32(uint32_t &out) { uint64_t x; if (!read_u64(x,4)) return false; out=uint32_t(x); return true; }
    bool read_u8(uint8_t &out) { uint64_t x; if (!read_u64(x,1)) return false; out=uint8_t(x); return true; }
    bool read_i64(int64_t &out) { uint64_t x; if (!read_u64(x)) return false; std::memcpy(&out,&x,8); return true; }
    bool read_f64(double &out) { uint64_t x; if (!read_u64(x)) return false; std::memcpy(&out,&x,8); return std::isfinite(out); }
    bool read_f32(float &out) { uint32_t x; if (!read_u32(x)) return false; std::memcpy(&out,&x,4); return std::isfinite(out); }
    bool read_bool(bool &out) { uint8_t x; if (!read_u8(x) || x>1) return false; out=x; return true; }
    bool read_string(std::string &out) {
        uint32_t size; if (!read_u32(size) || size>remaining()) return false;
        auto decoded=godot::String::utf8(reinterpret_cast<const char *>(data+cursor),size);
        const auto encoded=decoded.utf8();
        if (uint64_t(encoded.length()) != size || (size && std::memcmp(encoded.get_data(),data+cursor,size))) return false;
        out.assign(reinterpret_cast<const char *>(data+cursor),size); cursor+=size; return true;
    }
};
}
