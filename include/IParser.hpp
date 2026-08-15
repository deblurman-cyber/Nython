#ifndef __IPARSER__HPP
#define __IPARSER__HPP

#include <memory>
#include "Node.hpp"
#include "Lexer.hpp"
#include "Except.hpp"


namespace nython::node {
class Node;
typedef std::shared_ptr<Node> NodePtr;

}

namespace nython::parser {

using nython::lexer::TokenType;
using nython::node::NodePtr;

struct IParser extends ReporterAware {

    IParser(Reporter* reporter): ReporterAware(reporter) {
    }

    virtual ~IParser() {}
    virtual NodePtr parse()                                       = 0;/// parse code to provide ast.
    virtual Token token()                                         = 0;
    virtual Token next()                                          = 0;/// the next token.
    virtual Token prev()                                          = 0;/// the previous token.
    virtual Token peek(int i)                                     = 0;/// the token at position i.
    virtual std::string code()                                    = 0;/// the source code.
    virtual std::string fileName()                                = 0;/// the file name of the source code.
    virtual bool see(TokenType type)                              = 0;
    virtual bool have(TokenType type)                             = 0;
    virtual void mustBe(TokenType type, std::string context="")   = 0;
    virtual bool atEnd()                                          = 0; /// are we at the end of tokens?
    virtual bool match(TokenType kind)                            = 0;
    virtual bool match(std::initializer_list<TokenType> types)    = 0;
    virtual Token consume(TokenType kind, std::string context="") = 0;
    virtual void synchronize()                                    = 0;

};

}

#endif // __IPARSER__HPP
