// SDL_net.h stub for MaXtreme GDExtension
// Provides type definitions so networking code compiles.
// Actual networking will be reimplemented in Phase 10 (Godot ENet).
#ifndef MAXTREME_SDL_NET_STUB_H
#define MAXTREME_SDL_NET_STUB_H

#include <cstdint>

// --- Socket types (stubs) ---
struct _TCPsocket_stub {};
using TCPsocket = _TCPsocket_stub*;

struct IPaddress {
    uint32_t host = 0;
    uint16_t port = 0;
};

struct SDLNet_SocketSet_stub {};
using SDLNet_SocketSet = SDLNet_SocketSet_stub*;

// --- SDL_net function stubs ---
inline int SDLNet_Init() { return 0; }
inline void SDLNet_Quit() {}

inline int SDLNet_ResolveHost(IPaddress* address, const char* host, uint16_t port) {
    if (address) { address->host = 0; address->port = port; }
    return 0;
}

inline TCPsocket SDLNet_TCP_Open(IPaddress* ip) { return nullptr; }
inline TCPsocket SDLNet_TCP_Accept(TCPsocket server) { return nullptr; }
inline void SDLNet_TCP_Close(TCPsocket sock) {}
inline int SDLNet_TCP_Send(TCPsocket sock, const void* data, int len) { return 0; }
inline int SDLNet_TCP_Recv(TCPsocket sock, void* data, int maxlen) { return 0; }

inline SDLNet_SocketSet SDLNet_AllocSocketSet(int maxsockets) { return nullptr; }
inline void SDLNet_FreeSocketSet(SDLNet_SocketSet set) {}
inline int SDLNet_TCP_AddSocket(SDLNet_SocketSet set, TCPsocket sock) { return 0; }
inline int SDLNet_TCP_DelSocket(SDLNet_SocketSet set, TCPsocket sock) { return 0; }
inline int SDLNet_CheckSockets(SDLNet_SocketSet set, uint32_t timeout) { return 0; }
inline int SDLNet_SocketReady(TCPsocket sock) { return 0; }

inline IPaddress* SDLNet_TCP_GetPeerAddress(TCPsocket sock) { return nullptr; }

#endif // MAXTREME_SDL_NET_STUB_H
