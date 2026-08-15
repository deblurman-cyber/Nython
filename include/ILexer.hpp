#ifndef __ILEXER__HPP
#define __ILEXER__HPP

#include <memory>
#include <vector>
#include "Token.hpp"

namespace nython::lexer {

enum{
    TabSize    = 4,
    AltTabSize = 1,
};

struct ILexer{

    virtual ~ILexer(){}
    virtual std::vector<Token> tokenize()= 0;/// read the source code in a certain way to provide tokens.
    virtual void dump()                  = 0;/// prints the tokens.
    virtual Token next()                 = 0;/// the next token.
    virtual Token prev()                 = 0;/// the previous token.
    virtual Token peek(int i)            = 0;/// the token at position i.
    virtual std::string code()           = 0;/// the source code.
    virtual std::string fileName()       = 0;/// the file name of the source code.
    virtual bool isKeyWord(const std::string word)   = 0;/// true if word is a key word.
    virtual bool isOperator(const std::string word)  = 0;/// true if word is an operator.
    virtual bool isSeparator(const std::string word) = 0;/// true if word is a separator.
    virtual bool isIdentifier(const std::string word) = 0;/// true if word is an identifier.

};

}

#endif // __ILEXER__HPP
