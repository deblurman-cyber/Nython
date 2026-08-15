// platform_compat.hpp  — Nython cross-platform shim
// Covers: Windows (MSVC / MinGW / CodeBlocks), Linux, macOS.
// Safe for multiple inclusion (pragma once) and multiple translation units.
// ─────────────────────────────────────────────────────────────────────────────
#pragma once

#include <string>
#include <sstream>
#include <iomanip>
#include <vector>
#include <fstream>
#include <cstdint>
#include <cstring>
#include <algorithm>

// ═════════════════════════════════════════════════════════════════════════════
// WINDOWS
// ═════════════════════════════════════════════════════════════════════════════
#ifdef _WIN32
// _WIN32_WINNT must be set BEFORE winsock2.h / ws2tcpip.h.
// 0x0600 = Vista+: required for inet_pton, GetAddrInfo, etc.
#  ifndef _WIN32_WINNT
#    define _WIN32_WINNT 0x0600
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
// SDL3 also sets SDL_MAIN_HANDLED — make sure we don't redefine it
#  ifndef SDL_MAIN_HANDLED
#    define SDL_MAIN_HANDLED
#  endif
#  include <winsock2.h>
#  include <ws2tcpip.h>
#  include <windows.h>
#  include <io.h>
#  include <direct.h>
#  include <process.h>
#  include <sys/stat.h>
#  include <sys/types.h>
#  ifdef _MSC_VER
#    pragma comment(lib, "ws2_32.lib")
#    define _CRT_SECURE_NO_WARNINGS
#  endif

// POSIX name aliases
#  ifndef popen
#    define popen    _popen
#  endif
#  ifndef pclose
#    define pclose   _pclose
#  endif
#  ifndef getcwd
#    define getcwd   _getcwd
#  endif
#  ifndef chdir
#    define chdir    _chdir
#  endif
// map mkdir(path,mode) -> _mkdir(path)  (Windows ignores mode)
#  ifdef mkdir
#    undef mkdir
#  endif
#  define mkdir(p,m) _mkdir(p)
#  ifndef setenv
#    define setenv(k,v,o) _putenv_s((k),(v))
#  endif
#  ifndef unsetenv
#    define unsetenv(k)   _putenv_s((k),"")
#  endif
#  ifndef strncasecmp
#    define strncasecmp   _strnicmp
#  endif
#  ifndef strcasecmp
#    define strcasecmp    _stricmp
#  endif
#  ifndef fileno
#    define fileno        _fileno
#  endif
#  ifndef isatty
#    define isatty        _isatty
#  endif

// Missing types (MSVC only — MinGW provides these via sys/types.h)
#  ifdef _MSC_VER
#    ifndef ssize_t
       typedef SSIZE_T ssize_t;
#    endif
#    ifndef mode_t
       typedef unsigned short mode_t;
#    endif
#    ifndef pid_t
       typedef int pid_t;
#    endif
#  endif
#  ifndef socklen_t
     typedef int socklen_t;
#  endif

// stat macros missing on MSVC
#  ifndef S_ISREG
#    define S_ISREG(m)  (((m) & _S_IFMT) == _S_IFREG)
#  endif
#  ifndef S_ISDIR
#    define S_ISDIR(m)  (((m) & _S_IFMT) == _S_IFDIR)
#  endif
#  ifndef S_ISLNK
#    define S_ISLNK(m)  (0)
#  endif

// Socket helpers
static inline int ny_close_socket(SOCKET s) { return closesocket(s); }
#  define NY_SOCKET_T       SOCKET
#  define NY_INVALID_SOCKET INVALID_SOCKET

#  ifndef MSG_NOSIGNAL
#    define MSG_NOSIGNAL 0
#  endif
#  ifndef SHUT_RD
#    define SHUT_RD   SD_RECEIVE
#    define SHUT_WR   SD_SEND
#    define SHUT_RDWR SD_BOTH
#  endif

// Winsock auto-init via static local (one init per process, thread-safe C++11)
namespace ny_platform {
    inline void ensure_winsock() {
        static struct _WsGuard {
            _WsGuard()  { WSADATA wd; WSAStartup(MAKEWORD(2,2), &wd); }
            ~_WsGuard() { WSACleanup(); }
        } _g;
    }
}

