#pragma once

#ifndef __UTIL__HPP
#define __UTIL__HPP

// Must be first: sets WIN32_LEAN_AND_MEAN/_WINSOCKAPI_ before sys/stat.h
#include "Definitions.hpp"
#include <cmath>
#include <cfloat>
#include "bigint.hpp"
#include <sys/stat.h>
#include "Object.hpp"
#include "Except.hpp"

#ifndef _MSC_VER
#   include <cxxabi.h>
#endif

// utf8 provided by Definitions.hpp
// fmt provided by Definitions.hpp


// IS_NAN in Definitions.hpp
// IS_INFINITY in Definitions.hpp
#define FORCE_DOUBLE(X)    (force_double(X))
#define FLOAT_PRECISION    12

#define SLASHES "/\\"

#define __OCT__(str,ret)\
    int cpt = 0;\
    std::string tmp;\
    long len = str.size(),i;\
    for(i = len-1;i>=0;i--){\
        if(cpt<3){\
            tmp.insert(0,std::string()+str[i]);\
            cpt++;\
        }else{\
            ret.insert(0,std::string()+OctToNumMap[tmp]);\
            cpt = 1;\
            tmp.clear();\
            tmp.insert(0,std::string()+str[i]);\
        }\
    }\
    if(tmp.size()){\
        if(tmp.size()<3)  tmp.insert(0,"0");\
        if(tmp.size()==2) tmp.insert(0,"0");\
        ret.insert(0,std::string()+OctToNumMap[tmp]);\
    }\
    ret.insert(0,"0o");\



