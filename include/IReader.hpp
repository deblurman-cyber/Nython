#ifndef __IREADER__HPP
#define __IREADER__HPP

#include <string>
#include <cstddef>

namespace nython::reader {
struct IReader{
    virtual ~IReader() = default;
	virtual std::string read()                  = 0;
    virtual void sourceCode(const std::string&) = 0;
    virtual std::string sourceCode()            = 0;
    virtual std::string line()                  = 0;
    virtual int line_number() const             = 0;
    virtual std::string fileName() const        = 0;
    virtual bool eof() const                    = 0;
    virtual bool isFile() const                 = 0;
    virtual void reset(int pos = 0)             = 0;
};
}

#endif // __IREADER__HPP

