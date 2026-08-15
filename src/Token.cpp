#include "Token.hpp"
#include "PrettyPrinter.hpp"

namespace nython::lexer {

void Token::writeToStdOut(PrettyPrinter p) {
    TokenType type   = this->type();
    TokenKind kind   = this->kind();
    TokenClass clazz = this->clazz();
    p.printf("<Token value=\"%s\" file=\"%s\" line=\"%d\" column=\"%d\">\n",value.c_str(), _location.filename.c_str() , _location.row, _location.column);
    p.indentRight();
    p.printf("<TokenType value=\"%s\"/>\n",  std::string(~type).c_str());
    p.printf("<TokenKind value=\"%s\"/>\n",  std::string(~kind).c_str());
    p.printf("<TokenClass value=\"%s\"/>\n", std::string(~clazz).c_str());
    p.indentLeft();
    p.println("</Token>");
}

std::string Token::writeToString(PrettyPrinter p) {
    std::string str;
    TokenType type   = this->type();
    TokenKind kind   = this->kind();
    TokenClass clazz = this->clazz();
    p.printf(&str, "<Token value=\"%s\" file=\"%s\" line=\"%d\" column=\"%d\">\n",value.c_str(), _location.filename.c_str() , _location.row, _location.column);
    p.indentRight();
    p.printf(&str, "<TokenType value=\"%s\"/>\n",  std::string(~type).c_str());
    p.printf(&str, "<TokenKind value=\"%s\"/>\n",  std::string(~kind).c_str());
    p.printf(&str, "<TokenClass value=\"%s\"/>\n", std::string(~clazz).c_str());
    p.indentLeft();
    p.printf(&str, "</Token>\n");
    return str;
}

std::string Token::toString(){
	return writeToString(PrettyPrinter());
}

bool Token::isKeyWord() const {
    TokenClass clazz = this->clazz();
    return clazz==TokenClass::Keyword;
}

bool Token::isAssignment() const {
	return this->clazz()==TokenClass::Assignment;
}

bool Token::operator==(const Token& that) const {
    return ident == that.ident && value == that.value && _location == that._location;
}

}