namespace nython::utils {

// Enum that defines the type of the std::string to (un)escape
enum class StringEscapeType {
    DOUBLE_QUOTED,  // Escapes double quotes
    SINGLE_QUOTED,  // Escapes single quotes
};

static const int SPLIT_COMPRESS    			  = 1;
static const int SPLIT_NO_COMPRESS 			  = 0;
static const int MIN_HIGH_SURROGATE           = 55296;
static const int MIN_LOW_SURROGATE            = 56320;
static const int MAX_LOW_SURROGATE            = 57343;
static const int MAX_HIGH_SURROGATE           = 56319;
static const int MIN_SUPPLEMENTARY_CODE_POINT = 0x010000;
static const int MIN_SURROGATE                = MIN_HIGH_SURROGATE;
static const int MAX_SURROGATE                = MAX_LOW_SURROGATE;
static const int MAX_CODE_POINT               = 0X10FFFF;

extern std::map<char,std::string> HexMap;
extern std::map<char,std::string> OctMap;
extern std::map<std::string,char> OctToNumMap;
extern std::map<int,std::string> TypeNames;

using nython::lexer::Token;
using nython::kernel::Type;
using nython::kernel::Value;
using nython::kernel::Class;
using nython::kernel::Method;
using nython::kernel::bigint;
using nython::kernel::Object;
using nython::exception::Exception;

using std::string;
using std::map;
using std::stringstream;

std::string      dec(const std::string& v);
std::string      __string__(bigint v);
std::string      __string__(long double v);
bigint      __int__(const std::string& v);
long double __float__(const std::string& v);

inline std::string remove_zero(const std::string& v){
    std::string ret = v;
    int num = 0; int len = static_cast<int>(v.size());
    while(num<len&&v[num]=='0') num++;
    if(num==len) return "0";
    return ret.erase(0,num);
}

inline std::string hex(int v){
    std::stringstream ret;
    std::hex(ret);
    ret<<v;
    return std::string("0x").append(ret.str());
}

inline std::string hex(long v){
    std::stringstream ret;
    std::hex(ret);
    ret<<v;
    return std::string("0x").append(ret.str());
}

inline std::string hex(bigint v){
    std::stringstream ret;
    std::hex(ret);
    ret<<v;
    return std::string("0x").append(ret.str());
}

inline std::string hex(const std::string& v){
    std::string ret,str = v;
    uint64_t len = str.size();
    if(v[1]=='x'||v[1]=='X'){
        ret = v;
    }else if(v[1]=='o'||v[1]=='O'){
        for(uint64_t i = 2;i<len;i++){
            ret.append(OctMap[str[i]]);
        };
        ret = remove_zero(ret);
        ret = std::string("0b").append(ret);
        return hex(__int__(ret));
    }else if(v[1]=='b'||v[1]=='B') return hex(__int__(v));
    return ret;
}

inline std::string hex(void* v){
    std::stringstream ret;
    std::hex(ret);
    ret<<v;
    return ret.str();
}

inline std::string bin(int v){
    std::string ret,str = hex(v);
    uint64_t len = str.size();
    for(uint64_t i = 2;i<len;i++){
        ret.append(HexMap[str[i]]);
    };
    ret = remove_zero(ret);
    ret = std::string("0b").append(ret);
    return ret;
}

inline std::string bin(long v){
    std::string ret,str = hex(v);
    uint64_t len = str.size();
    for(uint64_t i = 2;i<len;i++){
        ret.append(HexMap[str[i]]);
    };
    ret = remove_zero(ret);
    ret = std::string("0b").append(ret);
    return ret;
}

inline std::string bin(bigint v){
    std::string ret,str = hex(v);
    uint64_t len = str.size();
    for(uint64_t i = 2;i<len;i++){
        ret.append(HexMap[str[i]]);
    };
    ret = remove_zero(ret);
    ret = std::string("0b").append(ret);
    return ret;
}

inline std::string bin(const std::string& v){
    std::string ret,str = v;
    uint64_t len = str.size();
    if(v[1]=='x'||v[1]=='X'){
        for(uint64_t i = 2;i<len;i++){
            ret.append(HexMap[str[i]]);
        };
        ret = remove_zero(ret);
        ret = std::string("0b").append(ret);
    }else if(v[1]=='o'||v[1]=='O'){
        for(uint64_t i = 2;i<len;i++){
            ret.append(OctMap[str[i]]);
        };
        ret = remove_zero(ret);
        ret = std::string("0b").append(ret);
    }else if(v[1]=='b'||v[1]=='B') ret = v;
    return ret;
}

inline std::string bin(void* v){
    std::string ret,str = hex(v);
    uint64_t len = str.size();
    for(uint64_t i = 2;i<len;i++){
        ret.append(HexMap[str[i]]);
    };
    ret = remove_zero(ret);
    ret = std::string("0b").append(ret);
    return ret;
}

inline std::string oct(void* v){
    std::string ret,str = bin(v).erase(0,2);
    __OCT__(str,ret);
    return ret;
}

inline std::string oct(const std::string& v){
    std::string ret,str = v;
    if(v[1]=='x'||v[1]=='X'){
        str = bin(v).erase(0,2);
        __OCT__(str,ret);
        return ret;
    }else if(v[1]=='o'||v[1]=='O'){
        ret = v;
    }else if(v[1]=='b'||v[1]=='B'){
        str.erase(0,2);
        __OCT__(str,ret);
        return ret;
    }else{
        str = bin(v);
        str.erase(0,2);
        __OCT__(str,ret);
        return ret;
    }
    return ret;
}

inline std::string oct(int v){
    std::string ret,str = bin(v).erase(0,2);
    __OCT__(str,ret);
    return ret;
}

inline std::string oct(long v){
    std::string ret,str = bin(v).erase(0,2);
    __OCT__(str,ret);
    return ret;
}

inline std::string oct(bigint v){
    std::string ret,str = bin(v).erase(0,2);
    __OCT__(str,ret);
    return ret;
}

inline std::string format(){
    return "";
}

inline std::string format(bool t){
    return t?"true":"false";
}

inline std::string format(Type type){
    return TypeNames[int(type)];
}

template<class T>
inline std::string format(T value){
    std::stringstream str;
    str<<value;
    return str.str();
}

template<typename T,typename...Args>
inline std::string format(T&& t,Args&&... args){
    return format(std::forward<T&&>(t)).append(format(std::forward<Args&&>(args)...));
}

inline uint64_t hash(const std::string& s){
    if(s.size() == 0) return 0;
    long long h = s[0] << 7;
    for(int i = 0; i < (int)s.size(); ++i) h = (h * 1000003) ^ s[i];
    h = h ^ (long long)s.size();
    return h;
}

inline uint64_t hash(const char* s){
    return hash(std::string(s));
}

inline uint64_t hash(float f){
    float ip = 0.0;
    if(std::modf(f,&ip) == 0.0) return (long long)f;
    else{
        long long* p = (long long*)&f;
        return *p;
    }
}

inline uint64_t hash(double f){
    double ip = 0.0;
    if(modf(f,&ip) == 0.0) return (long long)f;
    else{
        long long* p = (long long*)&f;
        return *p;
    }
}

inline uint64_t hash(long double f){
    long double ip = 0.0;
    if(std::modf(f,&ip) == 0.0) return (long long)f;
    else{
        long long* p = (long long*)&f;
        return *p;
    }
}

inline uint64_t hash(int f){
    return f;
}

inline uint64_t hash(long f){
    return f;
}

inline uint64_t hash(long long f){
    return f;
}

inline uint64_t hash(bigint f){
    return f;
}

template<typename T>
inline uint64_t hash(const T& obj){
    return (unsigned long long)obj;
}

template<typename T>
inline uint64_t hash(const T* obj){
    return *((unsigned long long*)obj);
}

inline uint64_t hash(const Object& arg){
    return hash(&arg);
}

inline uint64_t hash(Object* arg){
    if(arg == nullptr){
        return 0x1234;
    }
    long long ret = 0x1234;
    Object* that = (Object*)arg;
    #undef INTERFACE
    switch(that->getType()){
        case Type::STRING:{
            ret = hash(that->toString());
        }
        break;
        case Type::CLASS:
        case Type::PROPERTY:
        case Type::INTERFACE:
        case Type::FUNCTION:
        case Type::METHOD:
        case Type::LAMBDA:
        case Type::LIST:
        case Type::TUPLE:
        case Type::ARRAY:
        case Type::MAP:
        case Type::FUNLIST:
        case Type::PACKAGE:
        case Type::MODULE:
        case Type::NAMESPACE:
        default:{
            std::string s = that->toString();
            ret = hash(s);
        }
        break;
    }
    return ret;
}

inline std::string capitalize(const std::string& str){
    std::string chr = str;
    chr[0] = toupper(chr[0]);
    return chr;
}

inline std::string copy(const std::string& src,int index = 0,int end = -1){
    std::string dest;
    if(end==-1){
        end = src.size()-1;
    }
    for(int i = index;i<=end;i++){
        dest += src[i];
    }
    return dest;
}

template <class T>
inline auto type_name() -> std::string{
    auto n = typeid(T).name();
    #ifndef _MSC_VER
    auto own = std::unique_ptr<char, void(*)(void*)>{abi::__cxa_demangle(n, nullptr, nullptr, nullptr), free};
    if(own!=nullptr) n = own.get();
    #endif
    auto r = std::string{n};
    if(std::is_const<T>::value)                r += " const";
    if(std::is_volatile<T>::value)             r += " volatile";
    if(std::is_lvalue_reference<T>::value)      r += "&";
    else if(std::is_rvalue_reference<T>::value) r += "&&";
    return r;
}

template <class T>
inline auto type_name(T value) -> std::string{
    auto n = typeid(T).name();
    #ifndef _MSC_VER
    auto own = std::unique_ptr<char, void(*)(void*)>{abi::__cxa_demangle(n, nullptr, nullptr, nullptr), free};
    if(own!=nullptr) n = own.get();
    #endif
    auto r = std::string{n};
    if(std::is_const<T>::value)                r += " const";
    if(std::is_volatile<T>::value)             r += " volatile";
    if(std::is_lvalue_reference<T>::value)      r += "&";
    else if(std::is_rvalue_reference<T>::value) r += "&&";
    else if(std::is_pointer<T>::value)          r = copy(r,0,r.size()-2);
    return r;
}

inline std::string replace(std::string& str,const std::string& search,const std::string& replace){
    if(search!=replace){
        size_t pos = 0;
        while((pos = str.find(search, pos)) != std::string::npos){
			str.replace(pos,search.length(), replace);
			pos += replace.length();
        }
    }
    return str;
}

inline std::string replace(std::string& str,char ch,char chr){
    return replace(str,format(ch),format(chr));
}

inline std::string escapeSpecialXMLChars(std::string s);

inline bool contains(const std::string& name,std::vector<std::string> Map){
    bool good = false;
    std::vector<std::string>::iterator it = Map.begin();
    while(it!=Map.end()){
        if((*it)==name){
            good = true;
            break;
        }
        ++it;
    }
    return good;
}

inline long double modulo(long double a,long double b){
    long double r;
    try{
        r = floor(a/b);
    }catch(...){
        throw new Exception(format("Division by 0 at line ",((int)__LINE__)-2," in file ",__FILE__));
    }
    return a-b*r;
}

inline long double gcd(long double a,long double b){
    /// Calculate the Greatest Common Divisor
    auto c  = (long double)(0);
    auto mx = std::max(a,b);
    auto mn = std::min(a,b);
    a = mx;
    b = mn;
    while(b){
        c = a;
        a = b;
        b = modulo(c,b);
    }
    return a;
}

inline bool startsWith(const std::string& str,const std::string&  prefix,int toffset){
    char* ta = (char*)str.data();
    int to   = toffset;
    char* pa = (char*)prefix.data();
    int po   = 0;
    int pc   = static_cast<int>(prefix.size());
    if((toffset < 0) || (toffset > (int)str.size() - pc)){
        return false;
    }
    while (--pc >= 0){
        if(ta[to++] != pa[po++]){
            return false;
        }
    }
    return true;
}

inline bool startsWith(const std::string& str,const std::string& pref){
    return startsWith(str,pref,0);
}

inline bool endsWith(const std::string& str,const std::string& suff){
    return startsWith(str,suff,str.size() - suff.size());
}

template<template <typename, typename...> class Wrap,class T,typename P>
inline void split(Wrap<T>& ret,const T& str,P f,int compress = SPLIT_COMPRESS){
}

template<template <typename, typename...> class Wrap>
inline void split(Wrap<std::string>& ret,const std::string& str,const std::string& delimiters = " ",int compress = SPLIT_COMPRESS){
    // Skip delimiters at beginning.
    std::string::size_type lastPos = str.find_first_not_of(delimiters,0);
    // Find first "non-delimiter".
    std::string::size_type pos     = str.find_first_of(delimiters,lastPos);
    while(std::string::npos != pos || std::string::npos != lastPos){
        // Found a token, add it to the std::vector.
        ret.push_back(str.substr(lastPos,pos-lastPos));
        // Skip delimiters.  Note the "not_of"
        lastPos = str.find_first_not_of(delimiters,pos);
        // Find next "non-delimiter"
        pos = str.find_first_of(delimiters,lastPos);
    }
}

inline auto split(const std::string& str,const std::string& sep) -> std::vector<std::string>{
    auto&& ret = std::vector<std::string>{};
    split(ret,str,sep);
    return ret;
}

template <typename T>
inline auto freeze(T&& v) -> T const&&{
    return std::move(v);
}

template <typename T>
inline auto freeze(const T&& v) -> T const&&{
    return std::move(v);
}

template <typename T>
inline auto freeze(T& v) -> T const &{
    return v;
}

template <typename T>
inline auto freeze(const T& v) -> T const &{
    return v;
}

template<typename T>
inline long long length(T t){
    return 1;
}

template<typename T, typename... Args>
inline long long length(T t,Args... args){
    return length(t)+length(args...);
}



using convert_t = std::codecvt_utf8<wchar_t>;
extern std::wstring_convert<convert_t, wchar_t> strconverter;

inline std::string to_string(std::wstring wstr) {
    return strconverter.to_bytes(wstr);
}

inline std::wstring to_wstring(std::string str) {
    return strconverter.from_bytes(str);
}

inline std::wstring to_wstring(std::wstring wstr) {
    return strconverter.from_bytes((char*)wstr.c_str());
}

inline std::stringstream to_string() {
    std::stringstream ss;
    return ss;
}

template<typename T>
inline std::stringstream to_string(T t) {
    std::stringstream ss;
    ss << t;
    return ss;
}

template<typename T, typename... Args>
inline std::stringstream to_string(T t, Args... args) {
    std::stringstream  ss = to_string(t);
    ss << to_string(args...).str();
    return ss;
}

template<typename T>
inline std::wstring to_wstring(T t) {
    std::stringstream ss;
    ss = to_string<T>(t);
    return to_wstring(ss.str());
}

template<typename... Args>
inline std::wstring to_wstring(Args... args) {
    return to_wstring(args...);
}

inline int valid_identifier_start(const char& ch) {
    return ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ((unsigned char)ch >= 0xC0));
}