// dirent emulation
#  ifndef DT_REG
#    define DT_REG      8
#    define DT_DIR      4
#    define DT_UNKNOWN  0
#  endif
struct dirent {
    char          d_name[MAX_PATH];
    unsigned char d_type;
};
struct DIR {
    HANDLE           hFind;
    WIN32_FIND_DATAA findData;
    bool             first;
    dirent           entry;
};
static inline DIR* opendir(const char* path) {
    std::string pat(path);
    if (!pat.empty() && pat.back() != '\\' && pat.back() != '/') pat += '\\';
    pat += '*';
    DIR* d = new DIR();
    d->hFind = FindFirstFileA(pat.c_str(), &d->findData);
    if (d->hFind == INVALID_HANDLE_VALUE) { delete d; return nullptr; }
    d->first = true;
    return d;
}
static inline struct dirent* readdir(DIR* d) {
    if (!d) return nullptr;
    if (d->first) { d->first = false; }
    else if (!FindNextFileA(d->hFind, &d->findData)) return nullptr;
    strncpy(d->entry.d_name, d->findData.cFileName, MAX_PATH - 1);
    d->entry.d_name[MAX_PATH - 1] = '\0';
    d->entry.d_type =
        (d->findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? DT_DIR : DT_REG;
    return &d->entry;
}
static inline int closedir(DIR* d) {
    if (d) { if (d->hFind != INVALID_HANDLE_VALUE) FindClose(d->hFind); delete d; }
    return 0;
}

// realpath emulation
static inline char* ny_realpath(const char* path, char* resolved) {
    return _fullpath(resolved, path, 4096);
}

#  define NY_PATH_SEP     '\\'
#  define NY_PATH_SEP_STR "\\"

// ═════════════════════════════════════════════════════════════════════════════
// POSIX (Linux / macOS / FreeBSD)
// ═════════════════════════════════════════════════════════════════════════════
#else  // !_WIN32

#  include <sys/socket.h>
#  include <sys/stat.h>
#  include <sys/types.h>
#  include <netinet/in.h>
#  include <netinet/tcp.h>
#  include <arpa/inet.h>
#  include <netdb.h>
#  include <unistd.h>
#  include <dirent.h>
#  include <fcntl.h>

static inline int ny_close_socket(int fd) { return close(fd); }
#  define NY_SOCKET_T       int
#  define NY_INVALID_SOCKET (-1)
#  define NY_PATH_SEP       '/'
#  define NY_PATH_SEP_STR   "/"

namespace ny_platform {
    inline void ensure_winsock() {}   // no-op on POSIX
}
static inline char* ny_realpath(const char* path, char* resolved) {
    return realpath(path, resolved);
}

#endif  // _WIN32

// ═════════════════════════════════════════════════════════════════════════════
// NY_MKDIR macro — portable mkdir with mode (mode ignored on Windows)
// ═════════════════════════════════════════════════════════════════════════════
#ifndef NY_MKDIR
#  ifdef _WIN32
#    define NY_MKDIR(p, m)  _mkdir(p)
#  else
#    define NY_MKDIR(p, m)  ::mkdir((p),(m))
#  endif
#endif

// SO_REUSEPORT guard
#ifndef SO_REUSEPORT
#  ifdef __linux__
#    define SO_REUSEPORT 15
#  else
#    define SO_REUSEPORT SO_REUSEADDR
#  endif
#endif

// ═════════════════════════════════════════════════════════════════════════════
// Pure-C++ SHA-256  (no shell, no OpenSSL)
// ═════════════════════════════════════════════════════════════════════════════
namespace ny_crypto {
    inline std::string sha256(const std::string& input) {
        static const uint32_t K[64] = {
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,
            0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,
            0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,
            0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,
            0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,
            0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,
            0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,
            0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,
            0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        };
        auto rot = [](uint32_t x, int n) -> uint32_t {
            return (x >> n) | (x << (32 - n));
        };
        uint32_t h[8] = {
            0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
            0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
        };
        std::string msg = input;
        uint64_t orig_len = (uint64_t)msg.size() * 8;
        msg += '\x80';
        while (msg.size() % 64 != 56) msg += '\x00';
        for (int i = 7; i >= 0; --i) msg += (char)((orig_len >> (i * 8)) & 0xff);
        for (size_t chunk = 0; chunk < msg.size(); chunk += 64) {
            uint32_t w[64];
            for (int i = 0; i < 16; i++)
                w[i] = ((uint8_t)msg[chunk+i*4]   << 24) |
                       ((uint8_t)msg[chunk+i*4+1] << 16) |
                       ((uint8_t)msg[chunk+i*4+2] <<  8) |
                        (uint8_t)msg[chunk+i*4+3];
            for (int i = 16; i < 64; i++) {
                uint32_t s0 = rot(w[i-15],7)^rot(w[i-15],18)^(w[i-15]>>3);
                uint32_t s1 = rot(w[i-2],17)^rot(w[i-2],19)^(w[i-2]>>10);
                w[i] = w[i-16]+s0+w[i-7]+s1;
            }
            uint32_t a=h[0],b=h[1],c=h[2],d=h[3],
                     e=h[4],f=h[5],g=h[6],hh=h[7];
            for (int i = 0; i < 64; i++) {
                uint32_t S1  = rot(e,6)^rot(e,11)^rot(e,25);
                uint32_t ch  = (e&f)^(~e&g);
                uint32_t t1  = hh+S1+ch+K[i]+w[i];
                uint32_t S0  = rot(a,2)^rot(a,13)^rot(a,22);
                uint32_t maj = (a&b)^(a&c)^(b&c);
                uint32_t t2  = S0+maj;
                hh=g; g=f; f=e; e=d+t1; d=c; c=b; b=a; a=t1+t2;
            }
            h[0]+=a;h[1]+=b;h[2]+=c;h[3]+=d;
            h[4]+=e;h[5]+=f;h[6]+=g;h[7]+=hh;
        }
        std::ostringstream oss;
        for (int i = 0; i < 8; i++)
            oss << std::hex << std::setw(8) << std::setfill('0') << h[i];
        return oss.str();
    }

    inline std::string md5(const std::string& input) {
        static const uint32_t T[64] = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,
            0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,
            0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,
            0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,
            0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
            0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,
            0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,
            0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
            0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        };
        static const int S[64] = {
            7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
            5, 9,14,20,5, 9,14,20,5, 9,14,20,5, 9,14,20,
            4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
            6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21
        };
        auto rotl = [](uint32_t x, int n) -> uint32_t {
            return (x << n) | (x >> (32 - n));
        };
        std::string msg = input;
        uint64_t orig_bits = (uint64_t)msg.size() * 8;
        msg += '\x80';
        while (msg.size() % 64 != 56) msg += '\x00';
        for (int i = 0; i < 8; i++) msg += (char)((orig_bits >> (i * 8)) & 0xff);
        uint32_t a0=0x67452301,b0=0xefcdab89,c0=0x98badcfe,d0=0x10325476;
        for (size_t off = 0; off < msg.size(); off += 64) {
            uint32_t M[16];
            for (int i = 0; i < 16; i++)
                M[i] = ((uint8_t)msg[off+i*4])         |
                       ((uint8_t)msg[off+i*4+1] <<  8) |
                       ((uint8_t)msg[off+i*4+2] << 16) |
                       ((uint8_t)msg[off+i*4+3] << 24);
            uint32_t A=a0,B=b0,C=c0,D=d0;
            for (int i = 0; i < 64; i++) {
                uint32_t F; uint32_t g;
                if      (i < 16) { F=(B&C)|(~B&D); g=(uint32_t)i; }
                else if (i < 32) { F=(D&B)|(~D&C); g=(uint32_t)(5*i+1)%16; }
                else if (i < 48) { F=B^C^D;        g=(uint32_t)(3*i+5)%16; }
                else             { F=C^(B|~D);      g=(uint32_t)(7*i)%16; }
                F += A+T[i]+M[g];
                A=D; D=C; C=B; B=B+rotl(F,S[i]);
            }
            a0+=A; b0+=B; c0+=C; d0+=D;
        }
        std::ostringstream oss;
        auto le=[&](uint32_t v){
            oss<<std::hex
               <<std::setw(2)<<std::setfill('0')<<(v&0xff)
               <<std::setw(2)<<std::setfill('0')<<((v>>8)&0xff)
               <<std::setw(2)<<std::setfill('0')<<((v>>16)&0xff)
               <<std::setw(2)<<std::setfill('0')<<((v>>24)&0xff);
        };
        le(a0); le(b0); le(c0); le(d0);
        return oss.str();
    }
} // namespace ny_crypto

