#ifndef _WIN32
#include <sys/resource.h>
#endif
// main.cpp
// ─────────────────────────────────────────────────────────────────────────────
// Nython interpreter entry point.
//
// COMPILATION FLAGS:
//   NYTHON_WITH_IDE=1  (default) — no-arg launch opens NythonIDE GUI
//   NYTHON_WITH_IDE=0            — no-arg launch opens terminal REPL
//
// Build IDE version (default):
//   make
// Build CLI-only version:
//   make NYTHON_WITH_IDE=0
// ─────────────────────────────────────────────────────────────────────────────
#include "NythonExecutor.hpp"
#include "ConsoleManager.hpp"
#include <algorithm>
#include <sstream>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

using namespace std;
using namespace nython;
using namespace nython::io;
using namespace nython::node;
using namespace nython::lexer;
using namespace nython::kernel;
using namespace nython::parser;
using namespace nython::reader;
using namespace nython::exception;

// Compile-time switch: IDE is enabled unless explicitly disabled
#ifndef NYTHON_WITH_IDE
#  define NYTHON_WITH_IDE 1
#endif

// ════════════════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════════════════

void print_header() {
    std::cout << "\n"
              << "\x1b[1;36m  _   _       _   _                 \x1b[0m\n"
              << "\x1b[1;36m | \\ | |     | | | |                \x1b[0m\n"
              << "\x1b[1;36m |  \\| |_   _| |_| |__   ___  _ __  \x1b[0m\n"
              << "\x1b[1;36m | . ` | | | | __| '_ \\ / _ \\| '_ \\ \x1b[0m\n"
              << "\x1b[1;36m | |\\  | |_| | |_| | | | (_) | | | |\x1b[0m\n"
              << "\x1b[1;36m |_| \\_|\\__, |\\__|_| |_|\\___/|_| |_|\x1b[0m\n"
              << "\x1b[1;36m         __/ |                       \x1b[0m\n"
              << "\x1b[1;36m        |___/                        \x1b[0m\n"
              << "\n"
              << "\x1b[1mNython " << NYTHON_VERSION << "\x1b[0m — AI-Powered Multi-Paradigm Language\n"
              << "Type \x1b[36mhelp\x1b[0m for commands, \x1b[36mexit\x1b[0m to quit. "
              << "Syntax: \x1b[33mPython\x1b[0m · \x1b[33mC/JS\x1b[0m · \x1b[33mLua\x1b[0m\n";
}

// Returns a process exit status: 0 on success, non-zero if the file could not
// be read, parsed or executed.
//
// This used to return void and swallow every error, printing a "[DBG ...]" line
// and exiting 0. Any harness that judged success by exit status — including this
// project's own example sweep — therefore counted files that failed to parse as
// passing.
// ─── Compiler diagnostics ────────────────────────────────────────────────────
// Syntax and lexing errors already carry a full Location (file, row, column);
// every report site printed only e.what() and threw that away, so the whole
// diagnostic was "Expected ParenClose, but found Var" with no indication of
// WHERE. On a 3,000-line file that is close to useless.
//
// Prints the standard file:line:column form, plus the offending source line
// with a caret under the column, the way every mainstream compiler does.
static void report_compiler_error(const std::string& kind,
                                  nython::lexer::Location loc,
                                  const std::string& message) {
    std::cerr << loc.filename << ":" << loc.row << ":" << loc.column
              << ": " << kind << ": " << message << "\n";

    // Echo the source line and point at the column. Best effort: if the file
    // cannot be re-read (stdin, a deleted temp) the message above still stands.
    std::ifstream in(loc.filename);
    if (in) {
        std::string line;
        uint32_t n = 0;
        while (n < loc.row && std::getline(in, line)) n++;
        if (n == loc.row) {
            std::cerr << "  " << line << "\n  ";
            for (uint32_t i = 1; i < loc.column && i < line.size() + 1; ++i)
                std::cerr << (line[i-1] == '\t' ? '\t' : ' ');
            std::cerr << "^\n";
        }
    }
}

