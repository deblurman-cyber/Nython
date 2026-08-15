#ifndef __INODE__HPP
#define __INODE__HPP


#include "Util.hpp"
#include "Token.hpp"
#include "Value.hpp"
#include "Object.hpp"
#include "Visitor.hpp"
#include "Context.hpp"
#include "PrettyPrinter.hpp"

using nython::lexer::Token;
using nython::kernel::Value;
using nython::kernel::Object;
using nython::kernel::Context;
using nython::lexer::Location;
using nython::visitor::IVisitor;
using nython::utils::PrettyPrinter;

namespace nython::node {

// Undefine Windows macros that clash with NodeType enum members
#ifdef _WIN32
#  undef TRUE
#  undef FALSE
#  undef CONST
#  undef DELETE
#  undef INTERFACE
#  undef NEAR
#  undef FAR
#  undef IN
#  undef OUT
#  undef OPTIONAL
#  undef VOID
#  undef STRICT
#  undef ERROR
#endif

enum class NodeType:uint8_t {
    SCRIPT,
    STATEMENT,
    STATEMENTS,
    TUPLE,
    LIST,
    MAP,
    MAP_ENTRY,
    ARRAY,
    FLOAT,
    INTEGER,
    STRING,
    TRUE,
    FALSE,
    NONE,
    UNDEFINED,
    CALL,
    WITH,
    WITH_ITEM,
    CONST,
    LET,
    INTERVAL,
    GLOBAL,
    COMPLEX,
    DEPACK,
    DELETE,
    KEYWORD,
    KEYWORD_ARG,
    SLICE,
    RANGE,
    VARIABLE,
    VARIABLE_DECL,
    ASSIGNMENT,
    ASSIGNMENT_AUG,
    YIELD,
    YIELD_FROM,
    WALRUS,
    RETURN,
    BREAK,
    CONTINUE,
    BLOCK,
    ATTRIBUTE,
    SUBSCRIPT,
    VAR_ARGS,
    SUPER,
    LAMBDA,
    FUNCTION,
    METHOD,
    CLASS,
    ENUM,
    ENUM_ITEM,
    REF,
    INTERFACE,
    NAMESPACE,
    PACKAGE,
    IMPORT,
    SELF,
    PASS,
    IF,
    ELSE,
    ELSEIF,
    FOR,
    WHILE,
    SWITCH,
    CASE,
    DEFAULT,
    REPEAT,
    UNLESS,
    TRY,
    FINALLY,
    EXCEPT,
    EXCEPT_ITEM,
    RAISE,
    ASSERT,
    PRINT,
    EXECUTE,
    UNARY,
    BINARY,
    BINARY_OP,
    BINARY_RE,
    OPERATOR,
    LOOP,
    MACRO_CALL,
    DYN_BINOP
};

struct INode{

    virtual ~INode() {
    }

    virtual bool is(NodeType t){
        return type()==t;
    }

    virtual bool isVariable(){
        return is(NodeType::VARIABLE);
    }

    virtual bool isAssign(){
        return is(NodeType::ASSIGNMENT);
    }

    virtual bool isAttribute(){
        return is(NodeType::ATTRIBUTE);
    }

    virtual bool isTuple(){
        return is(NodeType::TUPLE);
    }

    virtual bool isList(){
        return is(NodeType::LIST);
    }

    virtual bool isArray(){
        return is(NodeType::ARRAY);
    }

    virtual bool isMap(){
        return is(NodeType::MAP);
    }

    virtual bool isString(){
        return is(NodeType::STRING);
    }

    virtual bool isSequence(){
        return isArray() or isTuple() or isList() or isMap() or isString();
    }

    virtual bool isScript(){
        return is(NodeType::SCRIPT) || is(NodeType::STATEMENTS);
    }

    virtual int line(){
        return token().line();
    }

    virtual int column(){
        return token().column();
    }

    virtual std::string file(){
        return token().fileName();
    }

    virtual std::string value(){
        return token().value;
    }

    // Return the location of the node
    virtual Location location() {
        return token().location();
    }

    virtual Token token()                  = 0;
    virtual NodeType type()                = 0;
    virtual Value eval(Context* context)   = 0;
    virtual void accept(IVisitor* visitor) = 0;/// visitor visit this node to perform some operations.
    /**
     * Write the information pertaining to this AST to STDOUT.
     *
     * @param p for pretty printing with indentation.
	*/
    virtual void writeToStdOut(PrettyPrinter p)   = 0;
    virtual std::string toString(PrettyPrinter p) = 0;

};

}

#endif // __INODE__HPP

