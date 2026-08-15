///============================================================================
/// Nython Programming Language — Master Header
/// Copyright (c) 2017-2026 Litet Li Mbeleg Perrin
/// MIT License — See LICENSE for details
///============================================================================
/// This is the single unified header for the Nython language implementation.
/// It provides all forward declarations, platform abstractions, and core types
/// needed by every translation unit.
///============================================================================
#ifndef NYTHON_HPP
#define NYTHON_HPP

// ─── Standard Library ───────────────────────────────────────────────────────
#include <map>
#include <set>
#include <cmath>
#include <mutex>
#include <regex>
#include <stack>
#include <atomic>
#include <string>
#include <memory>
#include <vector>
#include <thread>
#include <chrono>
#include <cctype>
#include <cfloat>
#include <locale>
#include <cerrno>
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <numeric>
#include <utility>
#include <iostream>
#include <iterator>
#include <stdarg.h>
#include <algorithm>
#include <exception>
#include <stdexcept>
#include <functional>
#include <type_traits>
#include <unordered_map>
#include <unordered_set>
#include <initializer_list>

// Platform detection on systems without sys/stat.h etc
#if defined(_WIN32) || defined(_WIN64) || defined(__WIN32__)
  #define NYTHON_OS_WINDOWS 1
#elif defined(__linux__) || defined(__gnu_linux__)
  #define NYTHON_OS_LINUX 1
#elif defined(__APPLE__)
  #define NYTHON_OS_APPLE 1
#else
  #define NYTHON_OS_UNKNOWN 1
#endif

// ─── Version ────────────────────────────────────────────────────────────────
#ifndef NYTHON_VERSION
  #define NYTHON_VERSION "0.2.0"
#endif

// ─── Exit Codes ─────────────────────────────────────────────────────────────
#define NYTHON_EXIT_OK          0
#define NYTHON_EXIT_USAGE       64
#define NYTHON_EXIT_DATAERR     65
#define NYTHON_EXIT_SOFTWAREERR 70
#define NYTHON_EXIT_OSERR       71
#define NYTHON_EXIT_IOERR       74
#define NYTHON_EXIT_CONFIG      78

// ─── Utility Macros ─────────────────────────────────────────────────────────
#define DISALLOW_COPY_AND_ASSIGN(Cls) \
    Cls(const Cls&) = delete;         \
    Cls& operator=(const Cls&) = delete;

// ─── Long double alias ─────────────────────────────────────────────────────
typedef long double ldouble;

// ─── Forward Declarations ───────────────────────────────────────────────────
namespace nython {

    // Garbage collector
    namespace gc {
        class Collectable;
        class GarbageCollector;
    }

    // Lexer subsystem
    namespace lexer {
        struct Location;
        struct Token;
        struct Lexer;
    }

    // Reader subsystem
    namespace reader {
        class SourceCode;
    }

    // Kernel (runtime types)
    namespace kernel {
        class  bigint;
        struct Value;
        struct Object;
        struct Class;
        struct Context;
        struct Container;
        struct Function;
        struct Method;
        struct Lambda;
        struct String;
        struct List;
        struct Tuple;
        struct Array;
        struct Map;
        struct Set;
    }

    // AST nodes
    namespace node {
        struct Node;
        struct Script;
        using node_ptr = std::shared_ptr<Node>;
    }

    // Parser
    namespace parser {
        class Parser;
    }

    // Visitor
    namespace visitor {
        struct IVisitor;
    }

    // Exception hierarchy
    namespace exception {
        class Exception;
        class Error;
        class Reporter;
        class ReporterAware;
        struct UnexpectedCharError;
        class SyntaxError;
        class RuntimeError;
    }

    // VM
    namespace vm {
        class VirtualMachine;
    }

    // Interpreter
    namespace interpreter {
        struct Interpreter;
    }

    // Runnable (interface for VM and Interpreter)
    class Runnable;
}

#endif // NYTHON_HPP