inline bool iswchar(const char& c){
	bool ok = true;
	#if defined(OS_WINDOWS) || defined(OS_WINDOWS64)
	ok = !isblank(c) && !isascii(c);
	#endif // OS_WINDOWS
    return !isalnum(c)&&!isxdigit(c)&&!iscntrl(c)&&!isgraph(c)&&!isprint(c)&&!ispunct(c)&&!isspace(c)&&ok;
}

inline std::string GetOSName() {
    std::string name = "Unknown OS";
    #ifdef _WIN32
        #ifdef _WIN64
        name = "Windows OS 64 bits";
        #else
        name = "Windows OS 32 bits";
        #endif
    #elif defined (__ANDROID__) || defined(ANDROID)//Android
    name = "Android OS";
    #elif defined (__APPLE__) || defined(__MACH__)//Apple
    name = "Apple OS";
    #elif TARGET_OS_EMBEDDED
    name = "iOS embedded";
    #elif TARGET_IPHONE_SIMULATOR
    name = "iOS Simulator";
    #elif TARGET_OS_IPHONE
    name = "iPhone";
    #elif TARGET_OS_MAC
    name = "MacOS";
    #elif defined (__LINUX__) || defined(__gnu_linux__) || defined(__linux__)//_Ubuntu - Fedora - Centos - RedHat
    name = "Linux";
    #elif _POSIX_VERSION
    name = "POSIX based";
    #elif __sun
    name = "Solaris";
    #elif __hpux
    name = "HP UX";
    #elif BSD
    name = "BSD";
    #elif __DragonFly__
    name = "DragonFly BSD";
    #elif __FreeBSD__
    name = "FreeBSD";
    #elif __NetBSD__
    name = "NetBSD";
    #elif __OpenBSD__
    name = "OpenBSD";
    #endif // _WIN64
    return name;
}

