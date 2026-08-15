#ifndef __TOKEN__HPP
#define __TOKEN__HPP

#include <string>
#include <sstream>
#include <iostream>
#include "IToken.hpp"
// fmt provided by Definitions.hpp

namespace nython::utils {
    class PrettyPrinter;
}

using nython::utils::PrettyPrinter;

namespace nython::lexer  {

template< typename ValueType, size_t InitSizeDiff = 0>
class ConstArray {

    private:
		ValueType * const data_;
		std::size_t size_;
    public:
        template<std::size_t N>
        ConstArray(ValueType(&data)[N]):data_(data),size_(N-InitSizeDiff) {
        }

        ConstArray(const ConstArray& that):data_{that.data_},size_{that.size_}{
        }

        virtual ~ConstArray() {
        }

        ConstArray& operator=(const ConstArray& that) = delete;

        char operator[](std::size_t index) const{
            return index < size_ ? data_[index]:throw std::out_of_range("");
        }

        std::size_t size() const{
            return size_;
        }

        ValueType const * data() const{
            return data_;
        }

        bool empty() const{
            return size_ == 0;
        }

        ValueType const * begin() const{
            return data();
        }

        ValueType const * end() const{
            return data() + size();
        }
};

struct TokenIdent {

    private:

        TokenType id_;
        TokenKind kind_;
        TokenClass cls_;

    public:

        TokenIdent(TokenType id, TokenKind kind, TokenClass cls): id_(id),kind_(kind),cls_(cls) {
        }

        TokenIdent(): TokenIdent(TokenType::Invalid, TokenKind::Error, TokenClass::Default) {
        }

        TokenType id() const{
            return id_;
        }

        void id(TokenType id) {
            id_ = id;
        }

        TokenKind kind() const{
            return kind_;
        }

        TokenClass cls() const{
            return cls_;
        }

        void kind(TokenKind kind) {
            kind_ = kind;
        }

        void cls(TokenClass cls) {
            cls_ = cls;
        }

        bool operator==(const TokenIdent& that) const {
            return that.kind_==kind_ && that.cls_==cls_ && that.id_==id_;
        }
};

struct TokenDef {

	TokenIdent ident;
	std::string value;

	TokenDef(TokenType id,std::string val,TokenKind kind,TokenClass cls):ident(id,kind,cls),value(std::move(val)) {
	}

	inline bool match4(char c0,char c1,char c2,char c3) const{
		return (value.size() == 4 && (c0 == value[0] && c1 == value[1] && c2 == value[2] && c3 == value[3]))
		|| (value.size() == 3 && (c0 == value[0] && c1 == value[1] && c2 == value[2]))
		|| (value.size() == 2 && (c0 == value[0]) && c1 == value[1])
		|| (value.size() == 1 && (c0 == value[0]));
	}

	inline bool match3(char c0,char c1,char c2) const{
		return (value.size() == 3 && (c0 == value[0] && c1 == value[1] && c2 == value[2]))
		|| (value.size() == 2 && (c0 == value[0] && c1 == value[1]))
		|| (value.size() == 1 && (c0 == value[0]));
	}

	inline bool match2(char c0,char c1) const{
		return (value.size() == 2 && (c0 == value[0] && c1 == value[1]))
		|| (value.size() == 1 && (c0 == value[0]));
	}

	friend std::ostream& operator<<(std::ostream& os,TokenDef& obj) {
		os<<"["<<obj.value.data()<<", "<<int(obj.ident.id())<<"]";
		return os;
	}
};


struct Token extends IToken {

    Location _location;
    TokenIdent ident  = {TokenType::End, TokenKind::End, TokenClass::Eof};
    std::string value = "End";

    Token() : _location{} {
    }

    Token(const Token& other) : _location(other._location), ident(other.ident), value(other.value) {
    }

    Token(Token&& other) noexcept : _location(std::move(other._location)), ident(std::move(other.ident)), value(std::move(other.value)) {
    }

    Token(TokenIdent t) : _location{}, ident(t) {
    }

    Token(TokenIdent t, const std::string& v) : _location{}, ident(t), value(v) {
    }

    Token(TokenIdent t, const std::string& v, const Location& l) : _location(l), ident(t), value(v) {
    }

    virtual ~Token() = default;

    TokenType type() const {
        return ident.id();
    }

    void type(TokenType tp) {
        return ident.id(tp);
    }

    TokenKind kind() const {
        return ident.kind();
    }

    TokenClass clazz() const {
        return ident.cls();
    }

    Token& operator=(const Token& token) {
        if(this!=&token) {
            ident     = token.ident;
            _location = token._location;
            value     = token.value;
        }
        return *this;
    }

    Token& operator=(Token&& token) noexcept {
        if(this!=&token) {
            ident     = std::move(token.ident);
            _location = std::move(token._location);
            value     = std::move(token.value);
        }
        return *this;
    }

    void writeToStdOut(PrettyPrinter p);
    std::string writeToString(PrettyPrinter p);
    std::string toString();

    bool isKeyWord() const;
    bool isAssignment() const;

    inline Location location() const {
        return _location;
    }

    inline std::string fileName() const {
        return _location.filename;
    }

    inline int line() const {
        return _location.row;
    }

    inline int column() const {
        return _location.column;
    }

    bool operator==(const Token& that) const;

    friend std::ostream& operator<<(std::ostream& os,Token token) {
        os << token.toString();
        return os;
    }
};

}



#endif // __TOKEN__HPP

