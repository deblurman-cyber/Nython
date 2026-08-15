#ifndef NYTHON_DEFINITIONS_HPP
#define NYTHON_DEFINITIONS_HPP

// These MUST be defined before ANY header that could pull in windows.h,
// otherwise winsock2.h conflicts with winsock.h on MinGW/MSVC.
#if defined(_WIN32) || defined(_WIN64)
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #ifndef _WINSOCKAPI_
    #define _WINSOCKAPI_
  #endif
#endif
/*=============================================================================
 * Nython — Definitions.hpp (REWRITTEN — zero external dependencies)
 * Platform detection, type aliases, macros, and replacement layers for:
 *   fmt::format/print -> variadic template + ostringstream
 *   utf8::* -> manual UTF-8 encode/decode
 * Copyright (c) 2017-2026 Litet Li Mbeleg Perrin — MIT License
 *=============================================================================*/
#ifndef NYTHON_VERSION
#define NYTHON_VERSION "0.3.0"
#define NYTHON_VERSION_MAJOR 0
#define NYTHON_VERSION_MINOR 3
#define NYTHON_VERSION_PATCH 0
#endif // NYTHON_VERSION

// Platform
#if defined(_WIN64)
  #define OS_WINDOWS 1
  #define OS_WINDOWS64 1
#elif defined(_WIN32)
  #define OS_WINDOWS 1
#elif defined(__APPLE__)
  #define OS_APPLE 1
#elif defined(__ANDROID__)
  #define OS_ANDROID 1
#elif defined(__linux__)
  #define OS_LINUX 1

#endif

#ifdef OS_WINDOWS
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #ifndef NOMINMAX
    #define NOMINMAX
  #endif
  #ifndef _CRT_SECURE_NO_WARNINGS
    #define _CRT_SECURE_NO_WARNINGS 1
  #endif
  #pragma GCC diagnostic push
  #pragma GCC diagnostic ignored "-Wcpp"
  #include <winsock2.h>
  #include <ws2tcpip.h>
  #include <windows.h>
  #pragma GCC diagnostic pop
  #include <io.h>
  #include <fcntl.h>
  #include <direct.h>
#endif

#ifdef __GNUC__
  #pragma GCC diagnostic ignored "-Wunused-variable"
  #pragma GCC diagnostic ignored "-Wunused-parameter"
  #pragma GCC diagnostic ignored "-Wdeprecated-declarations"

#endif

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <cctype>
#include <cerrno>
#include <cassert>
#include <cstdarg>
#include <ctime>
#include <cfloat>
#include <climits>
#include <cwchar>
#include <cwctype>
#include <clocale>
#include <string>
#include <string_view>
#include <vector>
#include <list>
#include <deque>
#include <map>
#include <unordered_map>
#include <set>
#include <unordered_set>
#include <stack>
#include <queue>
#include <memory>
#include <functional>
#include <algorithm>
#include <utility>
#include <initializer_list>
#include <type_traits>
#include <variant>
#include <optional>
#include <any>
#include <tuple>
#include <bitset>
#include <array>
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <regex>
#include <locale>
#include <codecvt>
#include <thread>
#include <mutex>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <future>
#include <numeric>
#include <limits>
#include <random>
#include <complex>
#include <stdexcept>
#include <exception>
#include <typeinfo>
#include <typeindex>
#include <system_error>

#ifndef _WIN32
  #include <unistd.h>
  #include <sys/stat.h>
  #include <sys/types.h>
  #include <sys/time.h>
  #include <dirent.h>
  #include <signal.h>
  #include <termios.h>
  // dlfcn.h (dlopen/dlsym) — Linux/macOS only; not needed for core Nython
  // #include <dlfcn.h>
#else
  #include <sys/stat.h>
  #include <direct.h>
  #include <io.h>
#endif
#ifndef _MSC_VER
  #include <cxxabi.h>

#endif

using i8=int8_t; using i16=int16_t; using i32=int32_t; using i64=int64_t;
using u8=uint8_t; using u16=uint16_t; using u32=uint32_t; using u64=uint64_t;
using f32=float; using f64=double; using f128=long double;
typedef long double ldouble;
using byte=uint8_t;

#ifndef extends
  #define extends : public

#endif
#ifndef DISALLOW_COPY_AND_ASSIGN
#define DISALLOW_COPY_AND_ASSIGN(Cls) Cls(const Cls&)=delete; Cls& operator=(const Cls&)=delete;
#endif // DISALLOW_COPY_AND_ASSIGN
#define IS_NAN(X) ((X)!=(X))
#define IS_INFINITY(X) ((X)&&((X)*0.5==(X)))
#define FLOAT_PRECISION 12
#define SLASHES "/\\"
#define STRING_REMOVE_CHAR(str,ch) str.erase(std::remove(str.begin(),str.end(),ch),str.end())