inline std::string trim(const std::string& input) {
    return std::regex_replace(input, std::regex("^ +| +$"), "$1");
}

inline bool FileExists(const std::string& name) {
	struct stat buffer;
	return !name.empty() && (stat (name.c_str(), &buffer) == 0);
}

// Pack a list of runes into a std::string
inline std::string rune_pack_to_str(std::vector<uint32_t> rune_values) {
    std::string str;
    utf8::utf32to8(rune_values.cbegin(), rune_values.cend(), std::back_inserter(str));
    return str;
}

inline std::string rune_pack_to_str(std::initializer_list<uint32_t> rune_values) {
    std::vector<uint32_t> runes(rune_values);
    return rune_pack_to_str(runes);
}

inline std::string rune_pack_to_str(uint32_t rune_value) {
    std::vector<uint32_t> runes({rune_value});
    return rune_pack_to_str(runes);
}

  // Unpack a std::string into a list of runes
inline std::vector<uint32_t> rune_unpack_from_str(std::string str) {
    if (!utf8::is_valid(str.cbegin(), str.cend()))
      throw std::out_of_range(fmt::format("Invalid UTF-8 encoded std::string '{}'", str));

    std::vector<uint32_t> runes;
    utf8::utf8to32(str.cbegin(), str.cend(), std::back_inserter(runes));
    return runes;
}

// Repeat a std::string for the specified amount of times
inline std::string repeat(std::string str, size_t times) {
    std::string result;
    for (size_t i = 0; i < times; i ++)
      result.append(str);
    return result;
}

  // Convert unprintable characters in a std::string to escape sequences
inline std::string escape(std::string str, StringEscapeType type, bool ascii_only) {
    std::string result;

    auto runes = rune_unpack_from_str(str);
    for (size_t i = 0; i < runes.size(); i ++)
    {
      auto rune = runes[i];
      if (rune == 0x5C)
        result.append("\\\\");
      else if (type == StringEscapeType::DOUBLE_QUOTED && rune == 0x22)
        result.append("\\\"");
      else if (type == StringEscapeType::SINGLE_QUOTED && rune == 0x27)
        result.append("\\'");
      else if (rune == 0x08)
        result.append("\\b");
      else if (rune == 0x09)
        result.append("\\t");
      else if (rune == 0x0A)
        result.append("\\n");
      else if (rune == 0x0C)
        result.append("\\f");
      else if (rune == 0x0D)
        result.append("\\r");
      else if (rune <= 0x1F || (rune >= 0x7F && rune <= 0x9F) || (ascii_only && rune >= 0xA0))
        result.append(fmt::format("\\u{{{}}}", rune));
      else
        utf8::append(rune, std::back_inserter(result));
    }
    return result;
}

// Convert escape sequences in a std::string to unprintable characters
inline std::string unescape(std::string str, StringEscapeType type);

// Parse a std::string as another value type
inline int64_t parse_int(std::string str);
inline double parse_real(std::string str);
inline uint32_t parse_rune(std::string str);
inline const char* parse_string(std::string str);

inline std::vector<Value> shift(int pos,std::vector<Value> args){
	std::vector<Value> ret(args.begin()+pos,args.end());
	return ret;
}

/** ---------------------------------------------------------------------
*  is_prime
*  ---------------------------------------------------------------------
*  Description:
*    Checks if a given number is prime and returns true, false otherwise
*  Parameters:
*  number ---> The number to check
**/
inline bool isPrime(long long int number){
	/// 0 and 1 are not prime numbers
    if(number <= 1) return false;
	/// Iterate through from 2 to the integer root of the number
    for(auto i = 2; i <= std::sqrt(number); i++){
        if(number % i == 0) return false;
    }
    return true;
}
/** ---------------------------------------------------------------------
*  range
*  ---------------------------------------------------------------------
*  Description:
*    generate a tuple within range numbers and a step if given
*  Parameters:
*  number ---> The number where to stop
**/
inline std::vector<long double> range(long double stop){
    auto vect = [=](){
        std::vector<ldouble> yield;
		if(stop>=0){
			for(auto i = 0;i<stop;i++){
				yield.push_back(i);
			}
		}else{
			for(auto i = stop;i<0;i++){
				yield.push_back(i);
			}
		}
		return yield;
	};
	return vect();
}

inline void _merge(Object* clazz,std::unordered_map<std::string,Value>* table){
	for(auto it = clazz->container->begin();it!=clazz->container->end();it++){
		(*table)[it->first] = it->second;
	}
}

inline void merge(Object* clazz,std::unordered_map<std::string,Value>* table){
	if(!clazz || clazz->container) return;
	if(clazz!=nullptr&&clazz->getParent()!=nullptr&&clazz!=clazz->getParent()){
		merge(clazz->getParent(),table);
		_merge(clazz,table);
	}else if(clazz!=nullptr){
		_merge(clazz,table);
	}
}