// ═════════════════════════════════════════════════════════════════════════════
// Pure-C++ filesystem helpers  (no shell commands)
// ═════════════════════════════════════════════════════════════════════════════
namespace ny_fs {
    inline std::vector<std::string> listdir(const std::string& path) {
        std::vector<std::string> out;
        DIR* d = opendir(path.c_str());
        if (!d) return out;
        struct dirent* e;
        while ((e = readdir(d)) != nullptr) {
            std::string n = e->d_name;
            if (n != "." && n != "..") out.push_back(n);
        }
        closedir(d);
        return out;
    }
    inline bool exists(const std::string& p) {
        struct stat st{};
        return stat(p.c_str(), &st) == 0;
    }
    inline bool mkdirs(const std::string& path) {
        if (path.empty() || exists(path)) return exists(path);
        if (NY_MKDIR(path.c_str(), 0755) == 0) return true;
        // Walk component by component
        std::string cur;
        for (size_t i = 0; i < path.size(); ++i) {
            char c = path[i];
            if ((c == '/' || c == '\\') && !cur.empty()) {
                struct stat st{};
                if (stat(cur.c_str(), &st) != 0) NY_MKDIR(cur.c_str(), 0755);
            }
            cur += c;
        }
        if (!cur.empty()) { struct stat st{}; if (stat(cur.c_str(),&st)!=0) NY_MKDIR(cur.c_str(),0755); }
        return exists(path);
    }
    // Cross-platform path join
    inline std::string join(const std::string& a, const std::string& b) {
        if (a.empty()) return b;
        char last = a.back();
        if (last == '/' || last == '\\') return a + b;
        return a + std::string(1, NY_PATH_SEP) + b;
    }
} // namespace ny_fs