// Enum generation
template<typename T> std::map<T,std::string> nython_generate_enum_map(std::string s);
#define DECLARE_ENUM_WITH_TYPE(E,T,...) \
  enum class E:T{__VA_ARGS__}; \
  static std::map<T,std::string> E##MapName(nython_generate_enum_map<T>(#__VA_ARGS__)); \
  inline std::ostream& operator<<(std::ostream& os,E v){auto i=E##MapName.find((T)v);if(i!=E##MapName.end())os<<i->second;else os<<"Unknown("<<(T)v<<")";return os;} \
  inline std::string operator~(E v){auto i=E##MapName.find((T)v);return(i!=E##MapName.end())?i->second:"Unknown";} \
  inline size_t operator*(E){return E##MapName.size();}
#define DECLARE_ENUM(E,...) DECLARE_ENUM_WITH_TYPE(E,int32_t,__VA_ARGS__)

template<typename T>
inline std::map<T,std::string> nython_generate_enum_map(std::string s){
  STRING_REMOVE_CHAR(s,' '); STRING_REMOVE_CHAR(s,'(');
  std::map<T,std::string> r; T idx=(T)0;
  std::stringstream ss(s); std::string tok;
  while(std::getline(ss,tok,',')){
    if(tok.empty()) continue;
    auto eq=tok.find('=');
    if(eq==std::string::npos){r[idx]=tok;}
    else{r[idx]=tok.substr(0,eq);auto vs=tok.substr(eq+1);auto p=vs.find(')');if(p!=std::string::npos)vs=vs.substr(0,p);idx=(T)std::stoll(vs,nullptr,0);r[idx]=tok.substr(0,eq);}
    idx=(T)((int64_t)idx+1);
  }
  return r;
}

// ═══════════════════════════════════════════════════════════════════════════
// UTF-8 REPLACEMENT (replaces utfcpp)
// ═══════════════════════════════════════════════════════════════════════════
namespace utf8 {
template<typename O> inline O append(uint32_t c, O o){
  if(c<0x80){*o++=(uint8_t)c;}
  else if(c<0x800){*o++=(uint8_t)(0xC0|(c>>6));*o++=(uint8_t)(0x80|(c&0x3F));}
  else if(c<0x10000){*o++=(uint8_t)(0xE0|(c>>12));*o++=(uint8_t)(0x80|((c>>6)&0x3F));*o++=(uint8_t)(0x80|(c&0x3F));}
  else if(c<=0x10FFFF){*o++=(uint8_t)(0xF0|(c>>18));*o++=(uint8_t)(0x80|((c>>12)&0x3F));*o++=(uint8_t)(0x80|((c>>6)&0x3F));*o++=(uint8_t)(0x80|(c&0x3F));}
  else{*o++=(char)0xEF;*o++=(char)0xBF;*o++=(char)0xBD;}return o;}
template<typename I> inline uint32_t next(I& i, I e){
  if(i==e) return 0;
  uint8_t b=(uint8_t)*i++; uint32_t c;
  if(b<0x80) c=b;
  else if((b&0xE0)==0xC0){c=b&0x1F;if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);}
  else if((b&0xF0)==0xE0){c=b&0x0F;if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);}
  else if((b&0xF8)==0xF0){c=b&0x07;if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);if(i!=e)c=(c<<6)|((uint8_t)*i++&0x3F);}
  else c=0xFFFD;
  return c;
}
template<typename I> inline uint32_t peek_next(I i, I e){return next(i,e);}
template<typename I> inline void advance(I& i, size_t n, I e){while(n>0&&i!=e){next(i,e);--n;}}
template<typename I> inline size_t distance(I s, I e){size_t c=0;while(s!=e){next(s,e);++c;}return c;}
template<typename I> inline bool is_valid(I s, I e){
  while(s!=e){uint8_t b=(uint8_t)*s;int x;
    if(b<0x80)x=1;else if((b&0xE0)==0xC0){x=2;if(b<0xC2)return false;}
    else if((b&0xF0)==0xE0)x=3;else if((b&0xF8)==0xF0){x=4;if(b>0xF4)return false;}else return false;
    ++s;for(int j=1;j<x;++j){if(s==e)return false;if(((uint8_t)*s&0xC0)!=0x80)return false;++s;}}return true;}
template<typename I,typename O> inline O utf32to8(I s,I e,O o){while(s!=e)o=append(*s++,o);return o;}
template<typename I,typename O> inline O utf8to32(I s,I e,O o){while(s!=e)*o++=next(s,e);return o;}
} // namespace utf8

