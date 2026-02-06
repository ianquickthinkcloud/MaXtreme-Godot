// SDL_thread.h stub for MaXtreme GDExtension
// Replaces SDL thread functions with std:: equivalents
#ifndef MAXTREME_SDL_THREAD_STUB_H
#define MAXTREME_SDL_THREAD_STUB_H

#include <thread>
#include <cstdint>
#include <functional>

// SDL_ThreadID replacement
using SDL_threadID = uint64_t;

inline SDL_threadID SDL_ThreadID() {
    auto id = std::this_thread::get_id();
    return static_cast<SDL_threadID>(std::hash<std::thread::id>{}(id));
}

// SDL_Thread stub - wraps std::thread
struct SDL_Thread {
    std::thread thread;
};

using SDL_ThreadFunction = int (*)(void*);

inline SDL_Thread* SDL_CreateThread(SDL_ThreadFunction fn, const char* name, void* data) {
    auto* t = new SDL_Thread();
    t->thread = std::thread([fn, data]() { fn(data); });
    return t;
}

inline void SDL_WaitThread(SDL_Thread* thread, int* status) {
    if (thread && thread->thread.joinable()) {
        thread->thread.join();
    }
    if (status) *status = 0;
    delete thread;
}

inline void SDL_DetachThread(SDL_Thread* thread) {
    if (thread && thread->thread.joinable()) {
        thread->thread.detach();
    }
    delete thread;
}

inline SDL_threadID SDL_GetThreadID(SDL_Thread* thread) {
    if (!thread) return 0;
    auto id = thread->thread.get_id();
    return static_cast<SDL_threadID>(std::hash<std::thread::id>{}(id));
}

#endif // MAXTREME_SDL_THREAD_STUB_H