inline std::vector<long double> range(long double start,long double stop){
    auto vect = [=](){
        std::vector<ldouble> yield;
		if(stop<start){
			auto end = std::abs(stop);
			for(auto i = start;std::abs(i)<end;i--){
				yield.push_back(i);
			}
		}else{
			for(auto i = start;i<stop;i++){
				yield.push_back(i);
			}
		}
		return yield;
	};
	return vect();
}

inline std::vector<long double> range(long double start,long double stop, long double step){
    auto vect = [=](){
        std::vector<ldouble> yield;
		if(stop>=start){
			if(step>0){
				for(auto i = start;i<stop;i+= step){
					yield.push_back(i);
				}
			}
		}else{
			if(step<0){
				int end = abs(stop);
				for(auto i = start;abs(i)<end;i+= step){
					yield.push_back(i);
				}
			}
		}
		return yield;
	};
	return vect();
}

inline bool before(const std::string& cpl){
    signed pos    = cpl.find_first_of("+");
    if(pos!=-1){
        signed first = pos;
        pos          = cpl.find_first_of("j");
        if(pos!=-1) return pos < first;
        else{
            pos = cpl.find_first_of("J");
            return pos < first;
        }
    }else{
        pos = cpl.find_first_of("-");
        if(pos!=-1){
            signed first = pos;
            pos          = cpl.find_first_of("j");
            if(pos!=-1) return pos < first;
            else{
                pos = cpl.find_first_of("J");
                return pos < first;
            }
        }
    }
    return false;
}

inline ldouble real(const std::string& cpl){
    bool ok;
    std::string r;
    signed pos;
    ldouble $real{};
    ok  = before(cpl);
    pos = cpl.find_first_of("+");
    if(ok){
        if(pos!=-1) r = cpl.substr(pos+1);
        else{
            pos = cpl.find_first_of("-");
            r   = cpl.substr(pos);
        }
    }else{
        if(pos!=-1) r = cpl.substr(0,pos);
        else{
            pos = cpl.find_first_of("-");
            r   = cpl.substr(0,pos);
        }
    }
    $real = atof(r.c_str());
    return $real;
}

inline ldouble img(const std::string& cpl){
    bool ok;
    std::string i;
    signed pos;
    ldouble $img{};
    ok = before(cpl);
    pos = cpl.find_last_of("+");
    if(ok){
        if(pos!=-1) i = cpl.substr(0,pos);
        else{
            pos = cpl.find_last_of("-");
            i   = cpl.substr(0,pos);
        }
    }else if(signed(cpl.find_first_of("j"))!=-1||signed(cpl.find_first_of("J"))!=-1){
        if(pos!=-1) i = cpl.substr(pos,cpl.size()-2);
        else{
            pos = cpl.find_last_of("-");
            i   = cpl.substr(pos,cpl.size()-2);
        }
    }
    if(i=="+"||i=="-") i = (i=="+") ? "1":"-1";
    $img = atof(i.c_str());
    return $img;
}

inline std::string sign(const std::string& cpl){
    signed pos = cpl.find_last_of("+");
    if(pos!=-1) return "+";
    pos = cpl.find_last_of("-");
    if(pos!=-1) return "-";
    return "+";
}

template<typename T>
std::basic_string<T> toLower(const std::basic_string<T>& s){
    std::basic_string<T> str(s);
    [str](char ch){
       ch = tolower(ch);
    };
    return str;
}

template<typename T>
std::basic_string<T> toUpper(const std::basic_string<T>& s){
    std::basic_string<T> str(s);
    [str](char ch){
       ch = toupper(ch);
    };
    return str;
}

template<typename T, typename F>
std::basic_string<T> trim(std::basic_string<T>& str, const F& pred){
    size_t first = 0;
    size_t len = str.length();
    if(len == 0) return str;
    while(first < len && pred(str[first])) ++first;
    if(first == len){
        str = std::basic_string<T>();
        return str;
    }
    int last = (int)len-1;
    while (last >= 0 && pred(str[last])) --last;
    if(first != 0 || last != (int)str.length()-1) str = str.substr(first, last-first+1);
    return str;
}


template<typename T>
std::basic_string<T> trim(std::basic_string<T>& str){
    trim(str, [](T c)->bool{ return c == ' ' || c == '\t' || c == '\n'; });
    return str;
}

template<typename T>
std::basic_string<T> strip(std::basic_string<T>& str, const std::basic_string<T>& remove){
    trim(str, [&](T c)->bool{
        return remove.find(c) != std::basic_string<T>::npos;
    });
    return str;
}

inline std::string chomp(const string& code){
    std::string ret;
    unsigned i = 0;
    while(i<code.size()){
        if(code[i]=='\n'){
            ret += code[i++];
            while(code[i]=='\n'){
                i++;
            }
        }else{
            ret += code[i++];
        }
    }
    return ret;
}

template<typename T, typename F>
std::basic_string<T> unspace(std::basic_string<T>& str, const F& pred){
    int i = 0;
    int size = static_cast<int>(str.size());
    std::string ret;
    while(i<size){
        if(pred(str[i])){
            while(i<size&&pred(str[i])) i++;
            if(ret.size()&&i<size) ret += " ";
        }else{
            ret += str[i++];
        }
    }
    str = ret;
    return str;
}

template<typename T>
std::basic_string<T> unspace(std::basic_string<T>& str){
    return unspace(str, [](T c)->bool{ return isspace(c); });
}

inline std::vector<std::string> split(const std::string &s, char delim){
    std::vector<std::string> elems;
    std::stringstream ss(s);
    std::string item;
    while(std::getline(ss,item,delim)){
        elems.push_back(item);
    }
    return elems;
}

