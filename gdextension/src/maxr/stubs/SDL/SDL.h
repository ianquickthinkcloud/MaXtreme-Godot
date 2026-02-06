// SDL.h stub for MaXtreme GDExtension
// Replaces SDL functions with std:: equivalents
#ifndef MAXTREME_SDL_STUB_H
#define MAXTREME_SDL_STUB_H

#include <cstdint>
#include <chrono>
#include <thread>

// --- SDL types ---
using Uint8 = uint8_t;
using Uint16 = uint16_t;
using Uint32 = uint32_t;
using Uint64 = uint64_t;
using Sint8 = int8_t;
using Sint16 = int16_t;
using Sint32 = int32_t;
using Sint64 = int64_t;
using SDL_TimerID = int;

// --- SDL_GetTicks replacement ---
inline Uint32 SDL_GetTicks() {
    static auto start = std::chrono::steady_clock::now();
    auto now = std::chrono::steady_clock::now();
    return static_cast<Uint32>(
        std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count()
    );
}

// --- SDL Timer callback type ---
using SDL_TimerCallback = Uint32 (*)(Uint32 interval, void* param);

// SDL_AddTimer replacement - starts a std::thread that calls callback periodically
// Returns a fake timer ID > 0
inline SDL_TimerID SDL_AddTimer(Uint32 interval, SDL_TimerCallback callback, void* param) {
    static int next_id = 1;
    int id = next_id++;
    // Note: In the real implementation, the game timer will be reworked.
    // This stub just returns a valid ID so the code compiles.
    return id;
}

inline bool SDL_RemoveTimer(SDL_TimerID id) {
    // Stub - timer management will be reworked for Godot
    return true;
}

// --- SDL_RWops file I/O replacement using C stdio ---
#include <cstdio>

struct SDL_RWops {
    FILE* fp = nullptr;
};

inline SDL_RWops* SDL_RWFromFile(const char* file, const char* mode) {
    FILE* fp = fopen(file, mode);
    if (!fp) return nullptr;
    auto* rw = new SDL_RWops();
    rw->fp = fp;
    return rw;
}

inline size_t SDL_RWread(SDL_RWops* ctx, void* ptr, size_t size, size_t maxnum) {
    if (!ctx || !ctx->fp) return 0;
    return fread(ptr, size, maxnum, ctx->fp);
}

inline Sint64 SDL_RWseek(SDL_RWops* ctx, Sint64 offset, int whence) {
    if (!ctx || !ctx->fp) return -1;
    fseek(ctx->fp, static_cast<long>(offset), whence);
    return ftell(ctx->fp);
}

inline Sint64 SDL_RWtell(SDL_RWops* ctx) {
    if (!ctx || !ctx->fp) return -1;
    return ftell(ctx->fp);
}

inline int SDL_RWclose(SDL_RWops* ctx) {
    if (!ctx) return -1;
    if (ctx->fp) fclose(ctx->fp);
    delete ctx;
    return 0;
}

inline Uint16 SDL_ReadLE16(SDL_RWops* ctx) {
    Uint16 val = 0;
    SDL_RWread(ctx, &val, sizeof(val), 1);
    // Assume little-endian host (most modern systems)
    return val;
}

inline Uint32 SDL_ReadLE32(SDL_RWops* ctx) {
    Uint32 val = 0;
    SDL_RWread(ctx, &val, sizeof(val), 1);
    return val;
}

// --- SDL_Delay ---
inline void SDL_Delay(Uint32 ms) {
    std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

// --- SDL Thread Priority ---
enum SDL_ThreadPriority {
    SDL_THREAD_PRIORITY_LOW,
    SDL_THREAD_PRIORITY_NORMAL,
    SDL_THREAD_PRIORITY_HIGH,
    SDL_THREAD_PRIORITY_TIME_CRITICAL
};

inline int SDL_SetThreadPriority(SDL_ThreadPriority priority) {
    // No-op stub - thread priority not critical for initial compilation
    return 0;
}

#endif // MAXTREME_SDL_STUB_H
