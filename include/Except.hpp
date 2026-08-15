#ifndef __EXCEPT__HPP
#define __EXCEPT__HPP

#include <string>
#include <sstream>
#include <exception>
#include "Location.hpp"
#include "SourceCode.hpp"


// fmt provided by Definitions.hpp
// fmt replaced
// fmt provided by Definitions.hpp


using nython::lexer::Location;
using nython::reader::SourceCode;

struct except {
    virtual ~except() = default;

public:

    except(const std::string& desc) : m_desc(desc) {
    }

    virtual const char* what() {
        return m_desc.c_str();
    }

private:
    std::string m_desc;
};

namespace nython::exception {

// Exception thrown when processing a source file fails
class SourceException : public Exception {
    public:
      // Constructor
      inline SourceException(std::string message, Exception* previous) : Exception(message, previous) {}
      inline SourceException(std::string message) : Exception(message, nullptr) {}
      ~SourceException() override = default;
};

// Class that defines an error
class Error : public Exception {
private:
    // The location where the error occurred
    Location location_;
public:

    virtual ~Error() {}

    // Constructor
    inline Error(Location location, std::string message, Exception* previous) : Exception(message, previous), location_(location) {}
    inline Error(Location location, std::string message)  : Error(location, message, nullptr) {}

    // Return the location where the error occurred
    inline Location& location() {
        return location_;
    }

    // Return the type of the error as a string
    inline virtual std::string type() {
        return "Error";
    }
};

// Error thrown when compiling a source file fails
class CompilerError : public Error {
public:

    virtual ~CompilerError() {}

    inline CompilerError(Location location, std::string message, Exception* previous) : Error(location, message, previous) {}
    inline CompilerError(Location location, std::string message) : Error(location, message, nullptr) {}

    inline virtual std::string type() override {
        return "CompilerError";
    }
};


// An unexpected char was found during lexing of the source code
struct UnexpectedCharError: public CompilerError {

    virtual ~UnexpectedCharError() {}

    inline UnexpectedCharError(Location location, std::string message, Exception* previous) : CompilerError(location, message, previous) {}
    inline UnexpectedCharError(Location location, std::string message) : CompilerError(location, message, nullptr) {}

    virtual std::string report(int line, int column, const std::string &where, const std::string &message) const noexcept {
        return "UnexpectedCharError : [line -> " + std::to_string(line) + " ; column -> " + std::to_string(column) + "] -> " + where + " " + message;
    }

    inline std::string what() noexcept {
        auto loc = location();
        return report(loc.row, loc.column, loc.filename, message());
    }

    inline virtual std::string type() override {
        return "UnexpectedCharError";
    }
};

// Error thrown when lexing or parsing a source file fails
class SyntaxError : public CompilerError {
public:
    inline SyntaxError(Location location, std::string message, Exception* previous) : CompilerError(location, message, previous) {}
    inline SyntaxError(Location location, std::string message) : CompilerError(location, message, nullptr) {}

    virtual ~SyntaxError() {}

    inline virtual std::string type() override {
        return "SyntaxError";
    }
};

// Error thrown when resolving a type fails
class TypeError : public CompilerError {
public:
    // Constructor
    inline TypeError(Location location, std::string message, Exception* previous) : CompilerError(location, message, previous) {}
    inline TypeError(Location location, std::string message) : CompilerError(location, message, nullptr) {}
    virtual ~TypeError() {}

    inline virtual std::string type() override {
        return "TypeError";
    }
};

// Error thrown when a type cannot be resolved
class TypeUnresolvedError : public TypeError {
public:
    inline TypeUnresolvedError(Location location, std::string message, Exception* previous) : TypeError(location, message, previous) {}
    inline TypeUnresolvedError(Location location, std::string message) : TypeError(location, message, nullptr) {}
    virtual ~TypeUnresolvedError() {}

    inline virtual std::string type() override {
        return "TypeUnresolvedError";
    }
};

// Error thrown when a type does not match an already declared type
class TypeMismatchError : public TypeError
{
public:
    inline TypeMismatchError(Location location, std::string message, Exception* previous) : TypeError(location, message, previous) {}
    inline TypeMismatchError(Location location, std::string message) : TypeError(location, message, nullptr) {}
    virtual ~TypeMismatchError() {}

    inline virtual std::string type() override
    {
        return "TypeMismatchError";
    }
};

// Error thrown when processing a value fails
class IndexOutOfRangeError : public CompilerError
{
public:
    inline IndexOutOfRangeError(Location location, std::string message, Exception* previous) : CompilerError(location, message, previous) {}
    inline IndexOutOfRangeError(Location location, std::string message) : CompilerError(location, message, nullptr) {}
    virtual  ~IndexOutOfRangeError() {}

    inline virtual std::string type() override {
        return "IndexOutOfRangeError";
    }
};


// Error thrown when processing a value fails
class ValueError : public CompilerError
{
public:
    inline ValueError(Location location, std::string message, Exception* previous) : CompilerError(location, message, previous) {}
    inline ValueError(Location location, std::string message) : CompilerError(location, message, nullptr) {}
    virtual ~ValueError() {}

    inline virtual std::string type() override {
        return "ValueError";
    }
};

// Error thrown when a value is not of the expected value type
class ValueMismatchError : public ValueError
{
public:
    inline ValueMismatchError(Location location, std::string message, Exception* previous) : ValueError(location, message, previous) {}
    inline ValueMismatchError(Location location, std::string message) : ValueError(location, message, nullptr) {}
    virtual ~ValueMismatchError() {}