// ═════════════════════════════════════════════════════════════════════════════
// Pure-C++ HTTP GET / POST  (plain sockets; HTTPS returns "" gracefully)
// ═════════════════════════════════════════════════════════════════════════════
namespace ny_http {
    namespace _d {
        inline bool parse(const std::string& url,
                          std::string& host, int& port,
                          std::string& path, bool& https) {
            https = url.substr(0, 8) == "https://";
            size_t skip = https ? 8 : 7;
            if (url.size() <= skip) return false;
            std::string rest = url.substr(skip);
            size_t sl = rest.find('/');
            host = (sl != std::string::npos) ? rest.substr(0, sl) : rest;
            path = (sl != std::string::npos) ? rest.substr(sl)    : "/";
            size_t co = host.rfind(':');
            if (co != std::string::npos) {
                try { port = std::stoi(host.substr(co+1)); } catch (...) {}
                host = host.substr(0, co);
            } else { port = https ? 443 : 80; }
            return true;
        }
        inline std::string body(const std::string& r) {
            auto p = r.find("\r\n\r\n");
            return (p != std::string::npos) ? r.substr(p+4) : r;
        }
    }
    inline std::string get(const std::string& url) {
        ny_platform::ensure_winsock();
        std::string host, path; int port = 80; bool https = false;
        if (!_d::parse(url, host, port, path, https) || https) return "";
        struct addrinfo hints{}, *res = nullptr;
        hints.ai_family = AF_UNSPEC; hints.ai_socktype = SOCK_STREAM;
        if (getaddrinfo(host.c_str(), std::to_string(port).c_str(), &hints, &res) != 0) return "";
        NY_SOCKET_T s = ::socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        if (s == NY_INVALID_SOCKET) { freeaddrinfo(res); return ""; }
        if (::connect(s, res->ai_addr, (socklen_t)res->ai_addrlen) != 0) {
            ny_close_socket(s); freeaddrinfo(res); return ""; }
        freeaddrinfo(res);
        std::string req = "GET "+path+" HTTP/1.0\r\nHost: "+host+"\r\nConnection: close\r\n\r\n";
        ::send(s, req.c_str(), (int)req.size(), 0);
        std::string resp; char buf[4096]; int n;
        while ((n=(int)::recv(s,buf,sizeof(buf)-1,0))>0){buf[n]=0;resp+=buf;}
        ny_close_socket(s);
        return _d::body(resp);
    }
    inline std::string post(const std::string& url, const std::string& body,
                            const std::string& ct = "application/json") {
        ny_platform::ensure_winsock();
        std::string host, path; int port = 80; bool https = false;
        if (!_d::parse(url, host, port, path, https) || https) return "";
        struct addrinfo hints{}, *res = nullptr;
        hints.ai_family = AF_UNSPEC; hints.ai_socktype = SOCK_STREAM;
        if (getaddrinfo(host.c_str(), std::to_string(port).c_str(), &hints, &res) != 0) return "";
        NY_SOCKET_T s = ::socket(res->ai_family, res->ai_socktype, res->ai_protocol);
        if (s == NY_INVALID_SOCKET) { freeaddrinfo(res); return ""; }
        if (::connect(s, res->ai_addr, (socklen_t)res->ai_addrlen) != 0) {
            ny_close_socket(s); freeaddrinfo(res); return ""; }
        freeaddrinfo(res);
        std::string req = "POST "+path+" HTTP/1.0\r\nHost: "+host+
            "\r\nContent-Type: "+ct+"\r\nContent-Length: "+std::to_string(body.size())+
            "\r\nConnection: close\r\n\r\n"+body;
        ::send(s, req.c_str(), (int)req.size(), 0);
        std::string resp; char buf2[4096]; int n2;
        while ((n2=(int)::recv(s,buf2,sizeof(buf2)-1,0))>0){buf2[n2]=0;resp+=buf2;}
        ny_close_socket(s);
        return _d::body(resp);
    }
} // namespace ny_http

