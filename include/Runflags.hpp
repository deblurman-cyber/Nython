#ifndef __RUN__FLAGS__HPP
#define __RUN__FLAGS__HPP

#include <vector>
#include <string>
#include <cstdlib>
#include <algorithm>
#include "Except.hpp"
#include <unordered_map>


namespace nython {
namespace interpreter {

const std::string kEnvironmentStringDelimiter = "=";

struct RunFlags {

    // All arguments and flags passed to the program
    std::vector<std::string> flags;
    std::vector<std::string> arguments;
    std::vector<std::string> dump_files_include;
    std::unordered_map<std::string, std::string> environment;


    // Parsed flags
    bool show_help           = false;
    bool show_version        = false;
    bool show_license        = false;
    bool show_vmdir          = false;
    bool dump_tokens         = false;/// -t -tokens
    bool dump_ast            = false;/// -ast -a
    bool dump_asm            = false;/// -asm -as
    bool skip_execution      = false;/// -skipexec
    bool instruction_profile = false;/// -ip
    bool trace_gc            = false;/// -gc
    bool allow_compilation   = false;/// -c
    bool allow_multilines    = true;/// -ml

    std::string historyPath = "history";///(-hp) the path where we store what is written in the command line tool
    std::string prompt 	    = ">>> _";///(-pr)the prompt
    std::string executable  = "nython";/// the interpreter
    std::string file   	    = "";///(-f) the nython script file
    std::string cacheDir    = "nython-cache";/// this is where compile files will be stock
    int historyMaxLength    = 20;

    RunFlags(int argc, char** argv, char** envp): flags{}, arguments{}, dump_files_include{}, environment{} {
        /// set executable name
        int pos = 0;
		if(argc) executable = argv[0];
		if((pos = executable.find_last_of("."))!=-1) executable = executable.substr(0,pos);

		// Parse environment variables
        for (char** current = envp; *current; current++) {
          std::string envstring(*current);
          size_t string_delimiter_index = envstring.find(kEnvironmentStringDelimiter);
          std::string key(envstring, 0, string_delimiter_index);
          std::string value(envstring, string_delimiter_index + 1, std::string::npos);
          this->environment[key] = value;
        }
         // If no arguments were passed we can safely skip the rest of this code
        // It only parses arguments and flags
        if (argc == 1) return;

        bool append_to_flags = false;
        bool append_to_dump_files_include = false;
        bool argument_parser_active = true;

        auto append_flag = [&](const std::string& flag) {
          if (!flag.compare("dump_ast"))
            this->dump_ast = true;
          if (!flag.compare("dump_tokens"))
            this->dump_tokens = true;
          if (!flag.compare("dump_asm"))
            this->dump_asm = true;
          if (!flag.compare("compile"))
            this->allow_compilation = true;
          if (!flag.compare("multiple-lines"))
            this->allow_multilines = true;
          if (!flag.compare("skipexec"))
            this->skip_execution = true;
          if (!flag.compare("trace_gc"))
            this->trace_gc = true;
          if (!flag.compare("show-vmdir"))
            this->show_vmdir = true;
          if (!flag.compare("instruction_profile"))
            this->instruction_profile = true;
          if (!flag.compare("dump_file_include"))
            append_to_dump_files_include = true;
          this->flags.push_back(flag);
        };

        // Extract all arguments
        for (int argi = 1; argi < argc; argi++) {
          std::string arg(argv[argi]);

          // After the '--' token has been parsed, the argument parser
          // will store all remaining arguments into the arguments array,
          // ignoring any flags that may be special to Nython
          if (!argument_parser_active) {
            this->arguments.push_back(arg);
            continue;
          }

          // If this argument comes after a flag, append it to the flags
          //
          // This would be parsed in one step
          // -fexample
          //
          // This would be parsed in two steps
          // -f example
          if (append_to_flags) {
            append_flag(arg);
            append_to_flags = false;
            continue;
          }

          // Add a filename to the dump_file_include list
          //
          // -fdump_file_include file.ch
          if (append_to_dump_files_include) {
            this->dump_files_include.push_back(arg);
            append_to_dump_files_include = false;
            continue;
          }

          // Check if there are enough characters for this argument
          // to be a single character flag
          if (arg.size() == 1) {
            this->arguments.push_back(arg);
            continue;
          }

          // Check single character flags like -h, -v etc.
          if (arg.size() == 2) {

            // '--' terminates the argument parser, all remaining arguments
            // are added as is to the argument list
            if (arg[0] == '-' && arg[1] == '-') {
              argument_parser_active = false;
              continue;
            }

            bool found_flag = false;
            switch(arg[1]) {
              case 'h': {
                this->show_help = true;
                found_flag = true;
                break;
              }
              case 'v': {
                this->show_version = true;
                found_flag = true;
                break;
              }
              case 'l': {
                this->show_license = true;
                found_flag = true;
                break;
              }
              case 'f': {
                append_to_flags = true;
                found_flag = true;
                break;
              }
              case 'c': {
                append_to_flags = true;
                found_flag = true;
                break;
              }
              case 't': {
                append_to_flags = true;
                found_flag = true;
                break;
              }
              case 'a': {
                append_to_flags = true;
                found_flag = true;
                break;
              }
              default: break;
            }
              continue;
            if (found_flag)
              continue;
          }

          // Multiple character flags
          if (arg.size() > 2) {
            if (arg[0] == '-' && arg[1] == '-') {
              bool found_flag = false;

              if (!arg.compare("--help")) {
                this->show_help = true;
                found_flag = true;
              }
              if (!arg.compare("--version")) {
                this->show_version = true;
                found_flag = true;
              }
              if (!arg.compare("--license")) {
                this->show_license = true;
                found_flag = true;
              }
              if (!arg.compare("--vmdir")) {
                this->show_vmdir = true;
                found_flag = true;
              }
              if (!arg.compare("--garbage-collector")) {
                this->trace_gc = true;
                found_flag = true;
              }
              if (!arg.compare("--compile")) {
                this->allow_compilation = true;
                found_flag = true;
              }
              if (!arg.compare("--token")) {
                this->dump_tokens = true;
                found_flag = true;
              }
              if (!arg.compare("--ast")) {
                this->dump_ast = true;
                found_flag = true;
              }
              if (!arg.compare("--asm")) {
                this->dump_asm = true;
                found_flag = true;
              }
              if (!arg.compare("--flag")) {
                append_to_flags = true;
                found_flag = true;
              }

              if (append_to_flags)
                continue;
              if (found_flag)
                continue;
            }

            if (arg[0] == '-' && arg[1] == 'f') {
              append_flag(arg.substr(2, arg.size()));
              continue;
            }
          }

          this->arguments.push_back(arg);
        }

        this->file = this->arguments.size()? this->arguments[0] : "";

    }

    inline bool dump_file_contains(const std::string& str) {
    auto& dump_file_list = this->dump_files_include;

    for (auto& name : dump_file_list) {
      if (str.find(name) != std::string::npos) {
        return true;
      }
    }

    return false;
  }

};

}
}

#endif // __RUN__FLAGS__HPP

