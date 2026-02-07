// SDL_net.h -- Real POSIX TCP socket implementation for MaXtreme GDExtension.
// Replaces the original SDL_net API used by M.A.X.R.'s cNetwork layer with
// standard BSD sockets. Supports server listen/accept, client connect,
// send/recv, and socket-set polling via select().
#ifndef MAXTREME_SDL_NET_IMPL_H
#define MAXTREME_SDL_NET_IMPL_H

#include <cstdint>
#include <cstring>
#include <vector>
#include <string>
#include <algorithm>

// POSIX / BSD sockets
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

struct IPaddress {
    uint32_t host = 0;  // IPv4 in network byte order
    uint16_t port = 0;  // Port in network byte order
};

/// Internal TCP socket wrapper.
struct _TCPsocket_impl {
    int fd = -1;             // File descriptor
    bool is_server = false;  // True if this is a listening socket
    IPaddress peer_addr{};   // Peer address (for connected sockets)
    bool ready = false;      // Set by CheckSockets, read by SocketReady
};

using TCPsocket = _TCPsocket_impl*;

/// Internal socket set for select()-based polling.
struct SDLNet_SocketSet_impl {
    std::vector<TCPsocket> sockets;
    int max_sockets = 0;
};

using SDLNet_SocketSet = SDLNet_SocketSet_impl*;

// Sentinel values matching original SDL_net
#ifndef INADDR_ANY
#define INADDR_ANY ((uint32_t)0x00000000)
#endif
#ifndef INADDR_NONE
#define INADDR_NONE ((uint32_t)0xFFFFFFFF)
#endif

// ---------------------------------------------------------------------------
// Init / Quit (no-ops for POSIX sockets)
// ---------------------------------------------------------------------------

inline int SDLNet_Init() { return 0; }
inline void SDLNet_Quit() {}

// ---------------------------------------------------------------------------
// Host resolution
// ---------------------------------------------------------------------------

/// Resolve a hostname and port into an IPaddress.
/// If host is nullptr, sets host to INADDR_ANY (for server listen).
inline int SDLNet_ResolveHost(IPaddress* address, const char* host, uint16_t port) {
    if (!address) return -1;

    address->port = htons(port);

    if (host == nullptr) {
        // Server mode: listen on all interfaces
        address->host = INADDR_ANY;
        return 0;
    }

    // Try numeric IP first
    struct in_addr addr;
    if (inet_pton(AF_INET, host, &addr) == 1) {
        address->host = addr.s_addr;
        return 0;
    }

    // DNS lookup
    struct addrinfo hints{};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo* result = nullptr;
    if (getaddrinfo(host, nullptr, &hints, &result) != 0 || result == nullptr) {
        address->host = INADDR_NONE;
        return -1;
    }

    auto* sin = reinterpret_cast<struct sockaddr_in*>(result->ai_addr);
    address->host = sin->sin_addr.s_addr;
    freeaddrinfo(result);
    return 0;
}

// ---------------------------------------------------------------------------
// TCP socket operations
// ---------------------------------------------------------------------------

