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
// Callback returns the new interval for the next invocation.
// If it returns 0, the timer is cancelled (one-shot).
using SDL_TimerCallback = Uint32 (*)(Uint32 interval, void* param);

#include <map>
#include <mutex>
#include <atomic>

/// Internal state for an active SDL timer.
struct _SDLTimerState {
    std::thread thread;
    std::atomic<bool> active{true};
};

/// Global registry of active timers (protected by mutex).
struct _SDLTimerRegistry {
    std::mutex mutex;
    std::map<SDL_TimerID, std::unique_ptr<_SDLTimerState>> timers;
    int next_id = 1;

    static _SDLTimerRegistry& instance() {
        static _SDLTimerRegistry reg;
        return reg;
    }
};

/// SDL_AddTimer replacement -- spawns a detached std::thread that calls the
/// callback at the requested interval. If the callback returns 0, the timer
/// stops (one-shot). If it returns a positive value, the timer repeats with
/// that new interval.
inline SDL_TimerID SDL_AddTimer(Uint32 interval, SDL_TimerCallback callback, void* param) {
    auto& reg = _SDLTimerRegistry::instance();
    std::lock_guard<std::mutex> lock(reg.mutex);

    int id = reg.next_id++;
    auto state = std::make_unique<_SDLTimerState>();
    auto* state_ptr = state.get();

    state->thread = std::thread([state_ptr, interval, callback, param]() {
        Uint32 current_interval = interval;
        while (state_ptr->active.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(current_interval));
            if (!state_ptr->active.load()) break;

            Uint32 next_interval = callback(current_interval, param);
            if (next_interval == 0) {
                // One-shot timer: callback returned 0, stop
                state_ptr->active.store(false);
                break;
            }
            current_interval = next_interval;
        }
    });
    state->thread.detach();

    reg.timers[id] = std::move(state);
    return id;
}

/// SDL_RemoveTimer -- signals the timer thread to stop.
inline bool SDL_RemoveTimer(SDL_TimerID id) {
    auto& reg = _SDLTimerRegistry::instance();
    std::lock_guard<std::mutex> lock(reg.mutex);

    auto it = reg.timers.find(id);
    if (it == reg.timers.end()) return false;

    it->second->active.store(false);
    // Thread is detached, will exit on its own
    reg.timers.erase(it);
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
