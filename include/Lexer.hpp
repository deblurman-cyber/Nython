#ifndef __LEXER__HPP
#define __LEXER__HPP

#include <algorithm>
#include "ILexer.hpp"
#include "Regex.hpp"
#include "Logger.hpp"
#include "SourceCode.hpp"


using nython::kernel::Log;
using nython::kernel::Logger;
using nython::kernel::LogType;
using nython::reader::SourceCode;


namespace nython::lexer {

struct Lexer;

enum class LexerInfoLevel {
    Information,
    Warning,
    Error
};

struct LexerInfo {
    Token info;
    LexerInfoLevel level;
    std::string    value;
};

inline std::ostream& operator<<(std::ostream& os,LexerInfoLevel level);

using token_list = std::vector<Token>;
using lexer_ptr  = std::shared_ptr<Lexer>;

struct Lexer extends ILexer{

    SourceCode& source;
    Token token;
    char first_indet_char         = 0;
    int level_                    = 0;
    int tab                       = TabSize;/// default tabulation.
    int errors                    = 0;/// number of errors
    int warnings                  = 0;/// number of errors
    int indent                    = 0;///  current indent level is the number of spaces in the last indent.
    /// Open ( [ { count. Indentation is meaningless inside a bracketed
    /// expression, so continuation lines must not push or pop the indent
    /// stack; see handle_indentation().
    int bracket_depth             = 0;
    int current                   = 0;///  index of the current token inside the list of tokens.
    std::vector<int> indent_stack{};/// indentation stack.
    std::vector<Token> tokens{};/// list of tokens
    std::vector<LexerInfo> info{};/// the list of errors if any
    // eventually insert a Logger object here
    Logger logger;

public:

    Lexer(SourceCode& source);
    virtual ~Lexer();

    bool empty();
    int  tabSize();
    void tabSize(int tab);
    bool hasErrors();
    void statistics();
    void reset();
    void dump();
    Token next();
    Token prev();
    Token curr();
    Token peek(int i);
    std::vector<Token> tokenize();
    std::string code();
    std::string fileName();
    std::string toString();

    inline bool atEnd() { return current == int(tokens.size()-1); }

    inline Logger& getLogger()  { return logger; }

    void reset_token();
    void read_token();

    static bool is_ident_start(char cp);
    static bool is_ident_part(char cp);
    static bool is_alpha(char cp);
    static bool is_alpha_lowercase(char cp);
    static bool is_alpha_uppercase(char cp);
    static bool is_numeric(char cp);
    static bool is_hex(char cp);
    static bool is_octal(char cp);
    static bool is_binary(char cp);

    void consume_operator_or_assignment(TokenType type);
    void consume_left_shift();
    void consume_right_shift();
    void consume_whitespace(bool should_indent);
    void consume_newline();
    void consume_numeric();
    void consume_decimal();
    void consume_hex();
    void consume_octal();
    void consume_binary();
    void consume_cplx();
    void consume_regex(char first);
    void consume_string(char first);
    void consume_comment();
    void consume_multiline_comment();
    void consume_ident();
    void unexpectedChar();

    Token& make_token(TokenIdent ident);
    Token& make_token(TokenType id, TokenKind kind, TokenClass cls);

    bool isKeyWord(const std::string word);/// true if word is a key word.
    bool isOperator(const std::string word);/// true if word is an operator.
    bool isSeparator(const std::string word);/// true if word is a separator.
    bool isIdentifier(const std::string word);/// true if word is an identifier.

private:

    bool handle_indentation();

    Token make_invalid(char const * begin,char const * end,TokenType id = TokenType::Invalid,TokenKind kind = TokenKind::Error,TokenClass cls = TokenClass::Default);

    bool add_indent_error(bool dedent = false);
    void add_info_item(LexerInfoLevel level, Token const & t);

    inline void add_information(Token const & t) {
        add_info_item(LexerInfoLevel::Information, t);
    }

    inline void add_warning(Token const & t) {
        add_info_item(LexerInfoLevel::Warning, t);
    }

    inline void add_error(Token const & t) {
        add_info_item(LexerInfoLevel::Error, t);
    }

};

}


#endif // __LEXER__HPP

