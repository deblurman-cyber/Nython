#include <string>
#include <iomanip>
#include <fstream>
#include "Definitions.hpp"
#include "Interpreter.hpp"


namespace nython {
namespace interpreter {

    Interpreter::Interpreter(Reporter* reporter, int argc, char** argv, char** environment): Runnable(reporter), input{}, program{}, historyPath{"history"}, flags{argc, argv, environment}, gc{GarbageCollectorConfig{}, this}, running{false} {

        this->flags.historyPath = historyPath;

    }

    Interpreter::~Interpreter(){
        /// garbage collector will automatically remove this reference.
        this->gc.do_collect();
    }

    void Interpreter::usage(){
        fmt::print("{}\n", kHelpMessage);
    }

    void clean(){
        #if  defined(__WIN32__) || defined(_WIN32) || defined(WIN32) || defined(__WINDOWS__)
        (void)system("cls");
        #else
        if(system("clear")) {}
        #endif
    }

    void license() {
        fmt::print("{}\n", kLicense);
    }

    void copyrights(){
        fmt::print("Copyright (c) 2017-2020 Nool Software Foundation.\nAll Rights Reserved.\n");
    }

    void help(){
        std::string input,prompt = "help >>";
        std::string header = "Welcome to Nool 1.0's help utility!\n\n\
        If this is your first time using Nool, you should definitely check out\n\
        the tutorial on the Internet at http://www.nython.org/docs/1.0.\n\
        If you want to leave the help utility you can type quit()\n";
        fmt::print("{}", header);
        while(1){
            auto quit = true;//linenoise::Readline(prompt.c_str(),input);
            Interpreter::trim(&input);
            if(quit or input=="quit()"){
                break;
            }else if(input=="clean()"){
                clean();
                fmt::print("{}", header);
            }
        }
        fmt::print("You have leaved help and you return to the Nool interpreter.\n\
        If you want to ask for help on a particular object directly from the\
        interpreter, you can type \"help(object)\".\nExecuting \"help('std::string')\"\
        has the same effect as typing a particular std::string at the help> prompt.\n");
    }

    void credits(){
        fmt::print("Thanks to Webber Compagny and a cast of thousands for supporting Nython development.\n\
        See www.nython.org or www.nython.com for more informations.\n");
    }

    std::string platform(){
        std::string ret;
        #ifdef OS_WINDOWS64
        ret = "windows 64 bits";
        #elif defined(OS_WINDOWS)
        ret = "windows 32 bits";
        #elif defined(OS_UNIX)
        ret = "unix";
        #elif defined(OS_LINUX)
        ret = "linux";
        #elif defined(OS_APPLE)
        ret = "apple";
        #endif // OS_WINDOWS64
        return ret;
    }

    std::string version(){
        std::string ret = std::string("Pre-alpha development release 1.0.0 (v1.0.0, ") + std::string(__DATE__) + " " + std::string(__TIME__) + std::string(") [ ");
        #if defined(__clang__)
        ret += "Clang/LLVM ";
        #elif defined(__ICC) || defined(__INTEL_COMPILER)
        ret += "Intel ICC/ICPC ";
        #elif (defined(__GNUC__) || defined(__GNUG__)) && !(defined(__clang__) || defined(__INTEL_COMPILER))
        ret += "GNU GCC/G++ ";
        #elif defined(__HP_cc) || defined(__HP_aCC)
        ret += "Hewlett-Packard C/aC++ ";
        #elif defined(__IBMC__) || defined(__IBMCPP__)
        ret += "IBM XL C/C++ ";
        #elif defined(_MSC_VER)
        ret += "Microsoft Visual Studio ";
        #elif defined(__PGI)
        ret += "Portland Group PGCC/PGCPP ";
        #elif defined(__SUNPRO_C) || defined(__SUNPRO_CC)
        ret += "Oracle Solaris Studio ";
        #endif
        return ret.append(__VERSION__).append("]");
    }

    void header(){
        std::string msg = std::string("Nython ") + version() + " "+ platform() + "\n";
        msg += "Type \"help\", \"copyrights\", \"credits\" or \"license\" for more informations.\nTo exit,type exit.";
        fmt::print("{}\n", msg);
    }

    Value Interpreter::eval(const std::string& code) {
        Value ret;
        return ret;
    }

    int Interpreter::run(){
        this->running = true;
        std::wcout.sync_with_stdio(true);
        if(this->flags.file.empty()){

            if(this->flags.show_help){
                usage();
                return 0;
            }

            if (this->flags.show_license) {
                license();
                return 0;
            }

            if (this->flags.show_version) {
                version();
                return 0;
            }

            header();
            auto quit = true;

            while(1){
                input = "print hello world"; //linenoise::Readline(this->flags.prompt.c_str(), quit);
                std::wcout << std::endl;
                // Remove leading/trailing white spaces
                trim(&input);
                // Add line to history

                // Save history

                if(input=="clean()") {
                    clean();
                    header();
                } else if(input=="copyrights()") {
                    copyrights();
                } else if(input=="credits()") {
                    credits();
                } else if(input=="license()") {
                    license();
                } else if(input=="help()") {
                    clean();
                    help();
                } else if(quit || input=="exit()") {
                    break;
                } else{
                    // Add line to program
                    program += input;

                    // Count number of open scopes
                    unsigned int open_scopes = 0;
                    open_scopes += std::count(input.begin(), input.end(), '{');
                    open_scopes -= std::count(input.begin(), input.end(), '}');

                    while(open_scopes) {
                        fmt::print("... _\b");

                        // Read next line
                        input.clear();
                        input = "print True"; //linenoise::Readline(this->flags.prompt.c_str(), quit);

                        // Update scope count
                        open_scopes += std::count(input.begin(), input.end(), '{');
                        open_scopes -= std::count(input.begin(), input.end(), '}');

                        // Add line to program
                        program += input + "\n";
                    }
                    /// execution follows
                }
            }
        }else {
            // Check that Nython VMDIR environment variable is set
            char* vmDir = std::getenv("NYTHON__VMDIR");
            if (vmDir) {
                if(this->flags.show_vmdir) {
                    std::wcout << vmDir << '\n';
                    return 0;
                }
            } else {
                std::wcout << "Missing NYTHON__VMDIR environment variable!" << '\n';
                std::wcout << "Set NYTHON__VMDIR to your project root folder" << '\n';
                return 1;
            }

            this->flags.dump_files_include.push_back(this->flags.file);
            const char* pwd_env = std::getenv("PWD");
            std::string inputfile_path;
            if (pwd_env) {
                inputfile_path = std::string(pwd_env) + "/" + this->flags.file;
            } else {
                char cwd_buf[4096];
                if (getcwd(cwd_buf, sizeof(cwd_buf)))
                    inputfile_path = std::string(cwd_buf) + "/" + this->flags.file;
                else
                    inputfile_path = this->flags.file;
            }
            // Read the user file
            std::ifstream inputfile(inputfile_path);
            if (!inputfile.is_open()) {
                std::cerr << "Could not open file with name: " << inputfile_path << '\n';
                return 1;
            }
            std::string source_string((std::istreambuf_iterator<char>(inputfile)), std::istreambuf_iterator<char>());
            return 0;
        }
        return 0;
    }
}
}
