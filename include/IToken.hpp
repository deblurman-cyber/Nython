#ifndef __ITOKEN__HPP
#define __ITOKEN__HPP

#include <string>
#include <iostream>
#include <stdexcept>
#include "Location.hpp"
#include "Definitions.hpp"

namespace nython::lexer {

/**
*
* This are tokens type , kind and class.
* They represent respectively the current type of a token, the kind of that token and his class.
*
**/

DECLARE_ENUM_WITH_TYPE (
    TokenType,
    uint32_t,
    /// begin of enumerated class
	Invalid,
	End,
	NewLine,
	Indent,
	Dedent,
	Block,

	NotMultipleOfFourIndentError,
	MixedIndentError,
	IndentationError,
	DedentationError,
	LineContinuationError,
	UnterminatedStringError,
	UnterminatedRegexError,

	Comment,/// for class and function documentation
	Whitespace,
	BackQuote,/// '`'
	Identifier,
	Float,
	Integer,
	Hex,
	Oct,
	Binary,
	Complex,
	String,

	True,
	False,
	None,
	Undefined,
	Class,
	Abstract,
	Continue,
	Ref,
	If,
	Else,
	ElseIf,
	For,
	Default,
	Do,
	Then,
	Extends,
	Inherits,
	Finally,
	Final,
	Implements,
	Import,
	In,
	Pass,
	Instanceof,
	Subclassof,
	Parentof,
	Interface,
	Package,
	NameSpace,
	Private,
	Protected,
	Public,
	Return,
	Static,
	Super,
	Switch,
	This,
	Self,
	Raise,
	Try,
	While,
	Def,
	Function,
	Fun,
	Fn,
	EndBlock,
	Async,
	Await,
	Break,
	With,
	As,
	Assert,
	Lambda,
	Case,
	Use,
	Enum,
	Except,
	Print,
	Yield,
	Is,
	From,
	Unless,
	Repeat,
	Until,
	Loop,
	Delete,
	Sizeof,
	Typeof,
	Global,
	Execute,
	Var,
	Const,
	Let,

	Ellipsis,/// ...

	Add,
	Sub,
	Mul,
	Div,
	RevDiv,/// '\'
	Exp, /// **
	Mod, /// %
	DoubleAdd,/// ++
	DoubleSub,/// --
	ColonIn, /// ':>'
	InColon, /// '<:'
	Not,/// '!'
	And,/// '&&'
	Or,/// '||'
	Xor,/// '^^'
	BinOr,/// '|'
	BinXor,/// '^'
	BinAnd,/// '&'
	Complement,/// '~'
	Shift,/// '>>>'
	ShiftLeft,
	ShiftRight,
	Equal,
	Equals,
	NotEqual,
	DeepEqual,
	NotDeepEqual,
	GreatEqual,
	LessEqual,
	Great,
	Less,
	Interval,/// ..
	Assign,
	AddAssign,
	SubAssign,
	MulAssign,
	DivAssign,
	ExpAssign,
	ModAssign,
	RevDivAssign,/// '\='
	AndAssign,/// '&&='
	OrAssign,/// '||='
	XorAssign,/// '^^='
	BinOrAssign,/// '|='
	BinXorAssign,/// '^='
	BinAndAssign,/// '&='
	ComplementAssign,/// '~='
	ShiftAssign,/// '>>>='
	ShiftLeftAssign,
	ShiftRightAssign,

	BraceOpen,/// '{'
	BraceClose,/// '}'
	Comma,
	Colon,/// ':'
	Dot,
	SemiColon,
	BracketOpen,/// '['
	BracketClose,/// ']'
	ParenOpen,
	ParenClose,
	QuestionMark,
	At,/// '@'
	RightArrow,/// '->'
	LeftArrow,/// '<-'
	Regex,
	New,
	TokenTypeCount
);


DECLARE_ENUM_WITH_TYPE (
    TokenKind,
    uint32_t,
    /// begin of enumerated class
	End             = 0,
	Name            = 1,
	Number          = 2,
	String          = 3,
	Boolean         = 4,
	NewLine         = 5,
	Indent          = 6,
	Dedent          = 7,
	LeftParen       = 8,
	RightParen      = 9,
	LeftBracket     = 10,
	RightBracket    = 11,
	Colon           = 12,
	Comma           = 13,
	SemiColon       = 14,
	Plus            = 15,
	Minus           = 16,
	Star            = 17,
	Slash           = 18,
	BinOr           = 19,
	BinAnd          = 20,
	Less            = 21,
	Greater         = 22,
	Assign          = 23,
	Dot             = 24,
	Percent         = 25,
	BackQuote       = 26,
	LeftBrace       = 27,
	RightBrace      = 28,
	Equal           = 29,
	NotEqual        = 30,
	LessEqual       = 31,
	GreaterEqual    = 32,
	Tilde           = 33,
	Interval        = 34,
	LeftShift       = 35,
	RightShift      = 36,
	DoubleStar      = 37,
	PlusEqual       = 38,
	MinusEqual      = 39,
	StarEqual       = 40,
	SlashEqual      = 41,
	PercentEqual    = 42,
	BinAndEqual     = 43,
	BinOrEqual      = 44,
	TildeEqual      = 45,
	LeftShiftEqual  = 46,
	RightShiftEqual = 47,
	DoubleStarEqual = 48,
	AntiSlash       = 49,
	AntiSlashEqual  = 50,
	DoublePlus      = 51,
	DoubleMinus     = 52,
	BinXor          = 53,
	BinXorEqual     = 54,
	Not             = 55,
	Or              = 56,
	Xor             = 57,
	And             = 58,
	OrEqual         = 59,
	XorEqual        = 60,
	AndEqual        = 61,
	Shift           = 62,
	ShiftEqual      = 63,
	DeepEqual       = 64,
	NotDeepEqual    = 65,
	Modifier        = 66,
	Ellipsis        = 67,
	At              = 68,
	Operator        = 69,
	Error           = 70,
	Block           = 71,
	Undefined       = 72,
	Ref             = 73,
	Exp             = 74,
	ExpEqual        = 75,
	/// Let this be at the end
	Fun,
	Fn,
	EndBlock,
	Comment,
	Whitespace,
	QuestionMark,
	RightArrow,
	LeftArrow,
	ColonIn,
	InColon,
	Identifier,
	Pass,
	Invalid,
	Regex,
	New,
	TokenKindCount,
);

DECLARE_ENUM_WITH_TYPE(
    TokenClass,
    uint32_t,
    /// begin of enumerated class
	Default,
	Identifier,
	Operator,
	Relational,
	Assignment,
	Keyword,
	Delimiter,
	Literal,
	Invalid,
	Eof
);

/**
*
* This is an interface for various tokens.
* To define a new kind of tokens just inherit from this class
*
**/
struct IToken {

    virtual ~IToken() {
    }

    virtual bool isAssignment() const    = 0;/// the token is an assignment operator
    virtual bool isKeyWord() const       = 0;/// the token is a key word
    virtual Location location() const    = 0;/// the line and column where this token was defined.
    virtual std::string fileName() const = 0;/// the file where this token was defined.
    virtual TokenType   type() const     = 0;/// the type of this token.
    virtual TokenKind   kind() const     = 0;/// the kind of this token.
    virtual TokenClass  clazz() const    = 0;/// the class of this token.

};

}

#endif // __ITOKEN__HPP