inline std::string join(const std::vector<std::string>& str,char delim,int len = -1){
    std::string ret;
    if(len==-1) len = str.size()-1;
    for(auto i = 0;i<=len;i++){
        ret.append(str[i]);
        ret += delim;
    }
    if(len < (int)str.size()) ret.append(str[len]);
    return ret;
}

inline std::string join(const std::vector<std::string>& str,const char* delim,int len = -1){
    std::string ret;
    if(len==-1) len = str.size()-1;
    for(auto i = 0;i<=len-1;i++){
        ret.append(str[i]);
        ret += delim;
    }
    if(len < (int)str.size()) ret.append(str[len]);
    return ret;
}

inline std::string join(const std::vector<std::string>& str,const std::string& delim,int len = -1){
    return join(str,delim.c_str(),len);
}

inline std::string filename(const std::string& path){
    // find the last slash
    size_t startPos = path.find_last_of(SLASHES);
    if(startPos == std::string::npos) startPos = 0;
    else startPos += 1;
    size_t endPos = path.find_last_of('.');
    if(endPos == path.npos || endPos < startPos){
        endPos = path.length();
    }
    return path.substr(startPos,endPos - startPos);
}

inline std::string extension(const std::string& name){
    return name.substr(name.find_last_of("."));
}

template<typename T>
T tryLookup(const map<std::string, T>& d, const std::string& name){
    auto it = d.find(name);
    if(it == d.end()) return T();
    return it->second;
}

inline std::string format(Value* v,int precision);
inline void format_float(char *buf, size_t buflen,Value* v, int precision);

inline double force_double(double x){
	volatile double y;
	y = x;
	return y;
}

inline double _strtod(const char *nptr, char **endptr){
	char *fail_pos;
	double val = -1.0;
	struct lconv *locale_data;
	const char *decimal_point;
	size_t decimal_point_len;
	const char *p, *decimal_point_pos;
	const char *end = NULL; /* Silence gcc */
	const char *digits_pos = NULL;
	int negate = 0;
	assert(nptr != NULL);
	fail_pos = NULL;
	locale_data = localeconv();
	decimal_point = locale_data->decimal_point;
	decimal_point_len = strlen(decimal_point);
	assert(decimal_point_len != 0);
	decimal_point_pos = NULL;
	/** We process any leading whitespace and the optional sign manually,
	   then pass the remainder to the system strtod.  This ensures that
	   the result of an underflow has the correct sign. (bug #1725)
    */
	p = nptr;
	/* Skip leading space */
	while(isspace(*p)) p++;
	/* Process leading sign, if present */
	if(*p == '-'){
		negate = 1;
		p++;
	}else if(*p == '+'){
		p++;
	}
	/* What's left should begin with a digit, a decimal point, or one of the letters i, I, n, N. It should not begin with 0x or 0X */
	if((!isdigit(*p) && *p != '.' && *p != 'i' && *p != 'I' && *p != 'n' && *p != 'N')||(*p == '0' && (p[1] == 'x' || p[1] == 'X'))){
		if(endptr) *endptr = (char*)nptr;
		errno = EINVAL;
		return val;
	}
	digits_pos = p;
	if(decimal_point[0] != '.' || decimal_point[1] != 0){
		while(isdigit(*p)) p++;

		if(*p == '.'){
			decimal_point_pos = p++;
			while(isdigit(*p)) p++;
			if(*p == 'e' || *p == 'E') p++;
			if(*p == '+' || *p == '-') p++;
			while(isdigit(*p)) p++;
			end = p;
		}else if(strncmp(p, decimal_point, decimal_point_len) == 0){
			/* Python bug #1417699 */
			if(endptr) *endptr = (char*)nptr;
			errno = EINVAL;
			return val;
		}
		/* For the other cases, we need not convert the decimal point */
	}

	/* Set errno to zero, so that we can distinguish zero results and underflows */
	errno = 0;

	if(decimal_point_pos){
		char *copy, *c;
		/* We need to convert the '.' to the locale specific decimal point */
		copy = (char *)malloc(end - digits_pos + 1 + decimal_point_len);
		if(copy == NULL){
			if(endptr) *endptr = (char *)nptr;
			errno = ENOMEM;
			return val;
		}
		c = copy;
		memcpy(c, digits_pos, decimal_point_pos - digits_pos);
		c += decimal_point_pos - digits_pos;
		memcpy(c, decimal_point, decimal_point_len);
		c += decimal_point_len;
		memcpy(c, decimal_point_pos + 1,end - (decimal_point_pos + 1));
		c += end - (decimal_point_pos + 1);
		*c = 0;
		val = strtod(copy, &fail_pos);
		if(fail_pos){
			if(fail_pos > decimal_point_pos) fail_pos = (char *)digits_pos + (fail_pos - copy) - (decimal_point_len - 1);
			else fail_pos = (char *)digits_pos + (fail_pos - copy);
		}
		free(copy);
	}
	else{
		val = strtod(digits_pos, &fail_pos);
	}
	if(fail_pos == digits_pos) fail_pos = (char *)nptr;
	if(negate && fail_pos != nptr) val = -val;

	if(endptr) *endptr = fail_pos;

	return val;
}

inline int _vsnprintf(char *str, size_t size, const char  *format, va_list va){
    int len;
    assert(str != NULL);
	assert(size > 0);
	assert(format != NULL);
    len = vsnprintf(str, size, format, va);
    return len;
}

inline int _snprintf(char *str, size_t size, const  char  *format, ...){
	int rc;
	va_list va;
	va_start(va, format);
	rc = _vsnprintf(str, size, format, va);
	va_end(va);
	return rc;
}