// ═════════════════════════════════════════════════════════════════════════════
// Portable inet_pton / inet_ntop
//
// On Windows, inet_pton is only declared in ws2tcpip.h when
// _WIN32_WINNT >= 0x0600 AND the MinGW version ships that declaration.
// Some MinGW-w64 builds omit it regardless of the flag.
//
// We provide our own pure-C++ implementation that:
//   • Has zero dependency on any socket header or OS version
//   • Works identically on Windows (all versions), Linux, macOS, FreeBSD
//   • Is placed in namespace ny_net so it never clashes with system versions
//   • Can be called via the ny_inet_pton / ny_inet_ntop macros below
// ═════════════════════════════════════════════════════════════════════════════
namespace ny_net {

    // inet_pton: convert a presentation-format address string to binary.
    // Supports AF_INET (IPv4) and AF_INET6 (IPv6).
    // Returns:  1 on success, 0 if src is not a valid address, -1 for bad af.
    inline int inet_pton(int af, const char* src, void* dst) {
        if (!src || !dst) return -1;

        if (af == AF_INET) {
            // ── IPv4 ───────────────────────────────────────────────────────
            uint8_t* out = static_cast<uint8_t*>(dst);
            unsigned int octet = 0;
            int dot = 0;
            bool any = false;
            const char* p = src;
            while (true) {
                char c = *p++;
                if (c >= '0' && c <= '9') {
                    octet = octet * 10 + (unsigned)(c - '0');
                    if (octet > 255) return 0;
                    any = true;
                } else if (c == '.' || c == '\0') {
                    if (!any) return 0;
                    out[dot++] = (uint8_t)octet;
                    octet = 0;
                    any = false;
                    if (c == '\0') break;
                } else {
                    return 0;
                }
            }
            return (dot == 4) ? 1 : 0;
        }

        if (af == AF_INET6) {
            // ── IPv6 ───────────────────────────────────────────────────────
            // Full parser: handles ::, mixed IPv4 tail, and zone IDs (%...).
            uint16_t words[8] = {};
            int w = 0;                  // current word index (left side)
            int dc = -1;                // index of "::" double-colon (-1 = none)
            const char* p = src;

            // Strip zone ID if present
            std::string s(src);
            auto pct = s.find('%');
            if (pct != std::string::npos) s.resize(pct);
            p = s.c_str();

            if (*p == ':') {
                if (*++p != ':') return 0;
                dc = 0; p++;
            }

            while (*p && w < 8) {
                if (*p == ':') {
                    if (dc >= 0) return 0;  // two "::" groups
                    dc = w; p++;
                    continue;
                }
                // Peek: IPv4 tail?
                const char* q = p;
                while (*q && *q != ':' && *q != '%') q++;
                bool is_v4 = false;
                if (w <= 6) {
                    const char* r = p;
                    int dots = 0;
                    while (*r) { if (*r == '.') dots++; r++; }
                    is_v4 = (dots == 3) && (q == r || *q == '\0');
                }
                if (is_v4) {
                    // Recurse into IPv4 parser for the last 32 bits
                    uint8_t v4[4];
                    if (ny_net::inet_pton(AF_INET, p, v4) != 1) return 0;
                    words[w++] = (uint16_t)((v4[0] << 8) | v4[1]);
                    words[w++] = (uint16_t)((v4[2] << 8) | v4[3]);
                    p = q;
                    break;
                }
                // Parse one hex group
                unsigned long val = 0;
                bool any2 = false;
                while ((*p >= '0' && *p <= '9') || (*p >= 'a' && *p <= 'f') || (*p >= 'A' && *p <= 'F')) {
                    unsigned d = (*p >= '0' && *p <= '9') ? (unsigned)(*p - '0') :
                                 (*p >= 'a' && *p <= 'f') ? (unsigned)(*p - 'a' + 10) :
                                                             (unsigned)(*p - 'A' + 10);
                    val = val * 16 + d;
                    if (val > 0xFFFF) return 0;
                    any2 = true; p++;
                }
                if (!any2) return 0;
                words[w++] = (uint16_t)val;
                if (*p == ':') p++;
            }
            if (*p != '\0' && *p != '%') return 0;

            // Expand "::"
            if (dc >= 0) {
                int fill = 8 - w;
                if (fill < 1) return 0;
                // Shift right side
                for (int i = w - 1; i >= dc; i--)
                    words[i + fill] = words[i];
                for (int i = dc; i < dc + fill; i++)
                    words[i] = 0;
            } else if (w != 8) {
                return 0;
            }

            // Write big-endian output
            uint8_t* out6 = static_cast<uint8_t*>(dst);
            for (int i = 0; i < 8; i++) {
                out6[i * 2]     = (uint8_t)(words[i] >> 8);
                out6[i * 2 + 1] = (uint8_t)(words[i] & 0xFF);
            }
            return 1;
        }

        return -1; // unsupported address family
    }

