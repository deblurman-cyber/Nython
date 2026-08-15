#ifndef NYTHON_CLIFLAGS_HPP
#define NYTHON_CLIFLAGS_HPP
#include "Definitions.hpp"
#include "Runflags.hpp"

namespace nython {

struct CliFlags {
    std::string filename{};
    std::string code{};
    bool interactive = false;
    bool version = false;
    bool help = false;
    bool debug = false;
    bool verbose = false;
    bool compile = false;
    bool disassemble = false;
    bool tokenize = false;
    bool parse_only = false;
    bool ast_dump = false;
    std::vector<std::string> args{};

    static CliFlags parse(int argc, char** argv) {
        CliFlags flags;
        for (int i = 1; i < argc; i++) {
            std::string arg = argv[i];
            if (arg == "-h" || arg == "--help") flags.help = true;
            else if (arg == "-v" || arg == "--version") flags.version = true;
            else if (arg == "-i" || arg == "--interactive") flags.interactive = true;
            else if (arg == "-d" || arg == "--debug") flags.debug = true;
            else if (arg == "--verbose") flags.verbose = true;
            else if (arg == "-c" || arg == "--compile") flags.compile = true;
            else if (arg == "--disassemble") flags.disassemble = true;
            else if (arg == "--tokenize") flags.tokenize = true;
            else if (arg == "--parse") flags.parse_only = true;
            else if (arg == "--ast") flags.ast_dump = true;
            else if (arg == "-e" && i + 1 < argc) flags.code = argv[++i];
            else if (arg[0] != '-') {
                if (flags.filename.empty()) flags.filename = arg;
                else flags.args.push_back(arg);
            }
        }
        if (flags.filename.empty() && flags.code.empty() && !flags.version && !flags.help)
            flags.interactive = true;
        return flags;
    }

    static void printHelp() {
        std::cout << "Nython " << NYTHON_VERSION << " — AI-Powered Multi-Paradigm Programming Language\n\n"
                  << "Usage: nython [options] [script] [args...]\n\n"
                  << "Options:\n"
                  << "  -h, --help         Show this help\n"
                  << "  -v, --version      Show version\n"
                  << "  -i, --interactive  Start REPL\n"
                  << "  -e <code>          Execute code string\n"
                  << "  -d, --debug        Enable debug mode\n"
                  << "  -c, --compile      Compile to bytecode\n"
                  << "  --tokenize         Show token stream\n"
                  << "  --parse            Parse only (show AST)\n"
                  << "  --ast              Dump AST\n"
                  << "  --disassemble      Show bytecode\n"
                  << "  --verbose          Verbose output\n";
    }
};

} // namespace nython
#endif
