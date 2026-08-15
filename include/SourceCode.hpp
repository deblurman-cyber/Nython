#ifndef __SourceCode__HPP
#define __SourceCode__HPP


#include "ILexer.hpp"
#include "IReader.hpp"
#include "Location.hpp"
// fmt provided by Definitions.hpp
#include "Definitions.hpp"

using namespace nython::utils;
using namespace nython::lexer;

namespace nython::reader {

class SourceCode;
using source_ptr = std::shared_ptr<SourceCode>;

class SourceCode extends IReader {

	public:

		SourceCode(const std::string & filename);
		SourceCode(const SourceCode& that);
		~SourceCode();

		std::string line();
		std::string read();

		inline bool isFile() const { return isfile; }
		inline int line_number() const  { return nb; }
		inline std::string fileName() const  { return location.filename; }
		inline bool eof() const  { return current>=int(code.size()); }
		inline std::string sourceCode()  { return code; }
		inline void sourceCode(const std::string& src)  { this->code = src; }
		inline void reset(int pos = 0) { current = pos; current_char = '\0'; reset_frame(); location.reset(); }

		inline char read_char() {
		    if(current>=int(code.size()))  {
                return '\0';
            }
		    current_char = code[current++];
		    if(current_char=='\n') {
                location.row++;
                location.column = 1;
		    }else {
		        if(current_char == '\t'){
                    location.column += TabSize;
                }else{
                    location.column++;
                }
            }
		    return current_char;
		}

		inline char peek_char(int i = 0) {
		    if(current + i >= int(code.size()) || current + i < 0 ) {
                return '\0';
            }
            return code[current + i];
		}

		inline char put_char() {
            if(current) current--;
            if (current_char == '\n' || current_char == '\x0c') {
                if(location.row) location.row--;
                location.column = 1;
            }
            else {
                if(this->location.column) {
                    if(current_char == '\t') this->location.column -= TabSize;
                    else this->location.column--;
                }
            }
            return current_char;
        }

		inline void reset_frame() {
            frame.clear();
		}

		inline std::string get_current_frame() {
            return frame;
		}

		inline bool isAtEnd() {
            return current_char=='\0' or current >= int(code.size());
		}

		inline void appendToFrame(char c) {
		    frame.append(std::string({c}));
		}

		inline int getCurrent() const {
            return current;
		}

		// Return The source string split by line of the source
        inline  std::vector<std::string> source_lines() const {
            return source_lines_;
        }

        // Format a location in the source
        std::string format(Location location);

        // Create a shared pointer to a source
        static source_ptr create(std::string source);

        // Create a shared pointer to a source read from a file
        static source_ptr create_read(std::string file);

	private:
	    bool _eof   = false;
		std::string code{};
		int nb      = 0;
		int current = 0;
		std::ifstream in{};

		// The source string split by line of the source
        std::vector<std::string> source_lines_;

    public:

        char current_char = '\0';
		Location location;
		std::string frame;
        bool isfile = false;

};

}

#endif // __SourceCode__HPP

