// SDL_endian.h stub for MaXtreme GDExtension
// Replaces SDL byte-swapping with portable C++20 equivalents
#ifndef MAXTREME_SDL_ENDIAN_STUB_H
#define MAXTREME_SDL_ENDIAN_STUB_H

#include <cstdint>
#include <cstring>

// SDL integer type aliases (normally from SDL_stdinc.h)
using Uint8 = uint8_t;
using Uint16 = uint16_t;
using Uint32 = uint32_t;
using Uint64 = uint64_t;
using Sint8 = int8_t;
using Sint16 = int16_t;
using Sint32 = int32_t;
using Sint64 = int64_t;

// Detect endianness
#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#define MAXTREME_BIG_ENDIAN 1
#else
#define MAXTREME_BIG_ENDIAN 0
#endif

// Byte swap functions
inline uint16_t maxtreme_swap16(uint16_t x) {
    return (x >> 8) | (x << 8);
}

inline uint32_t maxtreme_swap32(uint32_t x) {
    return ((x >> 24) & 0xFF) |
           ((x >> 8)  & 0xFF00) |
           ((x << 8)  & 0xFF0000) |
           ((x << 24) & 0xFF000000);
}

inline uint64_t maxtreme_swap64(uint64_t x) {
    return ((x >> 56) & 0xFFULL) |
           ((x >> 40) & 0xFF00ULL) |
           ((x >> 24) & 0xFF0000ULL) |
           ((x >> 8)  & 0xFF000000ULL) |
           ((x << 8)  & 0xFF00000000ULL) |
           ((x << 24) & 0xFF0000000000ULL) |
           ((x << 40) & 0xFF000000000000ULL) |
           ((x << 56) & 0xFF00000000000000ULL);
}

// SDL-compatible macros - convert little-endian to host
#if MAXTREME_BIG_ENDIAN
    #define SDL_SwapLE16(x) maxtreme_swap16(x)
    #define SDL_SwapLE32(x) maxtreme_swap32(x)
    #define SDL_SwapLE64(x) maxtreme_swap64(x)
#else
    // Host is little-endian - no swap needed
    #define SDL_SwapLE16(x) (x)
    #define SDL_SwapLE32(x) (x)
    #define SDL_SwapLE64(x) (x)
#endif

// SDL_ReadLE16/32 equivalents for binary reading
// (used in map loading - will be replaced with std::ifstream later)
inline uint16_t SDL_ReadLE16(void* src) {
    uint16_t val;
    std::memcpy(&val, src, sizeof(val));
    return SDL_SwapLE16(val);
}

inline uint32_t SDL_ReadLE32(void* src) {
    uint32_t val;
    std::memcpy(&val, src, sizeof(val));
    return SDL_SwapLE32(val);
}

#endif // MAXTREME_SDL_ENDIAN_STUB_H