inline int insertThousandsGrouping(char *buffer,int n_buffer,int n_digits,int buf_size,int *count,int append_zero_char){
	struct lconv *locale_data = localeconv();
	const char *grouping = locale_data->grouping;
	const char *thousands_sep = locale_data->thousands_sep;
	int thousands_sep_len = strlen(thousands_sep);
	char *pend = NULL; /* current end of buffer */
	char *pmax = NULL; /* max of buffer */
	char current_grouping;
	int remaining = n_digits; /* Number of chars remaining to be looked at */
	/* Initialize the character count, if we're just counting. */
	if(count) *count = 0;
	else{
		/* We're not just counting, we're modifying buffer */
		pend = buffer + n_buffer;
		pmax = buffer + buf_size;
	}
	/* Starting at the end and working right-to-left, keep track of what grouping needs to be added and insert that. */
	current_grouping = *grouping++;
	/* If the first character is 0, perform no grouping at all. */
	if(current_grouping == 0) return 1;
	while(remaining > current_grouping){
		/* Always leave buffer and pend valid at the end of this loop, since we might leave with a return statement. */
		remaining -= current_grouping;
		if(count){
			/* We're only counting, not touching the memory. */
			*count += thousands_sep_len;
		}
		else{
			/* Do the formatting. */
			char *plast = buffer + remaining;
			/* Is there room to insert thousands_sep_len chars? */
			if(pmax - pend < thousands_sep_len)
				/* No room. */
				return 0;
			/* Move the rest of the string down. */
			memmove(plast + thousands_sep_len,plast,(pend - plast) * sizeof(char));
			/* Copy the thousands_sep chars into the buffer. */
#if STRINGLIB_IS_UNICODE
			/* Convert from the char's of the thousands_sep from the locale into unicode. */
			{
				int i;
				for (i = 0; i < thousands_sep_len; ++i) plast[i] = thousands_sep[i];
			}
#else
			/* No conversion, just memcpy the thousands_sep. */
			memcpy(plast, thousands_sep, thousands_sep_len);
#endif
		}

		/* Adjust end pointer. */
		pend += thousands_sep_len;

		/* Move to the next grouping character, unless we're
		   repeating (which is designated by a grouping of 0). */
		if(*grouping != 0){
			current_grouping = *grouping++;
			if(current_grouping == CHAR_MAX)
				/* We're done. */
				break;
		}
	}
	if(append_zero_char){
		/* Append a zero character to mark the end of the string,
		   if there's room. */
		if(pend - (buffer + remaining) < 1)
			/* No room, error. */
			return 0;
		*pend = 0;
	}
	return 1;
}

/** Given a string that may have a decimal point in the current
   locale, change it back to a dot.  Since the string cannot get
   longer, no need for a maximum buffer size parameter.
*/
inline void change_decimal_from_locale_to_dot(char* buffer){
	struct lconv *locale_data = localeconv();
	const char *decimal_point = locale_data->decimal_point;

	if(decimal_point[0] != '.' || decimal_point[1] != 0){
		size_t decimal_point_len = strlen(decimal_point);
		if(*buffer == '+' || *buffer == '-') buffer++;
		while(isdigit(*buffer)) buffer++;
		if(strncmp(buffer, decimal_point, decimal_point_len) == 0){
			*buffer = '.';
			buffer++;
			if(decimal_point_len > 1){
				/* buffer needs to get smaller */
				size_t rest_len = strlen(buffer + (decimal_point_len - 1));
				memmove(buffer,buffer + (decimal_point_len - 1),rest_len);
				buffer[rest_len] = 0;
			}
		}
	}
}

#define MIN_EXPONENT_DIGITS 2

/* Ensure that any exponent, if present, is at least MIN_EXPONENT_DIGITS in length. */
inline void ensure_minumim_exponent_length(char* buffer, size_t buf_size){
	char *p = strpbrk(buffer, "eE");
	if(p && (*(p + 1) == '-' || *(p + 1) == '+')){
		char *start = p + 2;
		int exponent_digit_cnt = 0;
		int leading_zero_cnt = 0;
		int in_leading_zeros = 1;
		int significant_digit_cnt;
		/* Skip over the exponent and the sign. */
		p += 2;
		/* Find the end of the exponent, keeping track of leading zeros. */
		while(*p && isdigit(*p)){
			if(in_leading_zeros && *p == '0') ++leading_zero_cnt;
			if(*p != '0') in_leading_zeros = 0;
			++p;
			++exponent_digit_cnt;
		}
		significant_digit_cnt = exponent_digit_cnt - leading_zero_cnt;
		if(exponent_digit_cnt == MIN_EXPONENT_DIGITS){
			/* If there are 2 exactly digits, we're done,regardless of what they contain */
		}else if(exponent_digit_cnt > MIN_EXPONENT_DIGITS){
			int extra_zeros_cnt;
			/* There are more than 2 digits in the exponent.  See if we can delete some of the leading zeros */
			if(significant_digit_cnt < MIN_EXPONENT_DIGITS) significant_digit_cnt = MIN_EXPONENT_DIGITS;
			extra_zeros_cnt = exponent_digit_cnt -significant_digit_cnt;

			/* Delete extra_zeros_cnt worth of characters from the front of the exponent */
			assert(extra_zeros_cnt >= 0);
			/* Add one to significant_digit_cnt to copy the trailing 0 byte, thus setting the length */
			memmove(start,start + extra_zeros_cnt,
				significant_digit_cnt + 1);
		}
		else{
			/* If there are fewer than 2 digits, add zeros until there are 2, if there's enough room */
			int zeros = MIN_EXPONENT_DIGITS - exponent_digit_cnt;
			if(start + zeros + exponent_digit_cnt + 1 < buffer + buf_size){
				memmove(start + zeros, start,exponent_digit_cnt + 1);
				memset(start, '0', zeros);
			}
		}
	}
}