// ═══════════════════════════════════════════════════════════════════════════
// fmt REPLACEMENT (replaces {fmt} — {} placeholder substitution)
// ═══════════════════════════════════════════════════════════════════════════
namespace fmt {
namespace detail {
  template<typename T> inline void fa(std::ostringstream& o,const T& v){o<<v;}
  inline void fa(std::ostringstream& o,bool v){o<<(v?"true":"false");}
  inline void fi(std::ostringstream& o,const char* f){o<<f;}
  template<typename T,typename...A>
  inline void fi(std::ostringstream& o,const char* f,const T& v,const A&...r){
    while(*f){if(*f=='{'){
      if(*(f+1)=='}'){fa(o,v);fi(o,f+2,r...);return;}
      if(*(f+1)>='0'&&*(f+1)<='9'&&*(f+2)=='}'){fa(o,v);fi(o,f+3,r...);return;}
      if(*(f+1)==':'){const char*c=f+2;while(*c&&*c!='}')c++;if(*c=='}'){fa(o,v);fi(o,c+1,r...);return;}}
    }o<<*f++;}}
} // detail
inline std::string format(const std::string& s){return s;}
template<typename...A> inline std::string format(const char* f,const A&...a){std::ostringstream o;detail::fi(o,f,a...);return o.str();}
template<typename...A> inline std::string format(const std::string& f,const A&...a){return format(f.c_str(),a...);}
template<typename...A> inline void print(const char* f,const A&...a){std::cout<<format(f,a...);}
template<typename...A> inline void print(const std::string& f,const A&...a){std::cout<<format(f.c_str(),a...);}
inline void print(const std::string& m){std::cout<<m;}
template<typename...A> inline void println(const char* f,const A&...a){std::cout<<format(f,a...)<<std::endl;}
inline void println(const std::string& m){std::cout<<m<<std::endl;}
inline void printf(const char* f){std::printf("%s",f);}
template<typename...A> inline void printf(const char* f,A...a){std::printf(f,a...);}
template<typename T> struct formatter{ static std::string stringify(const T& v){std::ostringstream o;o<<v;return o.str();} };
} // namespace fmt

// Colors
namespace nython{namespace color{
  inline const char* reset(){return "\033[0m";}
  inline const char* bold(){return "\033[1m";}
  inline const char* red(){return "\033[31m";}
  inline const char* green(){return "\033[32m";}
  inline const char* yellow(){return "\033[33m";}
  inline const char* blue(){return "\033[34m";}
  inline const char* magenta(){return "\033[35m";}
  inline const char* cyan(){return "\033[36m";}
  inline const char* white(){return "\033[37m";}
  inline const char* gray(){return "\033[90m";}
}}

// Forward declarations
namespace nython{
  namespace kernel{struct Object;struct Class;struct Method;struct Package;struct Module;struct NameSpace;struct Value;class bigint;}
  namespace io{extern std::string file_name;extern std::vector<std::string> lines;}
  namespace gc{class Collectable;class GarbageCollector;}
  namespace lexer{struct Location;struct Token;class Lexer;}
  namespace reader{class SourceCode;}
  namespace node{struct Node;struct Script;using node_ptr=std::shared_ptr<Node>;}
  namespace parser{class Parser;}
  namespace visitor{struct IVisitor;}
  namespace exception{
  class Exception {
public:
    Exception(const Exception&) = default;
    Exception& operator=(const Exception&) = default;

    std::string message_;
    Exception* previous_;
  public:
    inline Exception(std::string message, Exception* previous) : message_(message), previous_(previous) {}
    inline Exception(std::string message) : Exception(message, nullptr) {}
    virtual ~Exception() = default;
    inline std::string message() { return message_; }
    virtual inline std::string what() noexcept { return message_; }
    inline Exception* previous() { return previous_; }
  };
}
  namespace vm{class VirtualMachine;}
  class Runnable;
}


#define NYTHON_EXIT_OK 0
#define NYTHON_EXIT_USAGE 64
#define NYTHON_EXIT_DATAERR 65
#define NYTHON_EXIT_SOFTWAREERR 70
#define NYTHON_EXIT_OSERR 71
#define NYTHON_EXIT_IOERR 74
#define NYTHON_EXIT_CONFIG 78

#endif // NYTHON_DEFINITIONS_HPP
