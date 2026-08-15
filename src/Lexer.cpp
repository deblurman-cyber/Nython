#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#include "Util.hpp"
#include "Lexer.hpp"
#include "Except.hpp"
// fmt provided by Definitions.hpp
#include "PrettyPrinter.hpp"
#include "DynamicLang.hpp"
#include <sstream>
// ^ explicit: libstdc++ supplies these transitively, MinGW does not.

using namespace nython::utils;
using nython::lexer::Location;
using nython::exception::UnexpectedCharError;

namespace nython::lexer {

static char const *level[] = {"Information", "Warning", "Error"};

std::map<TokenType,std::string> Warnings = {
    {TokenType::NotMultipleOfFourIndentError,"NotMultipleOfFourIndentError"},
	{TokenType::MixedIndentError,"MixedIndentError"},
	{TokenType::IndentationError,"IndentationError"},
	{TokenType::DedentationError,"DedentationError"},
	{TokenType::LineContinuationError,"LineContinuationError"},
	{TokenType::UnterminatedStringError,"UnterminatedStringError"},
};

std::map<TokenType,std::string> TokenTypeNames = {
	{TokenType::End,"End"},{TokenType::NewLine,"NewLine"},{TokenType::Indent,"Indent"},{TokenType::Dedent,"Dedent"},{TokenType::Comment,"Comment"},
	{TokenType::Identifier,"Identifier"},{TokenType::Float,"Float"},{TokenType::Integer,"Integer"},{TokenType::Hex,"Hex"},{TokenType::Oct,"Oct"},{TokenType::Binary,"Binary"},
	{TokenType::Complex,"Complex"},{TokenType::String,"String"},{TokenType::True,"True"},{TokenType::False,"False"},{TokenType::None,"None"},{TokenType::Not,"Not"},{TokenType::And,"And"},
	{TokenType::Or,"Or"},{TokenType::Xor,"Xor"},{TokenType::Class,"Class"},{TokenType::Abstract,"Abstract"},{TokenType::Continue,"Continue"},{TokenType::If,"If"},{TokenType::Else,"Else"},{TokenType::ElseIf,"ElseIf"},{TokenType::For,"For"},{TokenType::Default,"Default"},{TokenType::Do,"Do"},{TokenType::Extends,"Extends"},{TokenType::Finally,"Finally"},{TokenType::Final,"Final"},{TokenType::Implements,"Implements"},{TokenType::Import,"Import"},
	{TokenType::In,"In"},{TokenType::Pass,"Pass"},{TokenType::Instanceof,"Instanceof"},{TokenType::Subclassof,"Subclassof"},{TokenType::Parentof,"Parentof"},{TokenType::Interface,"Interface"},{TokenType::Package,"Package"},
	{TokenType::NameSpace,"NameSpace"},{TokenType::Private,"Private"},{TokenType::Protected,"Protected"},{TokenType::Public,"Public"},{TokenType::Return,"Return"},{TokenType::Static,"Static"},
	{TokenType::Super,"Super"},{TokenType::Switch,"Switch"},{TokenType::This,"This"},{TokenType::Self,"Self"},{TokenType::Raise,"Raise"},{TokenType::Try,"Try"},
	{TokenType::While,"While"},{TokenType::Def,"Def"},{TokenType::Function,"Function"},{TokenType::Break,"Break"},{TokenType::With,"With"},
	{TokenType::As,"As"},{TokenType::Assert,"Assert"},{TokenType::Lambda,"Lambda"},{TokenType::Case,"Case"},{TokenType::Use,"Use"},
	{TokenType::Enum,"Enum"},{TokenType::Except,"Except"},{TokenType::Print,"Print"},{TokenType::Yield,"Yield"},{TokenType::Is,"Is"},
	{TokenType::From,"From"},{TokenType::Unless,"Unless"},{TokenType::Repeat,"Repeat"},{TokenType::Until,"Until"},{TokenType::Loop,"Loop"},
	{TokenType::Delete,"Delete"},{TokenType::Sizeof,"Sizeof"},{TokenType::Typeof,"Typeof"},{TokenType::Global,"Global"},
	{TokenType::Execute,"Execute"},{TokenType::Ellipsis,"Ellipsis"},{TokenType::Add,"Add"},{TokenType::Sub,"Sub"},{TokenType::Mul,"Mul"},
	{TokenType::Div,"Div"},{TokenType::RevDiv,"RevDiv"},{TokenType::Exp,"Exp"},{TokenType::Mod,"Mod"},{TokenType::DoubleAdd,"DoubleAdd"},
	{TokenType::DoubleSub,"DoubleSub"},{TokenType::Not,"Not"},{TokenType::BinOr,"BinOr"},{TokenType::BinXor,"BinXor"},{TokenType::BinAnd,"BinAnd"},
	{TokenType::Complement,"Complement"},{TokenType::Shift,"Shift"},{TokenType::ShiftLeft,"ShiftLeft"},
	{TokenType::ShiftRight,"ShiftRight"},{TokenType::Equal,"Equal"},{TokenType::NotEqual,"NotEqual"},{TokenType::DeepEqual,"DeepEqual"},
	{TokenType::NotDeepEqual,"NotDeepEqual"},{TokenType::GreatEqual,"GreatEqual"},{TokenType::LessEqual,"LessEqual"},
	{TokenType::Great,"Great"},{TokenType::Less,"Less"},{TokenType::Interval,"Interval"},{TokenType::Assign,"Assign"},{TokenType::AddAssign,"AddAssign"},
	{TokenType::SubAssign,"SubAssign"},{TokenType::MulAssign,"MulAssign"},{TokenType::DivAssign,"DivAssign"},{TokenType::ExpAssign,"ExpAssign"},
	{TokenType::ModAssign,"ModAssign"},{TokenType::RevDivAssign,"RevDivAssign"},{TokenType::AndAssign,"AndAssign"},{TokenType::OrAssign,"OrAssign"},
	{TokenType::XorAssign,"XorAssign"},{TokenType::BinOrAssign,"BinOrAssign"},{TokenType::BinXorAssign,"BinXorAssign"},
	{TokenType::BinAndAssign,"BinAndAssign"},{TokenType::ComplementAssign,"ComplementAssign"},{TokenType::ShiftAssign,"ShiftAssign"},
	{TokenType::ShiftLeftAssign,"ShiftLeftAssign"},{TokenType::ShiftRightAssign,"ShiftRightAssign"},{TokenType::BraceOpen,"BraceOpen"},
	{TokenType::BraceClose,"BraceClose"},{TokenType::Comma,"Comma"},{TokenType::Colon,"Colon"},{TokenType::Dot,"Dot"},{TokenType::SemiColon,"SemiColon"},
	{TokenType::BracketOpen,"BracketOpen"},{TokenType::BracketClose,"BracketClose"},{TokenType::ParenOpen,"ParenOpen"},{TokenType::Regex,"Regex"},{TokenType::New,"New"},
	{TokenType::ParenClose,"ParenClose"},{TokenType::At,"At"},{TokenType::RightArrow,"RightArrow"},{TokenType::LeftArrow,"LeftArrow"},{TokenType::Var,"Var"},{TokenType::Block,"Block"},
	{TokenType::Const,"Const"},{TokenType::Let,"Let"},{TokenType::Undefined,"Undefined"},{TokenType::Ref,"Ref"},{TokenType::QuestionMark,"QuestionMark"},{TokenType::Comment,"Comment"}
};

static const TokenDef KeywordTokens[] = {
	TokenDef(TokenType::False,std::string("false"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::None, std::string("none"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Undefined, std::string("undefined"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::True, std::string("true"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Not, std::string("not"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Or, std::string("or"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::And, std::string("and"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Xor, std::string("xor"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Block, std::string("block"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Class, std::string("class"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Interface, std::string("interface"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Package, std::string("package"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::NameSpace, std::string("namespace"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Enum, std::string("enum"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Use, std::string("use"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Abstract, std::string("abstract"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Continue, std::string("continue"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::If, std::string("if"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Else, std::string("else"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::ElseIf, std::string("elif"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::For, std::string("for"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Default, std::string("default"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Do, std::string("do"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Then, std::string("then"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Extends, std::string("extends"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Inherits, std::string("inherits"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Implements, std::string("implements"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Finally, std::string("finally"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Final, std::string("final"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Import, std::string("import"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::In, std::string("in"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Pass, std::string("pass"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Instanceof, std::string("instanceof"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Subclassof, std::string("subclassof"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Parentof, std::string("parentof"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Public, std::string("public"), TokenKind::Modifier, TokenClass::Keyword),
	TokenDef(TokenType::Private, std::string("private"), TokenKind::Modifier, TokenClass::Keyword),
	TokenDef(TokenType::Protected, std::string("protected"), TokenKind::Modifier, TokenClass::Keyword),
	TokenDef(TokenType::Static, std::string("static"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Return, std::string("return"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Super, std::string("super"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Switch, std::string("switch"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Switch, std::string("match"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Async, std::string("async"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Await, std::string("await"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::This, std::string("this"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Self, std::string("self"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Raise, std::string("raise"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Try, std::string("try"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::While, std::string("while"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Def, std::string("def"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Function, std::string("function"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Break, std::string("break"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::With, std::string("with"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::As, std::string("as"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Assert, std::string("assert"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Lambda, std::string("lambda"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Case, std::string("case"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Except, std::string("except"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Print, std::string("print"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Yield, std::string("yield"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Is, std::string("is"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::From, std::string("from"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Unless, std::string("unless"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Repeat, std::string("repeat"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Until, std::string("until"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Loop, std::string("loop"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Delete, std::string("delete"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Delete, std::string("del"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Sizeof, std::string("sizeof"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Typeof, std::string("typeof"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Global, std::string("global"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Execute, std::string("execute"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Var, std::string("var"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Const, std::string("const"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Let, std::string("let"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Ref, std::string("ref"), TokenKind::Name, TokenClass::Keyword),
	TokenDef(TokenType::Equals,std::string("equals"), TokenKind::Equal, TokenClass::Keyword),
	TokenDef(TokenType::Pass,std::string("pass"), TokenKind::Pass, TokenClass::Keyword),
	TokenDef(TokenType::EndBlock,std::string("end"), TokenKind::EndBlock, TokenClass::Keyword),
	TokenDef(TokenType::Fun,std::string("fun"), TokenKind::Fun, TokenClass::Keyword),
	TokenDef(TokenType::Fn,std::string("fn"), TokenKind::Fn, TokenClass::Keyword),
	TokenDef(TokenType::Fn,std::string("func"), TokenKind::Fn, TokenClass::Keyword),
	TokenDef(TokenType::New,std::string("new"), TokenKind::Fn, TokenClass::Keyword),
	// ── Multi-paradigm aliases ──────────────────────────────────────────────
	// JS/C++ "throw" is an alias for Python/Nython "raise"
	TokenDef(TokenType::Raise,std::string("throw"), TokenKind::Name, TokenClass::Keyword),
	// ...and "catch" for "except", so the JS/C++ spelling of the whole
	// construct works. Without this, `throw` parsed but `catch` did not, so
	// try/throw/catch — the form the alias above invites — was a syntax error.
	TokenDef(TokenType::Except,std::string("catch"), TokenKind::Name, TokenClass::Keyword),
	// JS/C "null" is an alias for Nython/Python "none"
	TokenDef(TokenType::None,std::string("null"), TokenKind::Name, TokenClass::Keyword),
	// Lua "elseif" as alias for "elif"
	TokenDef(TokenType::ElseIf,std::string("elseif"), TokenKind::Name, TokenClass::Keyword)
};

TokenDef DelimTokens[] = {
	TokenDef(TokenType::BraceOpen, std::string("{"), TokenKind::LeftBrace, TokenClass::Delimiter),
	TokenDef(TokenType::BraceClose, std::string("}"), TokenKind::RightBrace, TokenClass::Delimiter),
	TokenDef(TokenType::Comma, std::string(","), TokenKind::Comma, TokenClass::Delimiter),
	TokenDef(TokenType::Colon, std::string(":"), TokenKind::Colon, TokenClass::Delimiter),
	TokenDef(TokenType::ColonIn, std::string(":>"), TokenKind::ColonIn, TokenClass::Delimiter),
	TokenDef(TokenType::InColon, std::string("<:"), TokenKind::InColon, TokenClass::Delimiter),
	TokenDef(TokenType::Dot, std::string("."), TokenKind::Dot, TokenClass::Delimiter),
	TokenDef(TokenType::SemiColon, std::string(";"), TokenKind::SemiColon, TokenClass::Delimiter),
	TokenDef(TokenType::BracketOpen, std::string("["), TokenKind::LeftBracket, TokenClass::Delimiter),
	TokenDef(TokenType::BracketClose, std::string("]"), TokenKind::RightBracket, TokenClass::Delimiter),
	TokenDef(TokenType::ParenOpen, std::string("("), TokenKind::LeftParen, TokenClass::Delimiter),
	TokenDef(TokenType::ParenClose, std::string(")"), TokenKind::RightParen, TokenClass::Delimiter)
};

TokenDef OpTokens[] = {

	/// level 4
	TokenDef(TokenType::ShiftAssign     , std::string(">>>=") , TokenKind::ShiftEqual     , TokenClass::Assignment),
	/// level 3
	TokenDef(TokenType::Ellipsis        , std::string("...")  , TokenKind::Ellipsis       , TokenClass::Operator),
	TokenDef(TokenType::Shift           , std::string(">>>")  , TokenKind::Shift	      , TokenClass::Operator),
	TokenDef(TokenType::DeepEqual       , std::string("===")  , TokenKind::DeepEqual      , TokenClass::Relational),
	TokenDef(TokenType::NotDeepEqual    , std::string("!==")  , TokenKind::NotDeepEqual   , TokenClass::Relational),
	TokenDef(TokenType::ExpAssign       , std::string("**=")  , TokenKind::DoubleStarEqual, TokenClass::Assignment),
	TokenDef(TokenType::AndAssign       , std::string("&&=")  , TokenKind::AndEqual       , TokenClass::Assignment),
	TokenDef(TokenType::OrAssign        , std::string("||=")  , TokenKind::OrEqual        , TokenClass::Assignment),
	TokenDef(TokenType::XorAssign       , std::string("^^=")  , TokenKind::XorEqual       , TokenClass::Assignment),
	TokenDef(TokenType::ShiftLeftAssign , std::string("<<=")  , TokenKind::LeftShiftEqual , TokenClass::Assignment),
	TokenDef(TokenType::ShiftRightAssign, std::string(">>=")  , TokenKind::RightShiftEqual, TokenClass::Assignment),
	/// level 2
	TokenDef(TokenType::Interval        , std::string("..")   , TokenKind::Interval       , TokenClass::Operator),
	TokenDef(TokenType::Exp	            , std::string("**")   , TokenKind::DoubleStar     , TokenClass::Operator),
	TokenDef(TokenType::DoubleAdd       , std::string("++")   , TokenKind::Percent	      , TokenClass::Operator),
	TokenDef(TokenType::DoubleSub       , std::string("--")   , TokenKind::Percent	      , TokenClass::Operator),
	TokenDef(TokenType::And 	        , std::string("&&")   , TokenKind::And		      , TokenClass::Operator),
	TokenDef(TokenType::Or  	        , std::string("||")   , TokenKind::Or 		      , TokenClass::Operator),
	TokenDef(TokenType::Xor 	        , std::string("^^")   , TokenKind::Xor		      , TokenClass::Operator),
	TokenDef(TokenType::ShiftLeft       , std::string("<<")   , TokenKind::LeftShift      , TokenClass::Operator),
	TokenDef(TokenType::ShiftRight      , std::string(">>")   , TokenKind::RightShift     , TokenClass::Operator),
	TokenDef(TokenType::GreatEqual      , std::string(">=")   , TokenKind::GreaterEqual   , TokenClass::Relational),
	TokenDef(TokenType::LessEqual       , std::string("<=")   , TokenKind::LessEqual      , TokenClass::Relational),
	TokenDef(TokenType::Equal	        , std::string("==")   , TokenKind::Equal          , TokenClass::Relational),
	TokenDef(TokenType::NotEqual        , std::string("!=")   , TokenKind::NotEqual       , TokenClass::Relational),
	TokenDef(TokenType::AddAssign       , std::string("+=")   , TokenKind::PlusEqual      , TokenClass::Assignment),
	TokenDef(TokenType::SubAssign       , std::string("-=")   , TokenKind::MinusEqual     , TokenClass::Assignment),
	TokenDef(TokenType::MulAssign       , std::string("*=")   , TokenKind::StarEqual      , TokenClass::Assignment),
	TokenDef(TokenType::DivAssign       , std::string("/=")   , TokenKind::SlashEqual     , TokenClass::Assignment),
	TokenDef(TokenType::RevDivAssign    , std::string("\\=")  , TokenKind::AntiSlashEqual , TokenClass::Assignment),
	TokenDef(TokenType::ModAssign       , std::string("%=")   , TokenKind::PercentEqual   , TokenClass::Assignment),
	TokenDef(TokenType::ComplementAssign, std::string("~=")   , TokenKind::TildeEqual     , TokenClass::Assignment),
	TokenDef(TokenType::BinAndAssign    , std::string("&=")   , TokenKind::BinAndEqual    , TokenClass::Assignment),
	TokenDef(TokenType::BinOrAssign     , std::string("|=")   , TokenKind::BinOrEqual     , TokenClass::Assignment),
	TokenDef(TokenType::BinXorAssign    , std::string("^=")   , TokenKind::BinXorEqual    , TokenClass::Assignment),
	TokenDef(TokenType::RightArrow      , std::string("->")   , TokenKind::RightArrow     , TokenClass::Operator),
	TokenDef(TokenType::LeftArrow       , std::string("<-")   , TokenKind::LeftArrow      , TokenClass::Operator),
	/// level one
	TokenDef(TokenType::BinAnd	        , std::string("&")    , TokenKind::BinAnd	      , TokenClass::Operator),
	TokenDef(TokenType::BinOr	        , std::string("|")    , TokenKind::BinOr 	      , TokenClass::Operator),
	TokenDef(TokenType::BinXor	        , std::string("^")    , TokenKind::BinXor  	      , TokenClass::Operator),
	TokenDef(TokenType::Complement      , std::string("~")    , TokenKind::Tilde	      , TokenClass::Operator),
	TokenDef(TokenType::Mod	            , std::string("%")    , TokenKind::Percent	      , TokenClass::Operator),
	TokenDef(TokenType::Add	            , std::string("+")    , TokenKind::Plus		      , TokenClass::Operator),
	TokenDef(TokenType::Sub	            , std::string("-")    , TokenKind::Minus	      , TokenClass::Operator),
	TokenDef(TokenType::Mul	            , std::string("*")    , TokenKind::Star		      , TokenClass::Operator),
	TokenDef(TokenType::Div	            , std::string("/")    , TokenKind::Slash	      , TokenClass::Operator),
	TokenDef(TokenType::RevDiv          , std::string("\\")   , TokenKind::AntiSlash      , TokenClass::Operator),
	TokenDef(TokenType::At              , std::string("@")    , TokenKind::At             , TokenClass::Operator),
	TokenDef(TokenType::Not	            , std::string("!")    , TokenKind::Not		      , TokenClass::Relational),
	TokenDef(TokenType::Great           , std::string(">")    , TokenKind::Greater        , TokenClass::Relational),
	TokenDef(TokenType::Less            , std::string("<")    , TokenKind::Less			  , TokenClass::Relational),
	TokenDef(TokenType::Assign		    , std::string("=")	  , TokenKind::Assign         , TokenClass::Assignment),
};

inline ConstArray<TokenDef const> Ops() {
	return { OpTokens };
}

inline ConstArray<TokenDef const> Delims() {
	return { DelimTokens };
}

inline ConstArray<TokenDef const> Keywords() {
	return { KeywordTokens };
}

inline bool is_ident_char(char c, bool first = false) {
	unsigned char uc = static_cast<unsigned char>(c);
	// Accept ASCII letters, underscore
	if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_') return true;
	// Accept digits (not as first char)
	if (!first && (c >= '0' && c <= '9')) return true;
	// Accept UTF-8 multi-byte sequences (emoji, CJK, Greek, etc.)
	// Any byte >= 0x80 is part of a UTF-8 multi-byte character
	if (uc >= 0x80) return true;
	// Accept $ for JS-style identifiers
	if (c == '$') return true;
	return false;
}

inline bool is_digit(char c) {
	return (c >= '0' && c <= '9');
}

inline bool is_hex(char c) {
	return is_digit(c)
		|| (c >= 'A' && c <= 'F')
		|| (c >= 'a' && c <= 'f');
}

inline char hex2num(char c) {
        if(!is_hex(c)) {
            return '\xff';
        }
        if(c >= '0' && c <= '9') {
            return c - '0';
        }
        c = tolower(c);
        return (c - 'a') + 10;
}

inline bool is_number(char c0, char c1, char c2) {
	return is_digit(c0)
		|| (c0 == '.' && is_digit(c1))
		|| (c0 == '-' && is_digit(c1))
		|| (c0 == '-' && c1 == '.' && is_digit(c2));
}

inline std::string lexerInfoLevel(LexerInfoLevel info) {
    return level[int(info)];
}

Lexer::Lexer(SourceCode& source): source{source}, token{}, logger{} {
}

Lexer::~Lexer() {
}

bool Lexer::empty() {
    return tokens.empty();
}

void Lexer::reset() {
    reset_token();
    source.reset(0);
    first_indet_char         = 0;
    level_                   = 0;
    tab                      = TabSize;
    errors                   = 0;
    warnings                 = 0;
    indent                   = 0;
    current                  = 0;
    indent_stack             = {};
    tokens                   = {};
    info                     = {};
}

void Lexer::unexpectedChar() {
    Location location(source.location.row, source.location.column, source.fileName());
    logger << Log(
        LogType::error,
        "Unexpected Token Error",
        source.location.row,
        source.location.column
    );
    throw UnexpectedCharError(location, std::to_string(source.current_char));
}

Token Lexer::next() {
    if(current>=int(tokens.size())) return Token();
    return tokens[current++];
}

Token Lexer::prev() {
    if(current <= 0) return Token();
    return tokens[current-1];
}

Token Lexer::curr() {
    if(current>=int(tokens.size()) || current < 0) return Token();
    return tokens[current];
}

Token Lexer::peek(int i) {
    if(current + i >= int(tokens.size()) || current + i < 0 ) {
        fmt::print("index out out range with value : {}\n", current + i);
        std::stringstream msg;
        msg << "index out out range with value : " << (current + i);
        throw std::runtime_error(msg.str());
    }
    return tokens[current + i];
}

std::string Lexer::code() {
    return source.sourceCode();
}

std::string Lexer::fileName() {
    return source.fileName();
}

void Lexer::reset_token() {
    source.location.reset(source.location.row, source.location.column);
    TokenIdent ident(TokenType::Invalid, TokenKind::Invalid, TokenClass::Invalid);
    token = Token(ident, "invalid" , source.location);
}

bool Lexer::isKeyWord(const std::string word) {
    for(auto kw:Keywords()) {
        if((kw.value.size() == word.size())&&(kw.value.c_str() == word)) {
            return true;
        }
    }
    return false;
}

bool Lexer::isOperator(const std::string word) {
    for(auto op:Ops()) {
        if((op.value.size() == word.size())&&(op.value.c_str() == word)) {
            return true;
        }
    }
    return false;
}

bool Lexer::isSeparator(const std::string word) {
    for(auto d:Delims()) {
        if((d.value.size() == word.size())&&(d.value.c_str() == word)) {
            return true;
        }
    }
    return false;
}

bool Lexer::isIdentifier(const std::string word) {
    bool ok = word.size()&&(is_ident_char(word[0],true)||word[0]=='$');
    for(unsigned i = 1;i<word.size();i++) {
        if(!is_ident_char(word[i])) return false;
    }
    return ok;
}

bool Lexer::is_ident_start(char cp) {
  return Lexer::is_alpha(cp) || cp == '_' || cp == '$';
}

bool Lexer::is_ident_part(char cp) {
  return Lexer::is_ident_start(cp) || Lexer::is_numeric(cp);
}

bool Lexer::is_alpha(char cp) {
  return Lexer::is_alpha_lowercase(cp) || Lexer::is_alpha_uppercase(cp);
}

bool Lexer::is_alpha_lowercase(char cp) {
  return (cp >= 0x41 && cp <= 0x5a);
}

bool Lexer::is_alpha_uppercase(char cp) {
  return (cp >= 0x61 && cp <= 0x7a);
}

bool Lexer::is_numeric(char cp) {
  return (cp >= 0x30 && cp <= 0x39);
}

bool Lexer::is_hex(char cp) {
  return Lexer::is_numeric(cp) || (cp >= 0x41 && cp <= 0x46) || (cp >= 0x61 && cp <= 0x66);
}

bool Lexer::is_octal(char cp) {
  return (cp >= 0x30 && cp <= 0x37);
}

bool Lexer::is_binary(char cp) {
  return (cp >= 0x30 && cp <= 0x31);
}

Token& Lexer::make_token(TokenIdent ident) {
	this->token.ident     = ident;
	this->token._location = source.location;
	return this->token;
}

Token& Lexer::make_token(TokenType id, TokenKind kind, TokenClass cls) {
	make_token({ id, kind, cls });
	return this->token;
}

void Lexer::dump() {
    fmt::print("{}\n", toString());
}

std::string Lexer::toString() {
    PrettyPrinter p;
    std::string str;
    p.print("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n",&str);
    p.print("<Tokens>\n",&str);
    p.indentRight();
    for(Token t:tokens) {
        str += t.writeToString(p);
    }
    p.indentLeft();
    p.print("</Tokens>",&str);
    return str;
}

inline std::vector<Token> optimize(std::vector<Token> tk) {
	std::vector<Token> ret;
	int nb = (int)tk.size();
	int paren_depth = 0;
	int paren_indent_delta = 0;

	for(auto i = 0; i < nb; ) {
        // Guard all tk[i+1] accesses with bounds check
        while(i < nb-1 && tk[i].type()==TokenType::NewLine && tk[i+1].type()==TokenType::NewLine) i++;
        if(i < nb-1 && tk[i].type()==TokenType::String && tk[i+1].type()==TokenType::String) {
            Token token = tk[i];
            while(i < nb-1 && tk[i].type()==TokenType::String && tk[i+1].type()==TokenType::String) {
                token.value.append(tk[i+1].value);
                i++;
            }
        }
        if(i >= nb) break;
        // Track paren/bracket/brace depth
        if(tk[i].type()==TokenType::ParenOpen || tk[i].type()==TokenType::BracketOpen || tk[i].type()==TokenType::BraceOpen) paren_depth++;
        if(tk[i].type()==TokenType::ParenClose || tk[i].type()==TokenType::BracketClose || tk[i].type()==TokenType::BraceClose) paren_depth--;
        if(paren_depth < 0) paren_depth = 0;
        // Multiline expression support: skip whitespace tokens inside balanced parens/brackets/braces
        if(paren_depth > 0) {
            if(tk[i].type()==TokenType::NewLine) { i++; continue; }
            if(tk[i].type()==TokenType::Indent) { paren_indent_delta++; i++; continue; }
            if(tk[i].type()==TokenType::Dedent) { paren_indent_delta--; i++; continue; }
        }
        // After closing last paren, consume extra Dedent tokens to rebalance
        if(paren_depth == 0 && paren_indent_delta > 0 && tk[i].type()==TokenType::NewLine) {
            ret.push_back(tk[i++]);
            while(i < nb && paren_indent_delta > 0 && tk[i].type()==TokenType::Dedent) {
                paren_indent_delta--;
                i++;
            }
            continue;
        }
        // Absorb Dedent that matches Indent we skipped inside parens
        if(paren_depth == 0 && paren_indent_delta > 0 && tk[i].type()==TokenType::Dedent) {
            paren_indent_delta--;
            i++; continue;
        }
        // Guard tk[i+1] access before using it
        if(i < nb-1 && tk[i].type()==TokenType::Comma && tk[i+1].type()==TokenType::NewLine) {
            ret.push_back(tk[i]);
            i += 2;
        } else {
            ret.push_back(tk[i++]);
        }
    }
	return ret;
}

std::vector<Token> Lexer::tokenize() {
    reset();
    if(source.line_number()<0) source.read();
    while (!source.isAtEnd()) { /// this->token.type() != TokenType::End
        this->read_token();
    }
    int col = 0;
    ///# Close all open blocks
	while(indent_stack.size()) {
		col = indent_stack[indent_stack.size() - 1];
		indent_stack.pop_back();
		this->token.value = std::to_string(col);
		make_token(TokenType::Dedent, TokenKind::Dedent, TokenClass::Delimiter);
		tokens.push_back(token);
	}
    this->token.value = "End";
    make_token(TokenType::End, TokenKind::End, TokenClass::Eof);
    tokens.push_back(this->token);
    tokens = optimize(tokens);
    return tokens;
}

void Lexer::read_token() {
    reset_token();
    source.reset_frame();
    bool potential_keyword = true;
    switch(source.read_char()) {
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9': {
            this->consume_numeric();
            break;
        }
        case '"':
		case '\'':
		case '`': {
		    potential_keyword = false;
            this->consume_string(source.current_char);
		    break;
		}
        case ' ':
        case '\t': {
        	bool should_indent = (source.getCurrent() - 1 == 0 ) or (source.peek_char(-1) == '\n');
        	this->consume_whitespace(should_indent);
        }
        break;
        case '\x0c': /// Allow form feed as \n
		case '\r':
        case '\n': {
            return this->consume_newline();
        }
        break;
		case ';': {
            this->token.value = ";";
            make_token(TokenType::SemiColon,TokenKind::SemiColon,TokenClass::Delimiter);
            break;
        }
        case ',': {
            this->token.value = ",";
            make_token(TokenType::Comma,TokenKind::Comma,TokenClass::Delimiter);
            break;
        }
        case '.': {
            if (Lexer::is_numeric(this->source.peek_char())) {
                this->consume_numeric();
            }else {
                if(source.peek_char()!='.') {
                    this->token.value = '.';
                    make_token(TokenType::Dot,TokenKind::Dot,TokenClass::Delimiter);
                } else {
                    if(source.peek_char(1)!='.') {
                        source.read_char();
                        this->token.value = "..";
                        make_token(TokenType::Interval,TokenKind::Interval,TokenClass::Delimiter);
                    } else {
                        source.read_char();
                        source.read_char();
                        this->token.value = "...";
                        make_token(TokenType::Ellipsis,TokenKind::Ellipsis,TokenClass::Default);
                    }
                }
            }
            break;
        }
        case '(': {
        	++level_;
            this->token.value = "(";
            bracket_depth++; make_token(TokenType::ParenOpen,TokenKind::LeftParen,TokenClass::Default);
          break;
        }
        case ')': {
        	--level_;
            this->token.value = ")";
            if(bracket_depth>0) bracket_depth--; make_token(TokenType::ParenClose,TokenKind::RightParen,TokenClass::Default);
          break;
        }
        case '{': {
        	++level_;
            this->token.value = "{";
            bracket_depth++; make_token(TokenType::BraceOpen,TokenKind::LeftBrace,TokenClass::Default);
          break;
        }
        case '}': {
        	--level_;
            this->token.value = "}";
            if(bracket_depth>0) bracket_depth--; make_token(TokenType::BraceClose,TokenKind::RightBrace,TokenClass::Default);
          break;
        }
        case '[': {
        	++level_;
            this->token.value = "[";
            bracket_depth++; make_token(TokenType::BracketOpen,TokenKind::LeftBracket,TokenClass::Default);
          }
        break;
        case ']': {
        	--level_;
            this->token.value = "]";
            if(bracket_depth>0) bracket_depth--; make_token(TokenType::BracketClose,TokenKind::RightBracket,TokenClass::Default);
          break;
        }
        case '?': {
            this->token.value = "?";
            make_token(TokenType::QuestionMark,TokenKind::QuestionMark,TokenClass::Delimiter);
          break;
        }
        case ':': {
            if(source.peek_char()=='=') {
                // Walrus operator :=
                source.read_char(); // consume '='
                this->token.value = ":=";
                make_token(TokenType::Assign,TokenKind::Assign,TokenClass::Operator);
            } else if(source.peek_char()!='>') {
                 this->token.value = ":";
                make_token(TokenType::Colon,TokenKind::Colon,TokenClass::Delimiter);
            } else {
                source.read_char();
                this->token.value = ":>";
                make_token(TokenType::ColonIn,TokenKind::ColonIn,TokenClass::Delimiter);
            }
          break;
        }
        case '@': {
              if (this->source.peek_char() == '"') {
                potential_keyword = false;
                source.read_char();
                this->consume_string(source.current_char);
                this->token.type(TokenType::Identifier);
              } else {
                this->token.value = "@";
                make_token(TokenType::At,TokenKind::At,TokenClass::Delimiter);
              }
            break;
        }
        case '&': {
            switch (this->source.peek_char()) {
                case '&': {
                    this->source.read_char();
                    switch (this->source.peek_char()) {
                         case '=':{
                            this->token.value = "&&=";
                            this->source.read_char();
                            make_token(TokenType::AndAssign,TokenKind::AndEqual,TokenClass::Assignment);
                         }
                         break;
                         default: {
                            this->token.value = "&&";
                            make_token(TokenType::And,TokenKind::And,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
                default: {
                    switch (this->source.peek_char()) {
                         case '=':{
                            this->token.value = "&=";
                            this->source.read_char();
                            make_token(TokenType::BinAndAssign,TokenKind::BinAndEqual,TokenClass::Assignment);
                         }
                         break;
                         default: {
                            this->token.value = "&";
                            make_token(TokenType::BinAnd,TokenKind::BinAnd,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
          }
        break;
        }
        case '|': {
            switch (this->source.peek_char()) {
                case '|': {
                    this->source.read_char();
                    switch (this->source.peek_char()) {
                         case '=': {
                            this->token.value = "||=";
                            this->source.read_char();
                            make_token(TokenType::OrAssign,TokenKind::OrEqual,TokenClass::Assignment);
                         }
                         break;
                         default: {
                            this->token.value = "||";
                            make_token(TokenType::Or,TokenKind::Or,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
                default: {
                    switch (this->source.peek_char()) {
                         case '=':{
                            this->token.value = "|=";
                            this->source.read_char();
                            make_token(TokenType::BinOrAssign,TokenKind::BinOrEqual,TokenClass::Assignment);
                         }
                         break;
                         default: {
                            this->token.value = "|";
                            make_token(TokenType::BinOr,TokenKind::BinOr,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
          }
        break;
        }
        case '^': {
            switch (this->source.peek_char()) {
                case '^': {
                    this->source.read_char();
                    switch (this->source.peek_char()) {
                         case '=':{
                            this->token.value = "^^=";
                            this->source.read_char();
                            make_token(TokenType::XorAssign,TokenKind::XorEqual,TokenClass::Assignment);
                         }
                         break;
                         default: {
                            this->token.value = "^^";
                            make_token(TokenType::Xor,TokenKind::Xor,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
                default: {
                    switch (this->source.peek_char()) {
                         case '=':{
                            this->token.value = "^=";
                            this->source.read_char();
                            make_token(TokenType::BinXorAssign,TokenKind::BinXorEqual,TokenClass::Assignment);
                         }
                         break;
                         case '/':{
                            this->consume_regex(source.current_char);
                         }
                         break;
                         default: {
                            this->token.value = "^";
                            make_token(TokenType::BinXor,TokenKind::BinXor,TokenClass::Operator);
                        }
                        break;
                    }
                    break;
                }
          }
        break;
        }
        case '~': {
            switch (this->source.peek_char()) {
                case '=': {
                    this->token.value = "~=";
                    this->source.read_char();
                    make_token(TokenType::ComplementAssign,TokenKind::TildeEqual,TokenClass::Assignment);
                break;
                }
                default:
                    this->token.value = "~";
                    make_token(TokenType::Complement,TokenKind::Tilde,TokenClass::Operator);
                break;
            }
        break;
        }
        case '!': {
            switch (this->source.peek_char()) {
                case '=': {
                    this->source.read_char();
                    switch (this->source.peek_char()) {
                         case '=': {
                            this->token.value = "!==";
                            this->source.read_char();
                            make_token(TokenType::NotDeepEqual,TokenKind::NotDeepEqual,TokenClass::Relational);
                         break;
                         }
                         default: {
                            this->token.value = "!=";
                            make_token(TokenType::NotEqual,TokenKind::NotEqual,TokenClass::Relational);
                        break;
                        }
                    }
                break;
                }
                default: {
                    this->token.value = "!";
                    make_token(TokenType::Not,TokenKind::Not,TokenClass::Relational);
                break;
                }
            }
            break;
        }
        case '>': {
            switch (this->source.peek_char()) {
                case '=': {
                    this->token.value = ">=";
                    this->source.read_char();
                    make_token(TokenType::GreatEqual,TokenKind::GreaterEqual,TokenClass::Relational);
                break;
                }
                case '>': {
                    this->source.read_char();
                    this->consume_right_shift();
                break;
                }
                default: {
                    this->token.value = ">";
                    make_token(TokenType::Great,TokenKind::Greater,TokenClass::Relational);
                break;
                }
              }
        break;
        }
        case '<': {
            switch (this->source.peek_char()) {
                case '=': {
                    this->token.value = "<=";
                    this->source.read_char();
                    make_token(TokenType::LessEqual,TokenKind::LessEqual,TokenClass::Relational);
                break;
                }
                case '-': {
                    this->token.value = "<-";
                    this->source.read_char();
                    make_token(TokenType::LeftArrow,TokenKind::LeftArrow,TokenClass::Delimiter);
                break;
                }
                case '<':
                    this->source.read_char();
                    this->consume_left_shift();
                break;
                case ':': {
                    this->token.value = "<:";
                    this->source.read_char();
                    make_token(TokenType::InColon,TokenKind::InColon,TokenClass::Delimiter);
                break;
                }
                default: {
                    this->token.value = "<";
                    make_token(TokenType::Less,TokenKind::Less,TokenClass::Relational);
                break;
                }
            }
        break;
        }
        case '%': {
            switch (this->source.peek_char()) {
                case '=': {
                    this->token.value = "%=";
                    this->source.read_char();
                    make_token(TokenType::ModAssign,TokenKind::PercentEqual,TokenClass::Assignment);
                    break;
                }
                default:
                    this->token.value = "%";
                    make_token(TokenType::Mod,TokenKind::Percent,TokenClass::Operator);
                break;
            }
          break;
        }
        case '=': {
            switch (this->source.peek_char()) {
                case '=': {
                  this->source.read_char();
                  if(source.peek_char()=='=') {
                    this->source.read_char();
                    this->token.value = "==";
                    make_token(TokenType::DeepEqual,TokenKind::DeepEqual,TokenClass::Relational);
                  } else make_token(TokenType::Equal,TokenKind::Equal,TokenClass::Relational);
                  break;
                }
                case '>': {
                    this->token.value = "=>";
                    this->source.read_char();
                    // Fat-arrow: JS/C++ arrow function syntax  x => expr  or  (p) => expr
                    make_token(TokenType::RightArrow,TokenKind::RightArrow,TokenClass::Operator);
                  break;
                }
                default: {
                    this->token.value = "=";
                    make_token(TokenType::Assign,TokenKind::Assign,TokenClass::Assignment);
                  break;
                }
            }
            break;
        }
        /// + -  *
        case '+': {
            switch (this->source.peek_char()) {
                case '+': {
                  this->token.value = "++";
                  this->source.read_char();
                  make_token(TokenType::DoubleAdd,TokenKind::DoublePlus,TokenClass::Operator);
                  break;
                }
                case '=': {
                    this->token.value = "+=";
                    this->source.read_char();
                    make_token(TokenType::AddAssign,TokenKind::PlusEqual,TokenClass::Assignment);
                  break;
                }
                default: {
                    this->token.value = "+";
                    make_token(TokenType::Add,TokenKind::Plus,TokenClass::Operator);
                  break;
                }
            }
            break;
        }
        case '-': {
            switch (this->source.peek_char()) {
                case '-': {
                  this->token.value = "--";
                  this->source.read_char();
                  make_token(TokenType::DoubleSub,TokenKind::DoubleMinus,TokenClass::Operator);
                  break;
                }
                case '=': {
                    this->token.value = "-=";
                    this->source.read_char();
                    make_token(TokenType::SubAssign,TokenKind::MinusEqual,TokenClass::Assignment);
                  break;
                }
                 case '>': {
                    this->token.value = "->";
                    this->source.read_char();
                    make_token(TokenType::RightArrow,TokenKind::RightArrow,TokenClass::Operator);
                  break;
                }
                default: {
                    this->token.value = "-";
                    make_token(TokenType::Sub,TokenKind::Minus,TokenClass::Operator);
                  break;
                }
            }
            break;
        }
        case '*': {
            switch (this->source.peek_char()) {
                case '*': {
                  this->source.read_char();
                  if(source.peek_char() == '=') {
                    this->source.read_char();
                    this->token.value = "**=";
                    make_token(TokenType::ExpAssign,TokenKind::ExpEqual,TokenClass::Operator);
                  } else {
                    this->token.value = "**";
                    make_token(TokenType::Exp,TokenKind::Exp,TokenClass::Operator);
                  }
                  break;
                }
                case '=': {
                    this->token.value = "*=";
                    this->source.read_char();
                    make_token(TokenType::MulAssign,TokenKind::StarEqual,TokenClass::Assignment);
                  break;
                }
                default: {
                    this->token.value = "*";
                    make_token(TokenType::Mul,TokenKind::Star,TokenClass::Operator);
                  break;
                }
            }
            break;
        }
        case '#': {
            token.value = "#";
            consume_comment();
        break;
        }
        case '/':{
            char c1 = source.read_char();
            switch(c1) {
                case '/': {
                    // Check for //= first (always floor div assign)
                    char c2 = source.peek_char();
                    if (c2 == '=') {
                        source.read_char(); // consume =
                        token.value = "//=";
                        make_token(TokenType::DivAssign, TokenKind::Assign, TokenClass::Operator);
                        break;
                    }
                    // Disambiguate: // as floor div vs // as comment
                    bool is_floordiv = false;
                    if (c2 == ' ' || c2 == '\t') {
                        char c3 = source.peek_char(1);
                        if ((c3 >= '0' && c3 <= '9') || c3 == '(' || c3 == '-'
                            || (c3 >= 'a' && c3 <= 'z') || (c3 >= 'A' && c3 <= 'Z') || c3 == '_')
                            is_floordiv = true;
                    } else if ((c2 >= '0' && c2 <= '9') || c2 == '(' || c2 == '-'
                               || (c2 >= 'a' && c2 <= 'z') || (c2 >= 'A' && c2 <= 'Z')
                               || c2 == '_' || c2 == '$') {
                        is_floordiv = true;
                    }
                    if (is_floordiv) {
                        token.value = "//";
                        make_token(TokenType::Div, TokenKind::Slash, TokenClass::Operator);
                    } else {
                        token.value = "//";
                        consume_comment();
                    }
                }
                break;
                case '*':
                    token.value = "/*";
                    consume_multiline_comment();
                break;
                case '=':
                    this->token.value = "/=";
                    make_token(TokenType::DivAssign,TokenKind::SlashEqual,TokenClass::Assignment);
                break;
                default:
                    source.put_char();
                    this->token.value = "/";
                    make_token(TokenType::Div,TokenKind::Slash,TokenClass::Operator);
                break;

            }
        break;
        }
        case '\\':{
            char c = source.peek_char(); /// \x0087
            if(c == 'x') {
                /// decode hex
                std::stack<char> decoded;
                char result = 0;
                do{
                    c = source.read_char();
                    if(c != 'x') break;
                    c = source.read_char();
                    if(!is_hex(c)) {
                        source.put_char();
                        c = 'x';
                        break;
                    }
                    result = hex2num(c) << 4;
                    char c1 = source.read_char();
                    if(!is_hex(c1)) {
                        source.put_char();
                        source.put_char();
                        c = 'x';
                        break;
                    }
                    result |= hex2num(c1);
                    decoded.push(result);
                }while((c = source.read_char()) == '\\');
                while(!decoded.empty()) {
                    source.put_char();
                    decoded.pop();
                }
            } else {
                if(c == '\r') {
                    source.read_char();
                    return;
                }
                if(c != '\n' && c != '\x0c') {
                    errors++;
                    Token token = {
                        {TokenType::LineContinuationError, TokenKind::Error, TokenClass::Default},
                        {"Line Continuation Error"},
                        source.location
                    };
                    logger << Log(
                        LogType::error,
                        "Line Continuation Error",
                        source.location.row,
                        source.location.column
                    );
                    tokens.push_back(token);
                    add_info_item(LexerInfoLevel::Error,token);
                    return;
                }
                if(c=='=') {
                    this->token.value = "\\=";
                    make_token(TokenType::RevDivAssign,TokenKind::AntiSlashEqual,TokenClass::Assignment);
                } else {
                    this->token.value = "\\";
                    make_token(TokenType::RevDiv,TokenKind::AntiSlash,TokenClass::Operator);
                }
            }
        }
        break;
        default: {
          if (is_ident_char(source.current_char, true)) {
            this->consume_ident();
            potential_keyword = true;
          } else if(source.current_char!=-1 && source.current_char!='\0') {
            // ── Dynamic symbolic operator scan ──────────────────────
            // Try to greedily match a registered dynamic operator symbol.
            // We peek ahead to build candidate strings and match longest-first.
            auto& dynreg = nython::DynamicLangRegistry::instance();
            if (!dynreg.operators().empty()) {
                // Find the longest registered symbol that starts here.
                // operators() is sorted longest-first.
                std::string matched_sym;
                for (auto& dop : dynreg.operators()) {
                    const std::string& sym = dop.symbol;
                    if (sym.empty()) continue;
                    if (sym[0] != source.current_char) continue;
                    // Check remaining chars via peek
                    bool ok = true;
                    for (size_t si = 1; si < sym.size(); si++) {
                        if (source.peek_char((int)si - 1) != sym[si]) { ok = false; break; }
                    }
                    if (ok) { matched_sym = sym; break; }
                }
                if (!matched_sym.empty()) {
                    // Consume the remaining chars (first already consumed by read_char)
                    for (size_t si = 1; si < matched_sym.size(); si++)
                        source.read_char();
                    this->token.value = "__dynop:" + matched_sym;
                    make_token(TokenType::Identifier, TokenKind::Identifier, TokenClass::Identifier);
                    potential_keyword = false;
                    break;
                }
            }
            this->unexpectedChar();
          }
        break;
        }
    }
    // Change the type of keyword tokens
    if (this->token.type() == TokenType::Identifier && potential_keyword) {
        bool matched_kw = false;
        for(auto kw : Keywords()) {
            if(this->token.value == kw.value) {
                this->token.ident = kw.ident;
                matched_kw = true;
                break;
            }
        }
        // Check dynamic tokens from DynamicLangRegistry
        if (!matched_kw) {
            auto& reg = nython::DynamicLangRegistry::instance();
            for (auto& dtok : reg.tokens()) {
                if (dtok.name.empty()) continue;
                bool match = false;
                if (dtok.pattern.empty()) {
                    // Exact keyword match
                    match = (this->token.value == dtok.name);
                } else {
                    // Regex match
                    try {
                        std::regex re("^(?:" + dtok.pattern + ")$");
                        match = std::regex_match(this->token.value, re);
                    } catch (...) {
                        match = (this->token.value == dtok.name);
                    }
                }
                if (match) {
                    // Tag as DynamicKeyword — use identifier type but mark value
                    // We encode the dynamic token ID in the token value prefix "__dyntok:ID:VALUE"
                    this->token.value = "__dyntok:" + std::to_string(dtok.token_id) + ":" + this->token.value;
                    // Keep as Identifier type; executor/parser will decode
                    break;
                }
            }
        }
    }
    if(source.isAtEnd() && token.type() == TokenType::Invalid) {
    	token.value = "newline";
    	make_token(TokenType::NewLine, TokenKind::NewLine, TokenClass::Delimiter);
    }
    // Ignore tokens which are not relevant for parsing
    if (this->token.type() != TokenType::Comment && this->token.type() != TokenType::Whitespace) {
         this->tokens.push_back(this->token);
    }
}

void Lexer::consume_numeric() {
    // Check the number prefix
    if (source.current_char == '0') {
        char cp = source.peek_char();
        switch(cp) {
			case 'b': case 'B':{
                source.read_char();
			    source.read_char();
                this->consume_binary();
                break;
            }
			case 'x': case 'X': {
			    source.read_char();
			    source.read_char();
                this->consume_hex();
                break;
            }
			case 'o': case 'O':{
                source.read_char();
			    source.read_char();
                this->consume_octal();
                break;
            }
			case 'j': case 'J':{
                this->consume_cplx();
                break;
            }
			case '.': case 'e': case 'E':{
                this->consume_decimal();
                break;
            }
			default: {
                this->consume_decimal();
            }
            break;
		}
    }else this->consume_decimal();
}

inline bool isExponential(char cp) {
    return cp == 'e' || cp == 'E';
}

inline bool isUnits(char first) {
    switch(first) {
		case 'T':
		case 'G':
		case 'K':
		case 'k':
		case 'M':
		case 'm':
		case 'u':
		case 'n':
		case 'p':
		case 'f':
		case 'a':
        return true;
		default:
        return false;
	}
	return false;
}

inline void units(char first,std::stringstream& decoder) {
	switch(first) {
		case 'T':
			decoder << "e+12";
		break;
		case 'G':
			decoder << "e+9";
		break;
		case 'M':
			decoder << "e+6";
		break;
		case 'K':
		case 'k':
			decoder << "e+3";
		break;
		case 'm':
			decoder << "e-3";
		break;
		case 'u':
			decoder << "e-6";
		break;
		case 'n':
			decoder << "e-9";
		break;
		case 'p':
			decoder << "e-12";
		break;
		case 'f':
			decoder << "e-15";
		break;
		case 'a':
			decoder << "e-18";
		break;
		default:
		break;
	}
}

inline bool isComplex(char cp) {
    return cp == 'j' or cp == 'J';
}

void Lexer::consume_decimal() {
    char cp;
    char numchar;
    bool point_passed  = false;
    bool complx_passed = false;
    bool units_passed  = false;
    bool expone_passed = false;
    bool digits_passed = false;
    std::stringstream decoder;
    decoder << std::dec;
    decoder << static_cast<char>(source.current_char);
    if( source.current_char == '.' ) point_passed = true;
    if( is_digit(source.current_char) ) digits_passed = true;
    while (true) {
        cp = source.read_char();
        // Skip underscores
        if (cp == '_') continue;
        // Parse float point
        if (cp == '.') {
          if (point_passed) {
            break;
          }
          if (Lexer::is_numeric(source.peek_char())) {
            point_passed = true;
            decoder << '.';
          } else {
            if( isExponential(source.peek_char()) ) {
                if(expone_passed) break;
                expone_passed = true;
            }else if( isUnits(source.peek_char()) ) {
                if(units_passed) break;
                units_passed = true;
            }else if( isComplex(source.peek_char()) ) {
                if(complx_passed) break;
                complx_passed = true;
            }else {
                break;
            }
          }
          continue;
        }
        if (isExponential(cp)) {
            numchar = static_cast<char>(cp);
            decoder << numchar;
            cp = source.read_char();
            if(expone_passed) break;
            if(!digits_passed) break;
            expone_passed = true;
            numchar = static_cast<char>(cp);
            decoder << numchar;
        }else if (isUnits(char(cp))) {
            if(units_passed) break;
            if(!digits_passed) break;
            units_passed = true;
            numchar = static_cast<char>(cp);
            units(numchar, decoder);
        }else if (isComplex(cp)) {
            if(complx_passed) break;  /// should remove
            if(!digits_passed) break;   /// should remove
            complx_passed = true;
            numchar = static_cast<char>(cp);
            decoder << numchar;
            break;
        }else if (Lexer::is_numeric(cp)) {
            if(!expone_passed)  digits_passed = true;
            if(!units_passed)   digits_passed = true;
            if(!complx_passed)  digits_passed = true;
            numchar = static_cast<char>(cp);
            decoder << numchar;
        }else break;
    }
    source.put_char();
    if (cp == '.' && !point_passed) {
        cp = source.peek_char();
        if(std::isspace(cp)) {
        	source.read_char();
        	decoder << '.';
        	point_passed = true;
        }
    }
    this->token.value = decoder.str();
    //Check if we parsed a complex
    if ( complx_passed ) {
        source.read_char();
        make_token(TokenType::Complex,TokenKind::Number,TokenClass::Literal);
    }
    // Check if we parsed a float
    else if (point_passed || units_passed || expone_passed) {
        make_token(TokenType::Float,TokenKind::Number,TokenClass::Literal);
    } else {
        make_token(TokenType::Integer,TokenKind::Number,TokenClass::Literal);
    }
}

void Lexer::consume_hex() {
    bool point_passed = false;
    this->token.value.clear();
    this->token.value.append("0x");
    // There has to be at least one hex character
    if (!Lexer::is_hex(source.current_char)) {
        this->unexpectedChar();
    }
    char cp = source.current_char;
    while (true) {
        if (Lexer::is_hex(cp)) {
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        } else if (cp == '.') {
            if (point_passed) {
                break;
            }
            point_passed = true;
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        }else {
            break;
        }
    }
    source.put_char(); // put back the non-octal character
    if(this->token.value.size() <= 2) {
		make_token(TokenType::Invalid, TokenKind::Error,TokenClass::Invalid);
		this->unexpectedChar();
	}
    if(point_passed) make_token(TokenType::Float,TokenKind::Number,TokenClass::Literal);
    else make_token(TokenType::Integer,TokenKind::Number,TokenClass::Literal);
}

void Lexer::consume_octal() {
    bool point_passed = false;
    this->token.value.clear();
    this->token.value.append("0o");
    // There has to be at least one hex character
    if (!Lexer::is_octal(source.current_char)) {
        this->unexpectedChar();
    }
    char cp = source.current_char;
    while (true) {
        if (Lexer::is_octal(cp)) {
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        }else if (cp == '.') {
            if (point_passed) {
                break;
            }
            point_passed = true;
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        } else {
            break;
        }
    }
    source.put_char(); // put back the non-octal character
    if(this->token.value.size() <= 2) {
		make_token(TokenType::Invalid, TokenKind::Error,TokenClass::Invalid);
		this->unexpectedChar();
	}
    if(point_passed) make_token(TokenType::Float,TokenKind::Number,TokenClass::Literal);
    else make_token(TokenType::Integer,TokenKind::Number,TokenClass::Literal);
}

void Lexer::consume_binary() {
    bool point_passed = false;
    this->token.value.clear();
    this->token.value.append("0b");
    // There has to be at least one hex character
    if (!Lexer::is_binary(source.current_char)) {
        this->unexpectedChar();
    }
    char cp = source.current_char;
    while (true) {
        if (Lexer::is_binary(cp)) {
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        }else if (cp == '.') {
            if (point_passed) {
                break;
            }
            point_passed = true;
            this->token.value += static_cast<char>(cp);
            cp = source.read_char();
        } else {
            break;
        }
    }
    source.put_char(); // put back non-binary char
    if(this->token.value.size() <= 2) {
		make_token(TokenType::Invalid, TokenKind::Error,TokenClass::Invalid);
		this->unexpectedChar();
	}
    if(point_passed) make_token(TokenType::Float,TokenKind::Number,TokenClass::Literal);
    else make_token(TokenType::Integer,TokenKind::Number,TokenClass::Literal);
}

void Lexer::consume_cplx() {
    char numchar = static_cast<char>(source.current_char);
    std::stringstream decoder;
    decoder << numchar;
    source.read_char();
    numchar = static_cast<char>(source.current_char);
    source.read_char();
    this->token.value = decoder.str();
    make_token(TokenType::Complex,TokenKind::Number,TokenClass::Literal);
}

void Lexer::consume_whitespace(bool should_indent) {
	char cp = source.current_char;
	int col = cp == ' '? 1: cp == '\t'? int(TabSize): 0;
	while (true) {
        cp = this->source.read_char();
        col += cp == ' '? 1: cp == '\t'? int(TabSize): 0;
        if (cp != ' ' && cp != '\t') break;
    }
    source.put_char();
    if(!should_indent) {
    	this->token.value = " ";
    	make_token(TokenType::Whitespace, TokenKind::Whitespace, TokenClass::Default);
    } else {
    	indent = col;
		indent_stack.push_back(indent);
		this->token.value = std::to_string(col);
		make_token(TokenType::Indent, TokenKind::Indent, TokenClass::Delimiter);
    }
}

bool Lexer::handle_indentation() {
    const int tab_size = int(TabSize);
    int col = 0;
    // Indentation is meaningless inside a bracketed expression. A list whose
    // header wraps —
    //     for j in ["x", "y",
    //               "z"]:
    //         var t = 1
    // — used to push an Indent for the continuation line's 10 spaces and then a
    // Dedent for the body's 4, which cancelled out, so the body never got an
    // Indent token and its first statement failed to parse. Skip the whitespace
    // and leave the indent stack untouched while any bracket is open.
    if(bracket_depth > 0) {
        char cc = -1;
        for(;;) {
            cc = source.read_char();
            if(cc != ' ' && cc != '\t') break;
        }
        source.put_char();
        return false;
    }
    char c = -1;
    for(;;) {
		c = source.read_char();
		if(c == ' '){
			++col;
		}
		else if(c == '\t'){
			col += tab_size;
		}
		else break;
	}
	source.put_char();
	if(col > indent) {
		///Adjust the current indentation level.
		indent = col;
		indent_stack.push_back(indent);
		this->token.value = std::to_string(col);
		make_token(TokenType::Indent, TokenKind::Indent, TokenClass::Delimiter);
		tokens.push_back(token);
	} else if(col < indent) {
	    /// If the indent is smaller than the last indent, then add as much dedent tokens until the indent matches one on the stack
		while (col < indent && !indent_stack.empty()) {
			this->token.value = std::to_string(indent);
			make_token(TokenType::Dedent, TokenKind::Dedent, TokenClass::Delimiter);
			tokens.push_back(token);
			indent_stack.pop_back();
            indent = indent_stack.size() ? indent_stack[indent_stack.size()-1] : 0;
		}
	}else if (!indent_stack.empty() && indent != indent_stack.back()) {
        // If the indent doesn't match the current indentation level, then report an error
        //make_token( TokenType::MixedIndentError,TokenKind::Error, TokenClass::Invalid);
        //add_info_item(LexerInfoLevel::Error,token);
        /*logger << Log(
            LogType::error,
            "MixedIndentError: The indentation does not match any outer indentation level.",
            source.location.row,
            source.location.column
        );*/
        return false;
    }
	return true;
}


void Lexer::consume_newline() {
    char cp = source.current_char;
    while ( cp == '\r' || cp == '\n'  ) cp = source.read_char();
    source.put_char();
    this->token.value = "newline";
    make_token(TokenType::NewLine, TokenKind::NewLine, TokenClass::Delimiter);
    tokens.push_back(token);
    handle_indentation();
}

void Lexer::consume_ident() {
    source.appendToFrame(source.current_char);
    while (is_ident_char(source.read_char())) {
        source.appendToFrame(source.current_char);
    }
    source.put_char();
    this->token.value = source.get_current_frame();
    make_token(TokenType::Identifier,TokenKind::Identifier,TokenClass::Identifier);
}

void Lexer::consume_regex(char first) {
    std::stringstream strbuff;
    char cur;
    bool escaped = false;
    first = source.read_char();
	do {
        cur = source.read_char();
        if(!escaped && cur==first) break;
		if(cur=='\\' && source.peek_char()==first) escaped = true;
		else escaped = false;
		if(!escaped) strbuff << char(cur);
	} while(!source.eof());
	this->token.value = strbuff.str();
	if(cur!=first) {
        errors++;
        make_token( TokenType::UnterminatedRegexError,TokenKind::Error, TokenClass::Invalid);
        add_info_item(LexerInfoLevel::Error,token);
        logger << Log(
            LogType::error,
            "Unterminated Regular Expression Error",
            source.location.row,
            source.location.column - 1
        );
	} else {
        make_token(TokenType::Regex,TokenKind::Regex,TokenClass::Literal);
	}
}

void Lexer::consume_string(char first) {
    std::stringstream strbuff;
    char cur = first;
	int quote_count     = 0;
	int end_quote_count = 0;
	while(cur == first && quote_count < 3) {
		++quote_count;
		cur = source.read_char();
	}
	source.put_char();
	if(quote_count != 2 && quote_count != 6) {
		while(end_quote_count != quote_count) {
			cur = source.read_char();
			if(cur == '\0') {
                this->token.value = source.get_current_frame();
                errors++;
				make_token( TokenType::UnterminatedStringError,TokenKind::Error, TokenClass::Invalid);
				add_info_item(LexerInfoLevel::Error,token);
				logger << Log(
                    LogType::error,
                    "Unterminated String Error",
                    source.location.row,
                    source.location.column
                );
                return;
			}
			if(cur != '\\' && cur != '\x0c' && cur != '\r') {
				// For triple-quoted strings (quote_count==3), preserve literal newlines
				if(cur == '\n') {
					if(quote_count == 3) strbuff << '\n';
					// single-quoted: newline already handled (error) above
				} else {
					if(cur!=first) strbuff << char(cur);
				}
			}
			if(cur == first) {
				++end_quote_count;
			}else{
				end_quote_count = 0;
				if(cur == '\n' || cur == '\x0c' || cur == '\r') {
					if(quote_count == 1) {
						source.put_char();
						this->token.value = source.get_current_frame();
						errors++;
						make_token( TokenType::UnterminatedStringError,TokenKind::Error, TokenClass::Invalid);
						add_info_item(LexerInfoLevel::Error,token);
						logger << Log(
                            LogType::error,
                            "Unterminated String Error",
                            source.location.row,
                            source.location.column
                        );
						return;
					}
					if(cur == '\r') continue;
				}
				if(cur == '\\') {
					char c = source.read_char();
					switch(c) {
						case '\\':
							strbuff << '\\';
						break;
						case 'a': {
                            strbuff << '\a';
                            break;
                        }
                        case 'b': {
                            strbuff << '\b';
                            break;
                        }
                        case 'n': {
                            strbuff << '\n';
                            break;
                        }
                        case 'r': {
                            strbuff << '\r';
                            break;
                        }
                        case 't': {
                            strbuff << '\t';
                            break;
                        }
                        case 'v': {
                            strbuff << '\v';
                            break;
                        }
                        case 'f': {
                            strbuff << '\f';
                            break;
                        }
                        case 'e': {
                            strbuff << char(0x1B);
                            break;
                        }
						case '"':
							strbuff << '"';
						break;
						case '\'':
							strbuff << '\'';
						break;
						case 'u': case 'U': {
                            // \uXXXX or \UXXXXXXXX unicode code point
                            int digits = (c == 'u') ? 4 : 8;
                            uint32_t codepoint = 0;
                            bool valid = true;
                            for(int _d = 0; _d < digits; _d++) {
                                char hc = source.read_char();
                                if(!is_hex(hc)) { valid = false; source.put_char(); break; }
                                codepoint = (codepoint << 4) | (uint32_t)hex2num(hc);
                            }
                            if(valid) {
                                // Encode as UTF-8
                                if(codepoint < 0x80) {
                                    strbuff << (char)codepoint;
                                } else if(codepoint < 0x800) {
                                    strbuff << (char)(0xC0|(codepoint>>6));
                                    strbuff << (char)(0x80|(codepoint&0x3F));
                                } else if(codepoint < 0x10000) {
                                    strbuff << (char)(0xE0|(codepoint>>12));
                                    strbuff << (char)(0x80|((codepoint>>6)&0x3F));
                                    strbuff << (char)(0x80|(codepoint&0x3F));
                                } else {
                                    strbuff << (char)(0xF0|(codepoint>>18));
                                    strbuff << (char)(0x80|((codepoint>>12)&0x3F));
                                    strbuff << (char)(0x80|((codepoint>>6)&0x3F));
                                    strbuff << (char)(0x80|(codepoint&0x3F));
                                }
                            } else {
                                strbuff << '\\' << c; // leave as-is on invalid escape
                            }
                            break;
                        }
						case 'x': case 'X': {
                            // \xHH hex escape (exactly 2 hex digits)
                            char h1 = source.read_char();
                            char h2 = source.read_char();
                            if(is_hex(h1) && is_hex(h2)) {
                                strbuff << (char)((hex2num(h1)<<4)|hex2num(h2));
                            } else {
                                strbuff << '\\' << c;
                                if(!is_hex(h1)) source.put_char();
                                else source.put_char();
                            }
                            break;
                        }
						case '\0': {
                            this->unexpectedChar();
                            break;
                        }
						default:
						    strbuff << char(cur);
						break;
					}
				}
			}
		}
	}
    this->token.value = strbuff.str();
    make_token(TokenType::String,TokenKind::String,TokenClass::Literal);
}

void Lexer::consume_right_shift() {
    switch(source.peek_char()) {
        case '=':
            this->token.value = ">>=";
            source.read_char();
            make_token(TokenType::ShiftAssign,TokenKind::RightShiftEqual, TokenClass::Operator);
        break;
        case '>':
            source.read_char();
            switch(source.peek_char()) {
                case '=':
                    source.read_char();
                    this->token.value = ">>>=";
                    make_token(TokenType::ShiftRightAssign,TokenKind::ShiftEqual, TokenClass::Assignment);
                break;
                default:
                    this->token.value = ">>>";
                    make_token(TokenType::Shift,TokenKind::Shift, TokenClass::Operator);
                break;
            }
        break;
        default:
            this->token.value = ">>";
            make_token(TokenType::ShiftRight,TokenKind::RightShift,TokenClass::Operator);
        break;
    }
}

void Lexer::consume_left_shift() {
    switch(source.peek_char()) {
        case '=':
            this->token.value = "<<=";
            source.read_char();
            make_token(TokenType::ShiftLeftAssign,TokenKind::LeftShiftEqual, TokenClass::Assignment);
        break;
        default:
            this->token.value = "<<";
            make_token(TokenType::ShiftLeft,TokenKind::LeftShift,TokenClass::Operator);
        break;
    }
}

void Lexer::consume_comment() {
    std::stringstream sstr;
    do{
        sstr << source.read_char();
        if(source.current_char == '\0') break;
    }while(source.current_char != '\n');
    // Put the newline back so the main loop can process it as a NewLine token
    // with correct indentation handling. Without this, the \n after a comment
    // is swallowed and the next line's indentation is lost.
    if(source.current_char == '\n') source.put_char();
    token.value.append(sstr.str());
    make_token(TokenType::Comment,TokenKind::Comment,TokenClass::Default);
}

void Lexer::consume_multiline_comment() {
    int level = 1;
    char c    = -1;
    char c0   = -1;
    bool ok   = false;
    std::stringstream sstr;
    c = source.read_char();
    sstr <<  c;
    while(!source.isAtEnd()) {
        c0 = c;
        c = source.read_char();
        sstr <<  c;
        if(c0 == '*' && c == '/') {
            level--;
            if(level == 0) {
                ok = true;
                break;
            }
        } else if(c0 == '/' && c == '*') {
            level++;
        }
    }
    if(!ok) {
        Token tk = { {TokenType::LineContinuationError,TokenKind::Error,TokenClass::Default},
            {"Invalid Multiple Line Comments"},
            source.location
        };
        logger << Log(
            LogType::error,
            "Invalid Multiple Line Comments",
            source.location.row,
            source.location.column
        );
        token.value.append(sstr.str());
        tk.value.append(token.value);
        token = tk;
        add_info_item(LexerInfoLevel::Error,token);
        errors++;
    }else {
        token.value.append(sstr.str());
        make_token(TokenType::Comment,TokenKind::Comment,TokenClass::Default);
    }
}

bool Lexer::add_indent_error(bool dedent) {
    errors++;
    Token token = {
		{dedent ? TokenType::DedentationError : TokenType::IndentationError, TokenKind::Error, TokenClass::Default},
		dedent ? "Dedentation Error" : "Indentation Error",
		source.location
	};
	tokens.push_back(token);
	add_info_item(LexerInfoLevel::Error,token);
	logger << Log(
        LogType::error,
        dedent ? "Dedentation Error" : "Indentation Error",
        source.location.row,
        source.location.column
    );
	return false;
}

void Lexer::add_info_item(LexerInfoLevel level, Token const & t) {
	Token tk     = t;
	tk._location = source.location;
	info.push_back({tk, level,{}});
}

Token Lexer::make_invalid(char const * begin, char const * end, TokenType id, TokenKind kind, TokenClass cls) {
	return{ {id, kind, cls}, std::string(begin, end), source.location};
}

void Lexer::statistics() {
    printf("Lexer Statistics:\n");
	fmt::print("{}", logger);
	printf("\n%d lexing errors\n", errors);
	printf("%d lexing warnings\n", warnings);
}

}




bool nython::lexer::Lexer::hasErrors() {
    return errors > 0;
}


#pragma GCC diagnostic pop