/** Ensure that buffer has a decimal point in it.  The decimal point
   will not be in the current locale, it will always be '.'
*/
inline void ensure_decimal_point(char* buffer, size_t buf_size){
	int insert_count = 0;
	char* chars_to_insert;

	/* search for the first non-digit character */
	char *p = buffer;
	/* Skip leading sign, if present.  I think this could only ever be '-', but it can't hurt to check for both. */
	if(*p == '-' || *p == '+') ++p;
	while(*p && isdigit(*p)) ++p;
	if(*p == '.'){
		if(isdigit(*(p+1))){
			/* Nothing to do, we already have a decimal point and a digit after it */
		}
		else{
			/* We have a decimal point, but no following digit.  Insert a zero after the decimal. */
			++p;
			chars_to_insert = (char*)"0";
			insert_count = 1;
		}
	}
	else{
		chars_to_insert = (char*)".0";
		insert_count = 2;
	}
	if(insert_count){
		size_t buf_len = strlen(buffer);
		if(buf_len + insert_count + 1 >= buf_size){
			/* If there is not enough room in the buffer for the additional text, just skip it.  It's not worth generating an error over. */
		}
		else{
			memmove(p + insert_count, p,buffer + strlen(buffer) - p + 1);
			memcpy(p, chars_to_insert, insert_count);
		}
	}
}

/** Add the locale specific grouping characters to buffer.  Note
   that any decimal point (if it's present) in buffer is already
   locale-specific.  Return 0 on error, else 1.
*/
inline int add_thousands_grouping(char* buffer, size_t buf_size){
	int len = strlen(buffer);
	struct lconv *locale_data = localeconv();
	const char *decimal_point = locale_data->decimal_point;

	/* Find the decimal point, if any.  We're only concerned
	   about the characters to the left of the decimal when
	   adding grouping. */
	char *p = strstr(buffer, decimal_point);
	if(!p){
		/* No decimal, use the entire string. */
		/* If any exponent, adjust p. */
		p = strpbrk(buffer, "eE");
		if(!p)
			/* No exponent and no decimal.  Use the entire string. */
			p = buffer + len;
	}
	/** At this point, p points just past the right-most character wevwant to format.  We need to add the grouping string for the
	   characters between buffer and p.
    */
	return insertThousandsGrouping(buffer, len, p-buffer,buf_size, NULL, 1);
}

/* see FORMATBUFLEN in unicodeobject.c */
#define FLOAT_FORMATBUFLEN 120

/**
 * _ascii_formatd:
 * @buffer: A buffer to place the resulting string in
 * @buf_size: The length of the buffer.
 * @format: The printf()-style format to use for the
 *          code to use for converting.
 * @d: The #gdouble to convert
 *
 * Converts a #gdouble to a string, using the '.' as
 * decimal point. To format the number you pass in
 * a printf()-style format string. Allowed conversion
 * specifiers are 'e', 'E', 'f', 'F', 'g', 'G', and 'n'.
 *
 * 'n' is the same as 'g', except it uses the current locale.
 * 'Z' is the same as 'g', except it always has a decimal and
 *     at least one digit after the decimal.
 *
 * Return value: The pointer to the buffer with the converted string.
 **/
inline char* _ascii_formatd(char* buffer,size_t buf_size,const char* format,double d){
	char format_char;
	size_t format_len = strlen(format);

	/* For type 'n', we need to make a copy of the format string, because
	   we're going to modify 'n' -> 'g', and format is const char*, so we
	   can't modify it directly.  FLOAT_FORMATBUFLEN should be longer than
	   we ever need this to be.  There's an upcoming check to ensure it's
	   big enough. */
	/* Issue 2264: code 'Z' requires copying the format.  'Z' is 'g', but
	   also with at least one character past the decimal. */
	char tmp_format[FLOAT_FORMATBUFLEN];

	/* The last character in the format string must be the format char */
	format_char = format[format_len - 1];

	if(format[0] != '%') return NULL;

	/* I'm not sure why this test is here.  It's ensuring that the format
	   string after the first character doesn't have a single quote, a
	   lowercase l, or a percent. This is the reverse of the commented-out
	   test about 10 lines ago. */
	if(strpbrk(format + 1, "'l%")) return NULL;

	/* Also curious about this function is that it accepts format strings
	   like "%xg", which are invalid for floats.  In general, the
	   interface to this function is not very good, but changing it is
	   difficult because it's a public API. */

	if(!(format_char == 'e' || format_char == 'E' || format_char == 'f' || format_char == 'F' || format_char == 'g' || format_char == 'G' ||
      format_char == 'n' || format_char == 'Z')) return NULL;

	/* Map 'n' or 'Z' format_char to 'g', by copying the format string and
	   replacing the final char with a 'g' */
	if(format_char == 'n' || format_char == 'Z'){
		if(format_len + 1 >= sizeof(tmp_format)){
			/* The format won't fit in our copy.  Error out.  In
			   practice, this will never happen and will be
			   detected by returning NULL */
			return NULL;
		}
		strcpy(tmp_format, format);
		tmp_format[format_len - 1] = 'g';
		format = tmp_format;
	}


	/* Have _snprintf do the hard work */
	_snprintf(buffer, buf_size, format, d);

	/* Do various fixups on the return string */

	/* Get the current locale, and find the decimal point string.
	   Convert that string back to a dot.  Do not do this if using the
	   'n' (number) format code, since we want to keep the localized
	   decimal point in that case. */
	if(format_char != 'n') change_decimal_from_locale_to_dot(buffer);

	/* If an exponent exists, ensure that the exponent is at least
	   MIN_EXPONENT_DIGITS digits, providing the buffer is large enough
	   for the extra zeros.  Also, if there are more than
	   MIN_EXPONENT_DIGITS, remove as many zeros as possible until we get
	   back to MIN_EXPONENT_DIGITS */
	ensure_minumim_exponent_length(buffer, buf_size);

	/* If format_char is 'Z', make sure we have at least one character
	   after the decimal point (and make sure we have a decimal point). */
	if(format_char == 'Z') ensure_decimal_point(buffer, buf_size);

	/* If format_char is 'n', add the thousands grouping. */
	if(format_char == 'n')
		if(!add_thousands_grouping(buffer, buf_size))
			return NULL;

	return buffer;
}

}


#endif // __UTIL__HPP
