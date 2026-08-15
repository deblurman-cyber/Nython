#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include "Util.hpp"
#include "Regex.hpp"
#include "Except.hpp"
#include "SourceCode.hpp"
#include "Definitions.hpp"

namespace nython::io {
    std::string file_name;
    std::vector<std::string> lines; // stores the lines of the input file
}

using nython::io::lines;
using nython::io::file_name;

namespace nython::reader {

    // Create a shared pointer to a source
    source_ptr SourceCode::create(std::string source) {
        return std::make_shared<SourceCode>(source);
    }

    // Create a shared pointer to a source read from a file
    source_ptr SourceCode::create_read(std::string file) {
        if (!utils::FileExists(file)) throw exception::SourceException(fmt::format("The file '{}' does not exist", file));
        return create(file);
    }

	SourceCode::SourceCode(const std::string & filename):_eof{false},code{},nb{-1},current{0},in{},source_lines_{},current_char{'\0'},location{},frame{},isfile{nython::utils::FileExists(filename)} {
        if(isfile) {
			in                = std::ifstream(filename);
			location.filename = filename;
			file_name         = filename;
		}else {
		    code              = filename;
		    location.filename = std::string("stdin");
		    file_name         = std::string("stdin");
        }
    }

    SourceCode::SourceCode(const SourceCode& that): SourceCode(that.location.filename) {
    }

    SourceCode::~SourceCode() {
        in.close();
    }

    std::string SourceCode::line(){
        std::string line;
        if(!isfile){
            char c;
            do{
                c = code[current++];
                line.push_back(c);
                if(c=='\0'|| c==-1){
                    nb++;
                    _eof = true;
                    break;
                }
                if(c =='\n' || c == '\x0c') nb++;
            }while(c != '\n' && c != '\x0c');
        }else{
            char c;
            do{
                c = in.get();
                line.push_back(c);
                 if(in.eof()){
                    break;
                }
                if(c =='\n' || c == '\x0c') nb++;
            }while(c != '\n' && c != '\x0c');
        }
        return line;
    }

    std::string SourceCode::read(){
        if(!isfile){
            // Content already loaded into `code` — just initialize metadata
            nb = 0; current = 0;
            if(!code.empty()) current_char = code[current];
            if(code.empty()||code.back()!='\0') code.push_back('\0');
            kernel::Regex line_pattern_("\\r?\\n");
            source_lines_ = line_pattern_.split(code);
            lines = source_lines_;
            return code;
        }
        std::string buff{};
        nb = 0;
        while(!(_eof||in.eof())) {
            buff += line();
        }
        in.close();
        // Initialize the regex patterns for the source
        kernel::Regex line_pattern_("\\r?\\n");
        if(!buff.empty()) buff[buff.size()-1] = '\0';
        buff                = nython::utils::trim(buff);
        code                = buff;
        current             = 0;
        current_char        = buff.empty()?'\0':buff[current];
        source_lines_       = line_pattern_.split(buff);
        lines               = source_lines_;
        return buff;
    }

    // Format a location in the source
    std::string SourceCode::format(Location location) {
        if (location.row >= source_lines_.size())
          throw exception::SourceException(fmt::format("line {} is not present in {}", location.row, location.filename));

        auto line = source_lines_[location.row];
        if (location.column > line.length())
          throw  exception::SourceException(fmt::format("line {}, col {} is not present in {}", location.row, location.column, location.filename));

        std::string format;
        format.append(fmt::format("{}, {}\n", location.filename, location));
        format.append(fmt::format("{:>4d} │ {}\n", location.row , source_lines_[location.row]));
        format.append(fmt::format("     │ {}^", utils::repeat(" ", location.column)));
        return format;
    }

}

#pragma GCC diagnostic pop