/// Open a TCP socket. If ip->host == INADDR_ANY, creates a listening server socket.
/// Otherwise, connects to the remote host. Returns nullptr on failure.
inline TCPsocket SDLNet_TCP_Open(IPaddress* ip) {
    if (!ip) return nullptr;

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return nullptr;

    // Allow address reuse (prevents "Address already in use" after restart)
    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // Disable Nagle's algorithm for low-latency game traffic
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

    if (ip->host == INADDR_ANY) {
        // Server: bind and listen
        struct sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = ip->port;

        if (bind(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            close(fd);
            return nullptr;
        }

        if (listen(fd, 16) < 0) {
            close(fd);
            return nullptr;
        }

        auto* sock = new _TCPsocket_impl();
        sock->fd = fd;
        sock->is_server = true;
        sock->peer_addr = *ip;
        return sock;
    } else {
        // Client: connect to remote host
        struct sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = ip->host;
        addr.sin_port = ip->port;

        if (connect(fd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) < 0) {
            close(fd);
            return nullptr;
        }

        auto* sock = new _TCPsocket_impl();
        sock->fd = fd;
        sock->is_server = false;
        sock->peer_addr = *ip;
        return sock;
    }
}

/// Accept an incoming connection on a server socket.
/// Returns nullptr if no connection is pending.
inline TCPsocket SDLNet_TCP_Accept(TCPsocket server) {
    if (!server || server->fd < 0 || !server->is_server) return nullptr;

    struct sockaddr_in client_addr{};
    socklen_t addr_len = sizeof(client_addr);

    int client_fd = accept(server->fd, reinterpret_cast<struct sockaddr*>(&client_addr), &addr_len);
    if (client_fd < 0) return nullptr;

    // Disable Nagle on accepted socket too
    int opt = 1;
    setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

    auto* sock = new _TCPsocket_impl();
    sock->fd = client_fd;
    sock->is_server = false;
    sock->peer_addr.host = client_addr.sin_addr.s_addr;
    sock->peer_addr.port = client_addr.sin_port;
    return sock;
}

/// Close a TCP socket and free its memory.
inline void SDLNet_TCP_Close(TCPsocket sock) {
    if (!sock) return;
    if (sock->fd >= 0) {
        close(sock->fd);
        sock->fd = -1;
    }
    delete sock;
}

/// Send data on a TCP socket. Returns the number of bytes sent,
/// or 0 on error (matches SDL_net semantics where partial send = error).
inline int SDLNet_TCP_Send(TCPsocket sock, const void* data, int len) {
    if (!sock || sock->fd < 0 || !data || len <= 0) return 0;

    int total_sent = 0;
    const auto* buf = static_cast<const unsigned char*>(data);

    while (total_sent < len) {
        ssize_t sent = ::send(sock->fd, buf + total_sent, len - total_sent, MSG_NOSIGNAL);
        if (sent <= 0) {
            // Connection error or closed
            return total_sent; // Partial send = error condition for cNetwork
        }
        total_sent += static_cast<int>(sent);
    }
    return total_sent;
}

/// Receive data from a TCP socket. Returns the number of bytes received,
/// 0 if the connection was closed, or -1 on error.
inline int SDLNet_TCP_Recv(TCPsocket sock, void* data, int maxlen) {
    if (!sock || sock->fd < 0 || !data || maxlen <= 0) return -1;

    ssize_t received = recv(sock->fd, data, maxlen, 0);
    if (received < 0) return -1;
    return static_cast<int>(received);
}

/// Get the peer address of a connected socket.
inline IPaddress* SDLNet_TCP_GetPeerAddress(TCPsocket sock) {
    if (!sock) return nullptr;
    return &sock->peer_addr;
}

// ---------------------------------------------------------------------------
// Socket set (select-based polling)
// ---------------------------------------------------------------------------

/// Allocate a socket set that can hold up to maxsockets sockets.
inline SDLNet_SocketSet SDLNet_AllocSocketSet(int maxsockets) {
    auto* set = new SDLNet_SocketSet_impl();
    set->max_sockets = maxsockets;
    set->sockets.reserve(maxsockets);
    return set;
}

/// Free a socket set.
inline void SDLNet_FreeSocketSet(SDLNet_SocketSet set) {
    delete set;
}

/// Add a TCP socket to a socket set.
inline int SDLNet_TCP_AddSocket(SDLNet_SocketSet set, TCPsocket sock) {
    if (!set || !sock) return -1;
    // Avoid duplicates
    auto it = std::find(set->sockets.begin(), set->sockets.end(), sock);
    if (it == set->sockets.end()) {
        if (static_cast<int>(set->sockets.size()) >= set->max_sockets) return -1;
        set->sockets.push_back(sock);
    }
    return static_cast<int>(set->sockets.size());
}

/// Remove a TCP socket from a socket set.
inline int SDLNet_TCP_DelSocket(SDLNet_SocketSet set, TCPsocket sock) {
    if (!set || !sock) return -1;
    auto it = std::find(set->sockets.begin(), set->sockets.end(), sock);
    if (it != set->sockets.end()) {
        set->sockets.erase(it);
    }
    return static_cast<int>(set->sockets.size());
}

/// Check sockets in the set for activity. timeout is in milliseconds.
/// Returns the number of sockets with activity, 0 on timeout, -1 on error.
/// After this call, use SDLNet_SocketReady() to check individual sockets.
inline int SDLNet_CheckSockets(SDLNet_SocketSet set, uint32_t timeout) {
    if (!set || set->sockets.empty()) return -1;

    // Clear all ready flags first
    for (auto* sock : set->sockets) {
        if (sock) sock->ready = false;
    }

    // Build fd_set
    fd_set read_fds;
    FD_ZERO(&read_fds);
    int max_fd = -1;

    for (auto* sock : set->sockets) {
        if (sock && sock->fd >= 0) {
            FD_SET(sock->fd, &read_fds);
            if (sock->fd > max_fd) max_fd = sock->fd;
        }
    }

    if (max_fd < 0) return -1;

    struct timeval tv;
    tv.tv_sec = static_cast<long>(timeout / 1000);
    tv.tv_usec = static_cast<long>((timeout % 1000) * 1000);

    int result = select(max_fd + 1, &read_fds, nullptr, nullptr, &tv);
    if (result < 0) return -1;
    if (result == 0) return 0;

    // Set ready flags
    int ready_count = 0;
    for (auto* sock : set->sockets) {
        if (sock && sock->fd >= 0 && FD_ISSET(sock->fd, &read_fds)) {
            sock->ready = true;
            ready_count++;
        }
    }

    return ready_count;
}

/// Check if a socket has activity (data available to read, or incoming connection).
/// Must be called after SDLNet_CheckSockets().
inline int SDLNet_SocketReady(TCPsocket sock) {
    if (!sock) return 0;
    return sock->ready ? 1 : 0;
}

#endif // MAXTREME_SDL_NET_IMPL_H
