#ifndef __TYPE__HPP
#define __TYPE__HPP

#include <string>
// fmt provided by Definitions.hpp

namespace nython{
namespace db{}

namespace io{}

namespace os{}

namespace socket{}

namespace sys{}

namespace ide{}

namespace web{}

namespace xml{}

namespace widget{
    struct Widget;
    struct Window;
}

namespace example{}

namespace visitor{
}

namespace gc{
    class Collectable;
    class GarbageCollector;
}

namespace vm{
    struct VirtualMachine;
}

namespace lexer{
    struct Lexer;
    struct Token;
    struct LookaheadLexer;
}

namespace parser{
    struct Parser;
}

namespace util{
    struct Math;
    struct Util;
    struct PrettyPrinter;
}

namespace node{
    struct Node;
    struct Block;
    struct NodeList;
    struct Statement;
    struct ScriptNode;
    struct Expression;
}

namespace kernel{
    struct Set;
    struct Value;
    struct Object;/// interface for every objects.
    struct Slice;
    struct Lambda;
    struct Complex;
    struct Map;
    struct List;
    struct Tuple;
    struct Array;
    struct Date;
    struct Time;
    struct Code;
    struct String;
    struct Enum;
    struct Range;
    struct Instance;
    struct Interface;
    struct Class;
    struct Field;
    struct FunList;
    struct Iterator;
    struct NameSpace;
    struct Module;
    struct Method;
    struct Closure;
    struct Package;
    struct Function;
    struct Annotation;
    struct Runtime;
    struct Rational;
    struct Callable;
    struct File;
    struct Directory;
    struct Path;
    struct Regex;
    struct Context;
    struct Argument;
    struct Parameter;
}

namespace engine{
}

namespace exception {
    struct Exception;
    struct ParserException;
    struct RuntimeException;
    struct ArrayIndexException;
    struct ArithmeticException;
    struct FileNotFoundException;
    struct ClassNotFoundException;
    struct MethodNotFoundException;
    struct FunctionNotFoundException;
    struct AttributeNotFoundException;
}

namespace reader {
struct SourceCode;
}

}


namespace nython::kernel {

#undef INTERFACE

enum class Type: unsigned char{
	STRING  = 0,
	COMPLEX,
	RATIONAL,
	LIST,
	TUPLE,
	ARRAY,
	MAP,
	SET,
	ENUM,
	RANGE,
	SLICE,
	CLASS,
	METHOD,
	FUNCTION,
	LAMBDA,
	INTERFACE = 15,
	INSTANCE,
	PACKAGE,
	MODULE,
	NAMESPACE,
	PROPERTY,
	FUNLIST,
	ITERATOR,
	GENERATOR,
	PARAMETER,
	ARGUMENT,
	ELLIPSIS,
	FILE,
	EXCEPTION,
	REGEXP,
	COROUTINE,
	DATE,
	TIME,
	DATETIME,
	CODE,
	CONTEXT,
	UNIT,
	NATIVE,
	OBJECT,
	DEAD,
	THREAD,
	T_MASK
};

static const char* TypeNames[] = {
	"string",
	"complex",
	"rational",
	"list",
	"tuple",
	"array",
	"map",
	"set",
	"enum",
	"range",
	"slice",
	"class",
	"method",
	"function",
	"lambda",
	"interface",
	"instance",
	"package",
	"module",
	"namespace",
	"property",
	"funlist",
	"iterator",
	"generator",
	"parameter",
	"argument",
	"ellipsis",
	"file",
	"exception",
	"regexp",
	"coroutine",
	"date",
	"time",
	"datetime",
	"code",
	"context",
	"unit",
	"native",
	"object",
	"dead",
	"thread",
	"unkown"
};


inline std::string TypeToString(Type type){
	return std::string(TypeNames[int(type)]);
}

}


#endif // __TYPE__HPP