int run_file(const std::string& filename, bool show_ast = false) {
    struct stat buf;
    if (stat(filename.c_str(), &buf) != 0) {
        std::cerr << "[Nython] No such file: " << filename << "\n";
        return 2;
    }
    try {
        auto source = SourceCode(filename);
        auto reporter = std::make_shared<Reporter>(source);
        auto lexer = std::make_shared<Lexer>(source);
        auto vm_ptr = std::make_shared<nython::vm::VirtualMachine>(reporter.get());
        auto parser = std::make_shared<Parser>(reporter.get(), (Runnable*)vm_ptr.get(), lexer.get());
        auto tokens = lexer->tokenize();
        auto ast = parser->parse();
        if (show_ast && ast) {
            nython::utils::PrettyPrinter pp;
            ast->writeToStdOut(pp);
            return 0;
        }


        NythonExecutor exec((Runnable*)vm_ptr.get());
        exec.execute(ast);
        // --profile: emit measured per-function counts and timings after the
        // program finishes. Delimited so a caller can separate the report from
        // the program's own stdout.
        if (NythonExecutor::profiling_enabled()) {
            std::cout << "__NY_PROFILE__\n" << exec.profile_report();
        }
    } catch (exception::UnexpectedCharError& e) {
        report_compiler_error("error", e.location(), e.message()); return 1;
    } catch (exception::SyntaxError& e) {
        report_compiler_error("syntax error", e.location(), e.message()); return 1;
    } catch (std::string& s) {
        // Nython raises uncaught exceptions as tagged std::string. Without this
        // handler they escaped main() and the process died via std::terminate
        // ("terminate called after throwing an instance of std::string").
        std::string msg = s;
        if (msg.rfind("__exc__:", 0) == 0) {
            msg = msg.substr(8);
            auto colon = msg.find(':');
            if (colon != std::string::npos)
                msg = msg.substr(0, colon) + ": " + msg.substr(colon + 1);
        }
        std::cerr << "[Nython] Uncaught exception — " << msg << "\n"; return 1;
    } catch (std::runtime_error& e) {
        std::cerr << "runtime error: " << e.what() << "\n"; return 1;
    } catch (std::exception& e) {
        std::cerr << "error: " << e.what() << "\n"; return 1;
    }
    return 0;
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: extract directory from argv[0], handling both / and \ separators.
// On Windows, uses GetModuleFileNameW to get the true exe path — argv[0]
// may be just "nython.exe" when launched by double-click or from a shortcut.
// ────────────────────────────────────────────────────────────────────────────
static std::string get_binary_dir(const char* argv0) {
#ifdef _WIN32
    // Get the full path of the running exe — reliable regardless of how launched
    wchar_t wpath[4096] = {};
    if (GetModuleFileNameW(nullptr, wpath, 4095) > 0) {
        // Convert UTF-16 → UTF-8
        char path[4096] = {};
        WideCharToMultiByte(CP_UTF8, 0, wpath, -1, path, sizeof(path)-1, nullptr, nullptr);
        std::string p = path;
        auto sep = p.rfind('\\');
        if (sep == std::string::npos) sep = p.rfind('/');
        if (sep != std::string::npos) return p.substr(0, sep);
        return ".";
    }
#endif
    // Fallback: parse argv[0]
    std::string p = argv0;
    auto slash = p.rfind('/');
    auto bslash = p.rfind('\\');
    auto sep = std::string::npos;
    if (slash != std::string::npos && bslash != std::string::npos)
        sep = std::max(slash, bslash);
    else if (slash != std::string::npos) sep = slash;
    else if (bslash != std::string::npos) sep = bslash;
    return (sep != std::string::npos) ? p.substr(0, sep) : ".";
}

// ────────────────────────────────────────────────────────────────────────────
// IDE launcher: runs nython_ide.ny via the VM
// Searches for the IDE file alongside the binary, then in CWD, then in
// examples/ and tests/
// ────────────────────────────────────────────────────────────────────────────
#if NYTHON_WITH_IDE
static bool launch_ide(const std::string& binary_dir) {
    // Use platform-appropriate separator
#ifdef _WIN32
    const std::string S = "\\";
#else
    const std::string S = "/";
#endif
    // Candidate paths for nython_ide.ny
    std::vector<std::string> candidates = {
        binary_dir + S + "nython_ide.ny",
        binary_dir + S + ".." + S + "nython_ide.ny",
        binary_dir + S + ".." + S + "examples" + S + "nython_ide.ny",
        "nython_ide.ny",
        "examples/nython_ide.ny",
        "examples\\nython_ide.ny",
        "../nython_ide.ny",
        "..\\nython_ide.ny",
    };
    std::string ide_path;
    for (auto& c : candidates) {
        struct stat sb;
        if (stat(c.c_str(), &sb) == 0) { ide_path = c; break; }
    }
    if (ide_path.empty()) {
        std::string msg = "[Nython] nython_ide.ny not found.\n\n"
                          "Searched in:\n  " + binary_dir + "\\\n  (current directory)\n\n"
                          "Make sure nython_ide.ny and the lib\\ folder\n"
                          "are in the same folder as nython.exe.";
#ifdef _WIN32
        MessageBoxA(nullptr, msg.c_str(), "NythonIDE — File Not Found", MB_OK | MB_ICONWARNING);
#else
        std::cerr << msg << "\n";
#endif
        return false;
    }
    try {
        auto source = SourceCode(ide_path);
        auto reporter = std::make_shared<Reporter>(source);
        auto lexer2   = std::make_shared<Lexer>(source);
        auto vm2      = std::make_shared<nython::vm::VirtualMachine>(reporter.get());
        auto parser2  = std::make_shared<Parser>(reporter.get(), (Runnable*)vm2.get(), lexer2.get());
        lexer2->tokenize();
        auto ast = parser2->parse();
        // ── CRITICAL ────────────────────────────────────────────────────────
        // Execute the IDE through NythonExecutor, NOT through vm2->run(ast).
        //
        // The bytecode VM (VirtualMachine.hpp) registers only a subset of
        // builtins as natives (print/len/time_ms/json_encode/...). It knows
        // NOTHING about the module dispatch chain in NythonExecutor::callBuiltin,
        // so every gui_* and lang_* call inside the VM silently evaluated to
        // `none`. That made gui_create_window() return none WITHOUT ever
        // reaching SDL_CreateWindow, and gui_sdl_version() return none — which
        // is what produced the bogus
        //     "Window creation failed (SDL3 none is loaded)"
        // message blaming GPU drivers for what was really a missing builtin.
        //
        // run_file() already uses NythonExecutor; the IDE must use it too.
        if (ast) {
            NythonExecutor exec((Runnable*)vm2.get());
            exec.execute(ast);
        }
        return true;
    } catch (std::exception& e) {
        std::string msg = std::string("[IDE Error] ") + e.what();
#ifdef _WIN32
        MessageBoxA(nullptr, msg.c_str(), "NythonIDE — Runtime Error", MB_OK | MB_ICONERROR);
#else
        std::cerr << msg << "\n";
#endif
        return false;
    }
}
#endif // NYTHON_WITH_IDE

// ────────────────────────────────────────────────────────────────────────────
// Terminal REPL
// ────────────────────────────────────────────────────────────────────────────
void repl() {
    auto reporter_src = SourceCode(std::string("<repl>"));
    auto reporter = std::make_shared<Reporter>(reporter_src);
    auto vm_ptr = std::make_shared<nython::vm::VirtualMachine>(reporter.get());
    NythonExecutor exec((Runnable*)vm_ptr.get());

    // Non-interactive mode: read from pipe/redirect
    if (!isatty(STDIN_FILENO)) {
        std::string all_code;
        {
            char buf[4096];
            while (true) {
                ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
                if (n <= 0) break;
                all_code.append(buf, n);
            }
        }
        // Strip exit/quit lines
        {
            std::string cleaned;
            size_t pos = 0;
            while (pos < all_code.size()) {
                size_t nl = all_code.find('\n', pos);
                std::string ln = (nl == std::string::npos) ? all_code.substr(pos) : all_code.substr(pos, nl - pos);
                auto t = ln.find_first_not_of(" \t\r");
                std::string trimmed = (t != std::string::npos) ? ln.substr(t) : "";
                if (trimmed != "exit" && trimmed != "quit" && trimmed != "exit()" && trimmed != "quit()") {
                    if (!cleaned.empty()) cleaned += "\n";
                    cleaned += ln;
                }
                if (nl == std::string::npos) break;
                pos = nl + 1;
            }
            all_code = cleaned;
        }
        if (all_code.empty()) return;
        try {
            auto src = SourceCode(all_code);
            auto rep = std::make_shared<Reporter>(src);
            auto lex = std::make_shared<Lexer>(src);
            lex->tokenize();
            auto par = std::make_shared<Parser>(rep.get(), (Runnable*)vm_ptr.get(), lex.get());
            auto ast = par->parse();
            if (ast) {
                Value val = exec.execute(ast);
                if (val.type != ValueType::NONE && val.type != ValueType::UNDEFINED) {
                    exec.printValue(val);
                    std::cout << std::endl;
                }
            }
        } catch (exception::SyntaxError& se) {
            std::cerr << "SyntaxError: " << se.what() << std::endl;
        } catch (std::string& err) {
            std::cerr << "Error: " << err << std::endl;
        } catch (std::exception& ex) {
            std::cerr << "Error: " << ex.what() << std::endl;
        } catch (...) {
            std::cerr << "Unknown error" << std::endl;
        }
        return;
    }

    // Interactive REPL
    print_header();
    nython::repl_engine::MultilineCollector collector;
    std::cout << "\n";

    while (true) {
        std::string code;
        auto result = collector.collect(code);
        if (result == nython::repl_engine::MultilineCollector::EXIT_REQ) break;
        if (result == nython::repl_engine::MultilineCollector::CANCEL) continue;
        if (result == nython::repl_engine::MultilineCollector::EMPTY) continue;

        auto s = code.find_first_not_of(" \t\r\n");
        if (s == std::string::npos) continue;
        code = code.substr(s);
        auto e = code.find_last_not_of(" \t\r\n");
        if (e != std::string::npos) code = code.substr(0, e + 1);

        if (code == "exit" || code == "quit" || code == "exit()" || code == "quit()") break;
        if (code == "help" || code == "help()") {
            std::cout << "\x1b[1mNython " << NYTHON_VERSION << "\x1b[0m — AI-Powered Multi-Paradigm Language\n\n"
                      << "  \x1b[36mCommands:\x1b[0m  exit, help, version, clear\n"
                      << "  \x1b[36mSyntax:\x1b[0m    Python (colon+indent), C/JS (braces), Lua (do/end)\n"
                      << "  \x1b[36mKeys:\x1b[0m      Up/Down=history, Ctrl+C=cancel, Ctrl+D=exit\n"
                      << "             Ctrl+L=clear, Ctrl+A=home, Ctrl+E=end, Tab=indent\n"
                      << "  \x1b[36mMultiline:\x1b[0m Lines ending with : { or do auto-continue\n"
                      << "             Empty line submits the block\n\n";
            continue;
        }
        if (code == "version") { std::cout << "Nython " << NYTHON_VERSION << "\n"; continue; }
        if (code == "clear") { std::cout << "\x1b[2J\x1b[H"; continue; }
#if NYTHON_WITH_IDE
        if (code == "ide") {
            std::cout << "Launching NythonIDE...\n";
            launch_ide(".");
            continue;
        }
#endif

        try {
            auto src = SourceCode(code);
            auto rep = std::make_shared<Reporter>(src);
            auto lex = std::make_shared<Lexer>(src);
            lex->tokenize();
            auto par = std::make_shared<Parser>(rep.get(), (Runnable*)vm_ptr.get(), lex.get());
            auto ast = par->parse();
            if (ast) {
                Value val = exec.execute(ast);
                if (val.type != ValueType::NONE && val.type != ValueType::UNDEFINED) {
                    std::string repr;
                    if (val.type == ValueType::INTEGER) repr = val.value.i.toString();
                    else if (val.type == ValueType::DOUBLE) {
                        std::ostringstream oss; oss << val.value.d; repr = oss.str();
                    }
                    else if (val.type == ValueType::BOOLEAN) repr = val.value.b ? "true" : "false";
                    else if (val.type == ValueType::USERDATA && val.value.p) {
                        repr = "\x1b[33m'" + exec.getStringValue(val) + "'\x1b[0m";
                    }
                    else if (val.type == ValueType::COLLECTABLE) {
                        std::vector<Value> sa = {val};
                        Value sv = exec.callBuiltin("str", sa, exec.global_ctx);
                        repr = exec.getStringValue(sv);
                    }
                    if (!repr.empty()) std::cout << "\x1b[90m" << repr << "\x1b[0m" << std::endl;
                }
            }
        } catch (exception::SyntaxError& se) {
            std::cout << "\x1b[31mSyntaxError:\x1b[0m " << se.what() << "\n";
        } catch (std::string& err) {
            if (err == "break" || err == "continue")
                std::cout << "\x1b[31mSyntaxError:\x1b[0m '" << err << "' outside loop\n";
            else
                std::cout << "\x1b[31mError:\x1b[0m " << err << "\n";
        } catch (nython::node::ReturnSignal&) {
            std::cout << "\x1b[31mSyntaxError:\x1b[0m 'return' outside function\n";
        } catch (std::runtime_error& re) {
            std::cout << "\x1b[31mRuntimeError:\x1b[0m " << re.what() << "\n";
        } catch (std::exception& ex) {
            std::cout << "\x1b[31mError:\x1b[0m " << ex.what() << "\n";
        } catch (...) {
            std::cout << "\x1b[31mUnknown error\x1b[0m\n";
        }
    }
    std::cout << "\x1b[1mGoodbye!\x1b[0m\n";
}

// ════════════════════════════════════════════════════════════════════════════
// main
// ════════════════════════════════════════════════════════════════════════════

// ── VM -> interpreter builtin bridge ─────────────────────────────────────────
// The bytecode VM implements a small set of natives; the interpreter registers
// 536. This converts values between the two representations so a program run
// with --vm can call the whole standard library.
namespace {

using nython::vm::VMVal;
using nython::vm::VMType;

VMVal value_to_vm(const Value& v, NythonExecutor& exec);

Value vm_to_value(const VMVal& v, NythonExecutor& exec) {
    switch (v.type) {
        case VMType::NONE:   return NONE_VALUE;
        case VMType::BOOL:   return Value(v.b);
        case VMType::INT:    return Value((int64_t)v.i);
        case VMType::FLOAT:  return Value(v.d);
        case VMType::STRING: return exec.makeStringValue(v.s);
        case VMType::LIST: {
            auto* lst = new Object((Runnable*)exec.runner, "list", Type::LIST);
            int n = 0;
            if (v.list) for (auto& e : *v.list) lst->set(std::to_string(n++), vm_to_value(e, exec));
            lst->set("__len__", Value(n));
            return Value(static_cast<Collectable*>(lst));
        }
        case VMType::MAP: {
            auto* mp = new Object((Runnable*)exec.runner, "map", Type::MAP);
            if (v.map) for (auto& kv : *v.map) mp->set(kv.first, vm_to_value(kv.second, exec));
            return Value(static_cast<Collectable*>(mp));
        }
        default: return NONE_VALUE;
    }
}

VMVal value_to_vm(const Value& v, NythonExecutor& exec) {
    if (exec.isStringValue(v)) return VMVal::make_str(exec.getStringValue(v));
    switch (v.type) {
        case ValueType::NONE:    return VMVal::make_none();
        case ValueType::BOOLEAN: return VMVal::make_bool(v.value.b);
        case ValueType::INTEGER: return VMVal::make_int(bigint_to_i64(v.value.i));
        case ValueType::DOUBLE:  return VMVal::make_float((double)v.value.d);
        default: break;
    }
    // Containers: a list carries "__len__" and numeric keys, a map does not.
    // The collectable lives in Value::value.gc, not value.p — reading the wrong
    // union member made every container convert to none, so bridged builtins
    // that return a list or map (os_listdir, fs_stat, ...) came back empty.
    auto* c = dynamic_cast<Container*>(as_collectable(v));
    if (c && c->container) {
        auto len_it = c->container->find("__len__");
        if (len_it != c->container->end()) {
            std::vector<VMVal> out;
            int n = (int)bigint_to_i64(len_it->second.value.i);
            for (int i = 0; i < n; i++) {
                auto it = c->container->find(std::to_string(i));
                out.push_back(it == c->container->end() ? VMVal::make_none()
                                                        : value_to_vm(it->second, exec));
            }
            return VMVal::make_list(std::move(out));
        }
        VMVal m = VMVal::make_map();
        for (auto& kv : *c->container) (*m.map)[kv.first] = value_to_vm(kv.second, exec);
        return m;
    }
    return VMVal::make_none();
}

// Kept alive for the process: the bridge closures capture it.
std::shared_ptr<NythonExecutor> g_bridge_exec;

void install_vm_builtin_bridge(Runnable* runner) {
    if (g_bridge_exec) return;
    g_bridge_exec = std::make_shared<NythonExecutor>(runner);
    NythonExecutor* ex = g_bridge_exec.get();
    nython::vm::VirtualMachine::bridge_exists() = [ex](const std::string& n) {
        return ex->hasBuiltin(n);
    };
    nython::vm::VirtualMachine::bridge_call() =
        [ex](const std::string& n, std::vector<VMVal>& a) -> VMVal {
            std::vector<Value> args;
            args.reserve(a.size());
            for (auto& v : a) args.push_back(vm_to_value(v, *ex));
            Value r = ex->callBuiltin(n, args, ex->globalContext());
            return value_to_vm(r, *ex);
        };
}

} // namespace


int main(int argc, char** argv, char** env) {
    try {
        setlocale(LC_ALL, "");
        nython::ConsoleManager cm; cm.setupConsole();

        if (argc >= 2) {
            std::string arg1 = argv[1];

            // ── Version / Help ───────────────────────────────────────────
            if (arg1 == "--version" || arg1 == "-v") {
                std::cout << "Nython " << NYTHON_VERSION;
#if NYTHON_WITH_IDE
                std::cout << " (IDE build)";
#else
                std::cout << " (CLI build)";
#endif
                std::cout << "\n";
                return 0;
            }
            if (arg1 == "--help" || arg1 == "-h") {
                std::cout
                    << "Usage: nython [options] [script.ny]\n\n"
                    << "Options:\n"
                    << "  -v, --version      Show version and build type\n"
                    << "  -h, --help         Show this help\n"
                    << "  -t, --tokenize     Tokenize file and dump tokens\n"
                    << "  -a, --ast          Show AST for file\n"
                    << "  --vm <file>        Run script via Bytecode VM\n"
                    << "  -d, --disasm       Disassemble file to bytecode listing\n"
                    << "  -p, --profile      Run with the profiler; measured per-function timings\n"
                    << "  --ide              Launch NythonIDE GUI\n"
                    << "  --console          Force terminal REPL (no GUI, shows all output)\n"
                    << "  --cli, --repl      Same as --console\n"
                    << "  <file>             Run script (tree-walk interpreter)\n"
#if NYTHON_WITH_IDE
                    << "\nWhen launched with no arguments, NythonIDE opens automatically.\n"
                    << "Use --cli to force the terminal REPL instead.\n"
#endif
                    ;
                return 0;
            }

            // ── CLI / REPL override ──────────────────────────────────────
            if (arg1 == "--cli" || arg1 == "--repl" || arg1 == "--console") {
                repl();
                return 0;
            }

            // ── IDE launch ───────────────────────────────────────────────
#if NYTHON_WITH_IDE
            if (arg1 == "--ide") {
                launch_ide(get_binary_dir(argv[0]));
                return 0;
            }
#endif

            // ── Tokenize ─────────────────────────────────────────────────
            if ((arg1 == "--tokenize" || arg1 == "-t") && argc >= 3) {
                auto source = SourceCode(std::string(argv[2]));
                auto lex = std::make_shared<Lexer>(source);
                lex->tokenize(); std::cout << lex->toString(); return 0;
            }

            // ── AST dump ─────────────────────────────────────────────────
            if ((arg1 == "--ast" || arg1 == "-a") && argc >= 3) {
                return run_file(argv[2], true);
            }

            // ── Bytecode VM ──────────────────────────────────────────────
            if (arg1 == "--vm" && argc >= 3) {
                try {
                    auto source = SourceCode(std::string(argv[2]));
                    auto reporter = std::make_shared<Reporter>(source);
                    auto lexer2 = std::make_shared<Lexer>(source);
                    auto vm2 = std::make_shared<nython::vm::VirtualMachine>(reporter.get());
                    // Imports must resolve relative to the script, not the
                    // working directory — and must do so on BOTH engines. The
                    // interpreter already did; without this the same file's
                    // imports resolved under one engine and failed under the
                    // other.
                    vm2->set_script_dir(std::string(argv[2]));
                    auto parser2 = std::make_shared<Parser>(reporter.get(), (Runnable*)vm2.get(), lexer2.get());
                    install_vm_builtin_bridge((Runnable*)vm2.get());
                    lexer2->tokenize();
                    auto ast = parser2->parse();
                    if (ast) vm2->run(ast);
                } catch (exception::SyntaxError& e) {
                    // The VM compiler rejects some constructs the interpreter
                    // accepts. Report it rather than letting the exception
                    // escape main() and abort the process via std::terminate.
                    report_compiler_error("syntax error", e.location(), e.message()); return 1;
                } catch (exception::UnexpectedCharError& e) {
                    report_compiler_error("error", e.location(), e.message()); return 1;
                } catch (std::string& msg) {
                    std::cerr << "VM Error: " << msg << "\n"; return 1;
                } catch (std::exception& e) {
                    std::cerr << "VM Error: " << e.what() << "\n"; return 1;
                }
                return 0;
            }

            // ── Disassemble ──────────────────────────────────────────────
            if ((arg1 == "--profile" || arg1 == "-p") && argc >= 3) {
                NythonExecutor::profiling_enabled() = true;
                return run_file(argv[2]);
            }

            if ((arg1 == "--disasm" || arg1 == "-d") && argc >= 3) {
                try {
                    auto source = SourceCode(std::string(argv[2]));
                    auto reporter = std::make_shared<Reporter>(source);
                    auto lexer2 = std::make_shared<Lexer>(source);
                    auto vm2 = std::make_shared<nython::vm::VirtualMachine>(reporter.get());
                    auto parser2 = std::make_shared<Parser>(reporter.get(), (Runnable*)vm2.get(), lexer2.get());
                    lexer2->tokenize();
                    auto ast = parser2->parse();
                    if (ast) {
                        auto code = vm2->compile_ast(ast);
                        std::cout << vm2->disassemble(*code);
                    }
                } catch (std::exception& e) {
                    std::cerr << "Disasm Error: " << e.what() << "\n"; return 1;
                }
                return 0;
            }

            // ── Run script (tree-walk) ───────────────────────────────────
            return run_file(arg1);

        } else {
            // No arguments: launch IDE (if built with IDE support) or REPL
#if NYTHON_WITH_IDE
            // Determine binary directory for IDE file lookup
            if (!launch_ide(get_binary_dir(argv[0]))) {
                // IDE file not found — fall back to REPL
                repl();
            }
#else
            repl();
#endif
        }

        cm.restoreConsole();
    } catch (std::exception& e) {
        std::string msg = std::string("Fatal error: ") + e.what();
#ifdef _WIN32
        MessageBoxA(nullptr, msg.c_str(), "Nython — Fatal Error", MB_OK | MB_ICONERROR);
#else
        std::cerr << msg << std::endl;
#endif
        return 1;
    }
    return 0;
}