    // inet_ntop: convert binary address to presentation string.
    // Returns dst on success, nullptr on error.
    inline const char* inet_ntop(int af, const void* src, char* dst, unsigned long size) {
        if (!src || !dst || size == 0) return nullptr;

        if (af == AF_INET) {
            const uint8_t* b = static_cast<const uint8_t*>(src);
            int n = std::snprintf(dst, size, "%u.%u.%u.%u",
                                  (unsigned)b[0], (unsigned)b[1],
                                  (unsigned)b[2], (unsigned)b[3]);
            return (n > 0 && (unsigned)n < size) ? dst : nullptr;
        }

        if (af == AF_INET6) {
            const uint8_t* b = static_cast<const uint8_t*>(src);
            uint16_t words[8];
            for (int i = 0; i < 8; i++)
                words[i] = (uint16_t)((b[i*2] << 8) | b[i*2+1]);

            // Find longest run of zeros for "::" compression
            int best_start = -1, best_len = 0, cur_start = -1, cur_len = 0;
            for (int i = 0; i < 8; i++) {
                if (words[i] == 0) {
                    if (cur_start < 0) { cur_start = i; cur_len = 1; }
                    else cur_len++;
                    if (cur_len > best_len) { best_len = cur_len; best_start = cur_start; }
                } else { cur_start = -1; cur_len = 0; }
            }
            if (best_len < 2) best_start = -1; // only compress runs >=2

            char buf[48] = {};
            char* out = buf;
            for (int i = 0; i < 8; ) {
                if (i == best_start) {
                    *out++ = ':'; *out++ = ':';
                    i += best_len;
                    continue;
                }
                if (i > 0 && i != best_start + best_len)
                    *out++ = ':';
                int n = std::sprintf(out, "%x", (unsigned)words[i]);
                out += n; i++;
            }
            *out = '\0';
            size_t len = strlen(buf);
            if (len >= size) return nullptr;
            memcpy(dst, buf, len + 1);
            return dst;
        }

        return nullptr;
    }

} // namespace ny_net

// Convenience macros — use ny_net:: implementations everywhere.
// On any platform. No OS version required.
#ifndef NY_INET_PTON_DEFINED
#  define NY_INET_PTON_DEFINED
#  define ny_inet_pton(af, src, dst)        ny_net::inet_pton((af), (src), (dst))
#  define ny_inet_ntop(af, src, dst, size)  ny_net::inet_ntop((af), (src), (dst), (size))
#endif