    inline virtual std::string type() override {
        return "ValueMismatchError";
    }
};

// Error thrown when a value exceeds the range of the expected value type
class ValueOverflowError : public ValueError
{
public:
    inline ValueOverflowError(Location location, std::string message, Exception* previous) : ValueError(location, message, previous) {}
    inline ValueOverflowError(Location location, std::string message) : ValueError(location, message, nullptr) {}
    virtual ~ValueOverflowError() {}

    inline virtual std::string type() override {
        return "ValueOverflowError";
    }
};

// Error thrown when running a compiled a source file fails
class RuntimeError : public Error
{
public:
    inline RuntimeError(Location location, std::string message, Exception* previous) : Error(location, message, previous) {}
    inline RuntimeError(Location location, std::string message) : Error(location, message, nullptr) {}
    virtual ~RuntimeError() {}

    inline virtual std::string type() override {
        return "RuntimeError";
    }
};

// Error thrown when an aritmethic operation fails
class ArithmeticError : public RuntimeError {
public:
    inline ArithmeticError(Location location, std::string message, Exception* previous) : RuntimeError(location, message, previous) {}
    inline ArithmeticError(Location location, std::string message) : RuntimeError(location, message, nullptr) {}
    virtual ~ArithmeticError() {}

    inline virtual std::string type() override {
        return "ArithmeticError";
    }
};

// Error thrown when a value is divided by zero
class DivisionByZeroError : public ArithmeticError {
public:
    inline DivisionByZeroError(Location location, std::string message, Exception* previous) : ArithmeticError(location, message, previous) {}
    inline DivisionByZeroError(Location location, std::string message) : ArithmeticError(location, message, nullptr) {}
    virtual ~DivisionByZeroError() {}

    inline virtual std::string type() override {
        return "DivisionByZeroError";
    }
};

// Error thrown when a value cannot be converted in an arithmetic operation
class ConversionError : public ArithmeticError {
public:
    inline ConversionError(Location location, std::string message, Exception* previous) : ArithmeticError(location, message, previous) {}
    inline ConversionError(Location location, std::string message) : ArithmeticError(location, message, nullptr) {}
    virtual ~ConversionError() {}

    inline virtual std::string type() override {
        return "ConversionError";
    }
};

// Error thrown when the stack of the virtual machine overflows, i.e. has reached its maximum capacity
class StackOverflowError : public RuntimeError {
public:
    inline StackOverflowError(Location location, std::string message, Exception* previous) : RuntimeError(location, message, previous) {}
    inline StackOverflowError(Location location, std::string message) : RuntimeError(location, message, nullptr) {}
    virtual ~StackOverflowError() {}

    inline virtual std::string type() override {
        return "StackOverflowError";
    }
};

// Error thrown when the stack of the virtual machine underflows, i.e. has no more values
class StackUnderflowError : public RuntimeError {
public:
    inline StackUnderflowError(Location location, std::string message, Exception* previous) : RuntimeError(location, message, previous) {}
    inline StackUnderflowError(Location location, std::string message) : RuntimeError(location, message, nullptr) {}
    virtual ~StackUnderflowError() {}

    inline virtual std::string type() override {
        return "StackUnderflowError";
    }
};

// Error thrown when an operation is not implemented
class UnimplementedError : public RuntimeError {
public:
    inline UnimplementedError(Location location, std::string message, Exception* previous) : RuntimeError(location, message, previous) {}
    inline UnimplementedError(Location location, std::string message) : RuntimeError(location, message, nullptr) {}

    virtual ~UnimplementedError() {}

    inline virtual std::string type() override {
        return "UnimplementedError";
    }
};

// Class that defines an error reporter
class Reporter {
    private:
      // The source file which errors are reported for
      SourceCode source_;

      // The list of reported errors
      std::vector<Error> errors_;


    public:
      // Constructor
      Reporter(SourceCode source):source_(source), errors_{}{}

      // Return the source file which errors are reported for
      SourceCode source() {
        return source_;
      }

      // Return the reported errors
      std::vector<Error> errors() {
        return errors_;
      }

      // Return if the reporter has reported errors
      bool has_errors(){
        return errors_.size() > 0;
      }

      // Clear the reported errors
      void clear_errors() {
        errors_.clear();
      }

      // Print the reported errors
      void print_errors() {
        for (auto error : errors_)
          print_error(error);
      }


      // Print an error
      void print_error(Error error){
        std::cerr << nython::color::red() << nython::color::bold() << error.type() << ": " << nython::color::reset();
        std::cerr << nython::color::red() << error.message() << nython::color::reset() << std::endl;
        std::cerr << "at " << source_.format(error.location()) << std::endl;
      }

      // Report an error
      template <typename T, typename std::enable_if<std::is_base_of<Error, T>::value>::type* = nullptr>
      inline T report(Location location, std::string message, Exception* previous = nullptr) {
        T error(location, message, previous);
        errors_.push_back(error);
        return error;
      }
};


  // Class that defines another class to be aware of an error reporter
class ReporterAware {
public:
    ReporterAware(const ReporterAware&) = default;
    ReporterAware& operator=(const ReporterAware&) = default;
    private:
      // Reference to the error reporter
      Reporter* reporter_;
    public:
      // Constructor
      inline ReporterAware(Reporter* reporter) : reporter_(reporter) {}
      virtual ~ReporterAware() = default;

      // Report an error
      template <typename T, typename std::enable_if<std::is_base_of<Error, T>::value>::type* = nullptr>
      inline T report(Location location, std::string message, Exception* previous = nullptr) {
        return reporter_->report<T>(location, message, previous);
      }
};

}


#define CHECK(pred, msg) do { if(!(pred)) { std::stringstream ss; ss << msg; throw except(ss.str()); } } while(false)

#define ASSERT(pred, msg) CHECK(pred, msg)

#define THROW(msg) do { std::stringstream ss; ss << msg; throw except(ss.str()); } while(false)


#endif // __EXCEPT__HPP
