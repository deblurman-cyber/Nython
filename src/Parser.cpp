#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#include "Parser.hpp"
#include "SourceCode.hpp"
#include "Except.hpp"
#include "Script.hpp"
#include "ASTNodes.hpp"
#include "DynamicLang.hpp"

using nython::node::Script;
using namespace nython::node;

namespace nython::parser {

std::vector<std::string> operators = {
    ">>>=",">>>","===","!==","**=","&&=","||=","^^=","<<=",">>=","**","++","--","&&","||","^^",
    "<<",">>",">=","<=","==","!=","+=","-=","*=","/=","\\=","%=","~=","&=","|=","^=",">","<","&",
    "|","^","~","%","+","-","*","/","\\","!","=",
    "and","or","xor","not","sizeof","typeof","not in","in","is","is not","print"
};

std::vector<std::string> binaries = {
    ">>>","===","!==","**","&&","||","^^",
    "<<",">>",">=","<=","==","!=",">","<","&",
    "|","^","~","%","+","-","*","/","\\",
    "and","or","xor","not","not in","in","is","is not"
};

Parser::Parser(Reporter* reporter, Runnable* runner_arg, Lexer* lexer): IParser(reporter), runner{runner_arg}, scanner{lexer}, param_defaults_{} {}

node_ptr Parser::parse() {
    try { return script(); }
    catch (SyntaxError& ex) { throw ex; }
}

std::string Parser::dottedName(){
    // Accept identifier or string literal for import paths
    if (have(TokenType::String)) {
        return prev().value;
    }
    mustBe(TokenType::Identifier);
    std::string name = prev().value;
    while(have(TokenType::Dot)){ mustBe(TokenType::Identifier); name += "."+prev().value; }
    return name;
}

std::string Parser::identifier(){
    // Allow keywords to be used as identifiers (function/variable names)
    if(see(TokenType::Identifier)) {
        next();
        return prev().value;
    }
    // Accept common keywords as identifiers when used as names
    TokenType t = token().type();
    if(t == TokenType::Repeat || t == TokenType::Execute || t == TokenType::Delete
       || t == TokenType::Default || t == TokenType::Final || t == TokenType::Loop
       || t == TokenType::Block || t == TokenType::Use || t == TokenType::Global
       || t == TokenType::Static || t == TokenType::Public || t == TokenType::Private
       || t == TokenType::Protected || t == TokenType::Abstract || t == TokenType::Super
       || t == TokenType::Import || t == TokenType::From || t == TokenType::As
       || t == TokenType::Is || t == TokenType::In || t == TokenType::Print
       || t == TokenType::Typeof || t == TokenType::Sizeof || t == TokenType::Yield
       || t == TokenType::Raise || t == TokenType::Pass || t == TokenType::Assert
       || t == TokenType::With || t == TokenType::Ref || t == TokenType::Let
       || t == TokenType::Var || t == TokenType::Const
       // Async keywords double as ordinary names: lib/thread.ny declares
       // `def await(self)`, which the VM's import path rejected with
       // "Expected Identifier, but found Await".
       || t == TokenType::Await || t == TokenType::Async
       || t == TokenType::EndBlock || t == TokenType::Fn
       || t == TokenType::Function || t == TokenType::New
       || t == TokenType::Try || t == TokenType::Except
       || t == TokenType::Finally || t == TokenType::Break || t == TokenType::Continue
       || t == TokenType::Return || t == TokenType::If || t == TokenType::Else
       || t == TokenType::For || t == TokenType::While || t == TokenType::Do
       || t == TokenType::Switch || t == TokenType::Case || t == TokenType::Def
       || t == TokenType::Class || t == TokenType::Interface
       || t == TokenType::Enum || t == TokenType::Not || t == TokenType::And
       || t == TokenType::Or || t == TokenType::Xor || t == TokenType::True
       || t == TokenType::False || t == TokenType::None || t == TokenType::Lambda
       || t == TokenType::Then || t == TokenType::Extends || t == TokenType::Inherits
       || t == TokenType::Implements || t == TokenType::NameSpace
       || t == TokenType::Package || t == TokenType::Interface) {
        std::string name = token().value;
        next();
        return name;
    }
    mustBe(TokenType::Identifier);
    return prev().value;
}

bool Parser::isFlowStatement(){
    return see(TokenType::Break)||see(TokenType::Continue)||see(TokenType::Return)||see(TokenType::Yield)||see(TokenType::Raise);
}

bool Parser::isYield(){ return see(TokenType::Yield); }

bool Parser::isCompoundStatement(){
    return see(TokenType::Colon)||see(TokenType::Block)||see(TokenType::If)||see(TokenType::While)
        ||see(TokenType::For)||see(TokenType::Try)||see(TokenType::With)||see(TokenType::Def)
        ||see(TokenType::Function)||see(TokenType::Fn)||see(TokenType::Fun)||see(TokenType::Var)||see(TokenType::Let)||see(TokenType::Const)||see(TokenType::Ref)
        ||see(TokenType::Class)||see(TokenType::Unless)||see(TokenType::Interface)||see(TokenType::Typeof)||see(TokenType::Sizeof)||see(TokenType::Global)||see(TokenType::Loop)||see(TokenType::Block)||see(TokenType::Repeat)
        ||see(TokenType::Enum)||see(TokenType::Switch)||see(TokenType::NameSpace)||see(TokenType::Repeat);
}

bool Parser::isImportStatement(){ return see(TokenType::From)||see(TokenType::Import); }

bool Parser::isAugAssign(){
    return see(TokenType::AddAssign)||see(TokenType::SubAssign)||see(TokenType::MulAssign)
        ||see(TokenType::DivAssign)||see(TokenType::AndAssign)||see(TokenType::OrAssign)
        ||see(TokenType::XorAssign)||see(TokenType::BinAndAssign)||see(TokenType::BinOrAssign)
        ||see(TokenType::BinXorAssign)||see(TokenType::ModAssign)||see(TokenType::RevDivAssign)
        ||see(TokenType::ExpAssign)||see(TokenType::ShiftLeftAssign)||see(TokenType::ShiftRightAssign)
        ||see(TokenType::ShiftAssign);
}

bool Parser::isOperator(){
    return contains(value(),operators);
}

bool Parser::isClosing(){
    return see(TokenType::ParenClose)||see(TokenType::BraceClose)||see(TokenType::BracketClose);
}

bool Parser::isOperatorCall(){
    return contains(value(),operators) && peek().type()==TokenType::ParenOpen;
}

bool Parser::isComparison(){
    return see(TokenType::GreatEqual)||see(TokenType::LessEqual)||see(TokenType::Less)
        ||see(TokenType::Great)||see(TokenType::Equal)||see(TokenType::NotEqual)||see(TokenType::Equals)
        ||see(TokenType::In)||see(TokenType::Is)||(see(TokenType::Not)&&peek().type()==TokenType::In)
        ||(see(TokenType::Is)&&peek().type()==TokenType::Not)
        ||see(TokenType::DeepEqual)||see(TokenType::NotDeepEqual)||see(TokenType::DeepEqual)
        ||see(TokenType::Instanceof)||see(TokenType::Parentof)||see(TokenType::Subclassof);
}

bool Parser::isTrailer(){
    return see(TokenType::ParenOpen)||see(TokenType::BracketOpen)||see(TokenType::Dot);
}

bool Parser::isModifier(){
    return see(TokenType::Public)||see(TokenType::Protected)||see(TokenType::Private)||see(TokenType::Static)||see(TokenType::Abstract);
}

bool Parser::isKeyWord(){
    return (!see(TokenType::Self)&&!see(TokenType::This)&&!see(TokenType::Super)&&peek().type()!=TokenType::Dot)
        && token().clazz()==TokenClass::Keyword;
}

// ═══════════════════════════════════════════════════════════════════════════
// SCRIPT & STATEMENT ENTRY
// ═══════════════════════════════════════════════════════════════════════════

node_ptr Parser::script(){
    Token tok = this->token();
    if(have(TokenType::Package)){
        tok.value = dottedName();
        have(TokenType::SemiColon);
    } else {
        tok.value = "nython";
    }
    node_ptr node = node_ptr(new Script(tok));
    while(!see(TokenType::End)){
        if(have(TokenType::NewLine));
        else if(have(TokenType::SemiColon));
        else node->add(stmt());
    }
    mustBe(TokenType::End);
    return node;
}

node_ptr Parser::stmt(){
    while(have(TokenType::NewLine)||have(TokenType::SemiColon)) {}
    if(see(TokenType::End)) return nullptr;
    return statement();
}

node_ptr Parser::statement(){
    // ── Dynamic keyword dispatch ───────────────────────────────────
    // If the current token is a dynamic keyword (__dyntok:ID:name),
    // look up its registered rules and route accordingly.
    if (see(TokenType::Identifier) && nython::is_dyntok_value(token().value)) {
        Token dyn_tok = token();
        std::string dyn_name = nython::decode_dyntok_name(dyn_tok.value);
        auto& reg = nython::DynamicLangRegistry::instance();

        // PREFIX_OP rule: dynamic keyword used as prefix operator
        // (handled in expression(), not here — fall through to expression())

        // MACRO rule: collect tokens to EOL, build MacroCallNode
        const nython::DynamicRule* macro_rule = reg.macro_rule_for(dyn_name);
        if (macro_rule) {
            next(); // consume the macro keyword token
            // Collect all tokens until NewLine, Colon (body start), or End
            std::vector<std::string> args;
            while (!see(TokenType::NewLine) && !see(TokenType::End) &&
                   !see(TokenType::Colon) && !see(TokenType::SemiColon)) {
                args.push_back(token().value);
                next();
            }
            return make_node<MacroCallNode>(dyn_tok, dyn_name, args);
        }

        // INFIX_OP rule: dynamic keyword used as infix — handled in expression()
        // If it's just a defined token with no special rule, fall through to
        // expression parsing (it will be treated as an identifier).
    }

    // Variable declarations
    if(see(TokenType::Var)) return varDecl(false, false);
    if(see(TokenType::Let)) return varDecl(false, true);
    if(see(TokenType::Const)) return varDecl(true, false);
    if(see(TokenType::Ref)) return varDecl(false, false);

    // Control flow
    if(see(TokenType::Unless)) {
        Token tok = token();
        next(); // consume unless
        bool has_paren = have(TokenType::ParenOpen);
        node_ptr cond = expression();
        if(has_paren) mustBe(TokenType::ParenClose);
        have(TokenType::Colon); have(TokenType::Then);
        node_ptr body = blockOrStmt();
        // unless cond: body → if not cond: body
        // Create a NOT unary around the condition
        Token not_tok = tok;
        not_tok.value = "not";
        auto negated = make_node<UnaryNode>(not_tok, cond);
        return make_node<IfNode>(tok, negated, body);
    }
    if(see(TokenType::If)) return ifStmt();
    if(see(TokenType::While)) {
        auto wnode = whileStmt();
        // Check for else clause after while (Python while/else)
        while(have(TokenType::NewLine)) {}
        if(see(TokenType::Else)) {
            next(); // consume else
            have(TokenType::Colon);
            auto else_body = blockOrStmt();
            if(wnode->type() == NodeType::WHILE)
                static_cast<WhileNode*>(wnode.get())->else_branch = else_body;
        }
        return wnode;
    }
    if(see(TokenType::For)) {
        auto fnode = forStmt();
        // Check for else clause after for (Python for/else)
        while(have(TokenType::NewLine)) {}
        if(see(TokenType::Else)) {
            next(); // consume else
            have(TokenType::Colon);
            if (fnode->type() == NodeType::FOR)
                static_cast<ForNode*>(fnode.get())->else_branch = blockOrStmt();
        }
        return fnode;
    }
    if(see(TokenType::Repeat)) return repeatStmt();

    // Definitions
    // Decorator: @name before def/class
    if(have(TokenType::At)) {
        Token dec_tok = token();
        // Allow keywords as decorator names (e.g. @repeat)
        std::string decorator_name;
        if(see(TokenType::Identifier)) {
            decorator_name = identifier();
        } else {
            decorator_name = token().value;
            next();
        }
        // Optional (args) after decorator: @decorator(arg1, arg2)
        std::vector<node_ptr> dec_args;
        bool has_dec_args = false;
        if(have(TokenType::ParenOpen)) {
            has_dec_args = true;
            dec_args = argList();
            mustBe(TokenType::ParenClose);
        }
        have(TokenType::NewLine);
        // Parse the decorated function or class
        node_ptr target = statement();
        std::string target_name;
        if(target->type() == NodeType::FUNCTION)
            target_name = static_cast<FunctionNode*>(target.get())->name;
        else if(target->type() == NodeType::CLASS)
            target_name = static_cast<ClassNode*>(target.get())->name;
        else if(target->type() == NodeType::BLOCK) {
            // Stacked decorators: inner @dec already returned a block.
            // The assigned name is the last assignment's LHS in the block.
            auto* blk = static_cast<BlockNode*>(target.get());
            const auto& stmts = blk->statements();
            for (auto it = stmts.rbegin(); it != stmts.rend(); ++it) {
                if ((*it)->type() == NodeType::ASSIGNMENT) {
                    auto* asgn = static_cast<AssignmentNode*>(it->get());
                    if (asgn->target && asgn->target->type() == NodeType::VARIABLE) {
                        target_name = asgn->target->value();
                        break;
                    }
                }
            }
        }
        if(!target_name.empty()) {
            auto block = make_node<BlockNode>(dec_tok);
            block->add(target);
            Token call_tok = dec_tok; call_tok.value = decorator_name;
            auto dec_var = make_node<VariableNode>(call_tok);
            Token tgt_tok = dec_tok; tgt_tok.value = target_name;
            node_ptr final_call;
            if(has_dec_args) {
                // @decorator(args) -> target = decorator(args)(target)
                // Step 1: call decorator(args)
                auto factory_call = make_node<CallNode>(call_tok, dec_var);
                for(auto& a : dec_args) factory_call->add(a);
                // Step 2: call result(target)
                final_call = make_node<CallNode>(call_tok, factory_call);
                final_call->add(make_node<VariableNode>(tgt_tok));
            } else {
                // @decorator -> target = decorator(target)
                final_call = make_node<CallNode>(call_tok, dec_var);
                final_call->add(make_node<VariableNode>(tgt_tok));
            }
            auto assign_target = make_node<VariableNode>(tgt_tok);
            block->add(make_node<AssignmentNode>(dec_tok, assign_target, final_call));
            return block;
        }
        return target;
    }
    if(see(TokenType::Async)) { next(); } // consume async modifier, parse as normal function
    if(see(TokenType::Def)||see(TokenType::Function)||see(TokenType::Fn)||see(TokenType::Fun)) {
        // If the keyword is followed by = [ ( . += -= etc., treat it as an identifier/assignment
        // rather than a function declaration (e.g. `fn = x[0:5]` where fn is a variable name)
        TokenType next_type = peek().type();
        bool used_as_var = (next_type == TokenType::Assign
            || next_type == TokenType::AddAssign || next_type == TokenType::SubAssign
            || next_type == TokenType::MulAssign  || next_type == TokenType::DivAssign
            || next_type == TokenType::ModAssign  || next_type == TokenType::BracketOpen
            || next_type == TokenType::Dot        || next_type == TokenType::NewLine
            || next_type == TokenType::SemiColon  || next_type == TokenType::Comma
            || next_type == TokenType::End        || next_type == TokenType::Dedent
            // fn(args) where 'fn/function/fun' is a variable name being called:
            // If the keyword is immediately followed by '(' and no identifier precedes it,
            // it must be a call expression, not a function declaration (which requires a name).
            || next_type == TokenType::ParenOpen);
        if (!used_as_var) return functionDecl();
        // Fall through to expression statement (identifier + assignment)
    }
    if(see(TokenType::Class)) return classDecl();
    if(see(TokenType::Interface)) return interfaceDecl();
    if(see(TokenType::Typeof)||see(TokenType::Sizeof)) {
        Token tok = token();
        std::string fn_name = tok.value == "typeof" ? "type" : "len";
        next(); // consume keyword
        mustBe(TokenType::ParenOpen);
        auto arg = expression();
        mustBe(TokenType::ParenClose);
        Token call_tok = tok; call_tok.value = fn_name;
        auto fn_var = make_node<VariableNode>(call_tok);
        auto call = make_node<CallNode>(call_tok, fn_var);
        call->add(arg);
        have(TokenType::SemiColon); have(TokenType::NewLine);
        return call;
    }
    if(see(TokenType::Abstract)) { next(); return classDecl(); } // abstract class
    if(see(TokenType::Loop)) return loopStmt();
    if(see(TokenType::Block)) return blockStmt();
    if(see(TokenType::Repeat)) return repeatStmt();
    if(see(TokenType::Enum)) return enumDecl();
    if(see(TokenType::NameSpace)) return namespaceDecl();

    // Flow statements
    if(see(TokenType::Global)) {
        next(); // consume 'global'
        // global x, y, z - just consume identifiers
        identifier();
        while(have(TokenType::Comma)) identifier();
        have(TokenType::SemiColon); have(TokenType::NewLine);
        return make_node<BlockNode>(token()); // no-op
    }
    if(see(TokenType::Return)) return returnStmt();
    if(see(TokenType::Break)) return breakStmt();
    if(see(TokenType::Continue)) return continueStmt();
    if(see(TokenType::Pass)) return passStmt();
    if(see(TokenType::Yield)) return yieldStmt();

    // Exception handling
    if(see(TokenType::Try)) {
        auto tnode = tryStmt();
        auto tn = std::static_pointer_cast<TryNode>(tnode);
        // Check for else clause
        while(have(TokenType::NewLine)) {}
        if(see(TokenType::Else)) {
            next();
            have(TokenType::Colon);
            tn->else_clause = blockOrStmt();
        }
        // Check for finally clause
        while(have(TokenType::NewLine)) {}
        if(see(TokenType::Finally)) {
            next();
            have(TokenType::Colon);
            tn->finally_clause = blockOrStmt();
        }
        return tnode;
    }
    if(see(TokenType::Raise)) return raiseStmt();
    if(see(TokenType::Assert)) return assertStmt();

    // Misc
    if(see(TokenType::Print)) return printStmt();
    if(see(TokenType::Import)||see(TokenType::From)) return importStmt();
    if(see(TokenType::Delete)) return deleteStmt();
    if(see(TokenType::With)) return withStmt();
    if(see(TokenType::Switch)) return switchStmt();

    // Lua-style  do ... end  as a standalone statement
    // (blockOrStmt handles do-blocks as sub-blocks of while/for; this handles top-level)
    if(see(TokenType::Do) && peek().type() != TokenType::BraceOpen) {
        Token tok = token();
        next(); // consume 'do'
        // Python-style do: body \n while cond
        bool colon_style = have(TokenType::Colon);
        have(TokenType::NewLine);
        auto blk = make_node<BlockNode>(tok);
        if(have(TokenType::Indent)) {
            while(!see(TokenType::EndBlock)&&!see(TokenType::Dedent)&&!see(TokenType::End)&&!see(TokenType::While)){
                blk->add(stmt());
                while(have(TokenType::NewLine)||have(TokenType::SemiColon)) {}
            }
            have(TokenType::Dedent);
        } else {
            while(!see(TokenType::EndBlock)&&!see(TokenType::End)&&!see(TokenType::While)) {
                blk->add(stmt());
                while(have(TokenType::NewLine)||have(TokenType::SemiColon)) {}
            }
        }
        // Python-style: do: body while cond  →  desugar to while(true) { body; if(!cond) break; }
        if(colon_style && see(TokenType::While)) {
            next(); // consume 'while'
            bool hp = have(TokenType::ParenOpen);
            node_ptr cond = expression();
            if(hp) mustBe(TokenType::ParenClose);
            have(TokenType::SemiColon); have(TokenType::NewLine);
            Token not_tok = tok; not_tok.value = "not";
            auto neg_cond = make_node<UnaryNode>(not_tok, cond);
            auto brk = make_node<BreakNode>(tok);
            auto guard = make_node<IfNode>(tok, neg_cond, brk);
            blk->add(guard);
            auto true_cond = make_node<BoolNode>(tok, true);
            return make_node<WhileNode>(tok, true_cond, blk);
        }
        have(TokenType::EndBlock); // consume 'end' (Lua-style)
        have(TokenType::NewLine);
        return blk;
    }
    // C-style do { } while(cond) — distinct from Lua "do ... end"
    // Detect: do {  (brace immediately after do = C-style)
    if(see(TokenType::Do) && peek().type() == TokenType::BraceOpen) {        Token tok = token();
        next(); // consume 'do'
        node_ptr body = block(); // parses the { ... } block
        // Consume optional newlines between } and while
        while(have(TokenType::NewLine)) {}
        if(see(TokenType::While)) {
            next(); // consume 'while'
            bool hp = have(TokenType::ParenOpen);
            node_ptr cond = expression();
            if(hp) mustBe(TokenType::ParenClose);
            have(TokenType::SemiColon); have(TokenType::NewLine);
            // Desugar:  do { body } while(cond)
            //        →  while(true) { body; if(!cond) break; }
            auto blk = make_node<BlockNode>(tok);
            blk->add(body);
            Token not_tok = tok; not_tok.value = "not";
            auto neg_cond = make_node<UnaryNode>(not_tok, cond);
            auto brk = make_node<BreakNode>(tok);
            auto guard = make_node<IfNode>(tok, neg_cond, brk);
            blk->add(guard);
            auto true_cond = make_node<BoolNode>(tok, true);
            return make_node<WhileNode>(tok, true_cond, blk);
        }
        // No while → just a bare brace block after 'do' (unusual, but valid)
        return body;
    }

    // Block
    if(see(TokenType::BraceOpen)) return block();

    // Multi-target assignment: a, b = expr, expr (only at statement level)
    // Use peek() lookahead to detect pattern: ident , ident [, ident]* =
    if(see(TokenType::Identifier)) {
        bool is_multi_assign = false;
        int look = 1;
        // Check pattern: ident (, ident)+ =
        while(peek(look).ident.id() == TokenType::Comma && 
              peek(look+1).ident.id() == TokenType::Identifier) {
            look += 2;
        }
        if(look > 1 && peek(look).ident.id() == TokenType::Assign) {
            is_multi_assign = true;
        }
        if(is_multi_assign) {
            // Parse targets
            std::vector<node_ptr> targets;
            targets.push_back(make_node<VariableNode>(token()));
            next();
            while(have(TokenType::Comma)) {
                targets.push_back(make_node<VariableNode>(token()));
                next();
            }
            Token op = token();
            mustBe(TokenType::Assign);
            // Parse RHS values
            std::vector<node_ptr> vals;
            vals.push_back(ternary());
            while(have(TokenType::Comma)) vals.push_back(ternary());
            // Generate swap-safe assignments via temps
            auto block = make_node<BlockNode>(op);
            if (vals.size() == 1 && targets.size() > 1) {
                // Single RHS value with multiple targets -> list unpacking
                // Evaluate the single value, then subscript it for each target
                std::string tmp = "__unpack_src__";
                block->add(make_node<VarDeclNode>(op, tmp, vals[0], false, false));
                for(size_t i = 0; i < targets.size(); i++) {
                    Token tmp_tok = op; tmp_tok.value = tmp;
                    auto tmp_var = make_node<VariableNode>(tmp_tok);
                    Token idx_tok = op; idx_tok.value = std::to_string(i);
                    auto idx_node = make_node<IntegerNode>(idx_tok);
                    auto subscript = make_node<SubscriptNode>(op, tmp_var, idx_node);
                    block->add(make_node<AssignmentNode>(op, targets[i], subscript));
                }
            } else {
                for(size_t i = 0; i < vals.size(); i++) {
                    std::string tmp = "__swap_tmp_" + std::to_string(i) + "__";
                    block->add(make_node<VarDeclNode>(op, tmp, vals[i], false, false));
                }
                for(size_t i = 0; i < targets.size() && i < vals.size(); i++) {
                    std::string tmp = "__swap_tmp_" + std::to_string(i) + "__";
                    Token tmp_tok = op; tmp_tok.value = tmp;
                    auto tmp_var = make_node<VariableNode>(tmp_tok);
                    block->add(make_node<AssignmentNode>(op, targets[i], tmp_var));
                }
            }
            return block;
        }
    }
    // Expression statement (assignment, call, etc.)
    return expressionStmt();
}

// ═══════════════════════════════════════════════════════════════════════════
// EXPRESSION PARSING (precedence climbing)
// ═══════════════════════════════════════════════════════════════════════════

node_ptr Parser::expressionStmt(){
    node_ptr expr = expression();
    consumed_semi_ = have(TokenType::SemiColon);
    if(!consumed_semi_) have(TokenType::NewLine);
    return expr;
}

node_ptr Parser::expression(){
    return assignment();
}

node_ptr Parser::assignment(){
    node_ptr left = ternary();
    if(have(TokenType::Assign)){
        Token op = prev();
        node_ptr right = assignment(); // right-associative
        return make_node<AssignmentNode>(op, left, right);
    }
    if(isAugAssign()){
        Token op = token();
        next();
        node_ptr right = assignment();
        return make_node<AugAssignNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::ternary(){
    // yield as expression: allows "var x = yield val" and "x = yield val"
    if(see(TokenType::Yield)) {
        Token tok = token(); next(); // consume 'yield'
        if(have(TokenType::From)){
            node_ptr src = expression();
            return make_node<YieldFromNode>(tok, src);
        }
        node_ptr yexpr = nullptr;
        if(!see(TokenType::NewLine) && !see(TokenType::SemiColon) && !see(TokenType::End)
           && !see(TokenType::ParenClose) && !see(TokenType::BracketClose))
            yexpr = expression();
        return make_node<YieldNode>(tok, yexpr);
    }
    node_ptr expr = rangeExpr();
    // C-style ternary: cond ? then : else
    if(have(TokenType::QuestionMark)){
        Token tok = prev();
        node_ptr then_expr = expression();
        mustBe(TokenType::Colon);
        node_ptr else_expr = expression();
        auto node = make_node<IfNode>(tok, expr, then_expr);
        std::static_pointer_cast<IfNode>(node)->else_branch = else_expr;
        return node;
    }
    // Python-style ternary: value if cond else other
    if(have(TokenType::If)){
        Token tok = prev();
        node_ptr condition = logicalOr();
        mustBe(TokenType::Else);
        node_ptr else_expr = expression();
        auto node = make_node<IfNode>(tok, condition, expr);
        std::static_pointer_cast<IfNode>(node)->else_branch = else_expr;
        return node;
    }
    return expr;
}

// Range / interval:  a..b   (inclusive of a, exclusive of b)
//                    a...b  (inclusive of both ends)
//                    a..b..step
//
// The lexer has always emitted Interval and Ellipsis tokens and RangeNode /
// evalRange have always existed; nothing ever connected them, so `for i in 1..3`
// was a syntax error even though every piece needed to run it was present.
// Sits directly above logicalOr so `1..n` binds tighter than `and`/`or` but
// looser than arithmetic, making `1..n+1` mean `1..(n+1)`.
node_ptr Parser::rangeExpr(){
    node_ptr lo = logicalOr();
    if(see(TokenType::Interval) || see(TokenType::Ellipsis)){
        bool inclusive = see(TokenType::Ellipsis);
        Token tok = token();
        next();
        node_ptr hi = logicalOr();
        node_ptr step = nullptr;
        // a..b..step
        if(see(TokenType::Interval)){
            next();
            step = logicalOr();
        }
        if(inclusive){
            // `a...b` includes b. Represent it as a half-open range ending at
            // b+1 so one evaluator serves both forms.
            Token one = tok;
            one.value = "1";
            one.type(TokenType::Integer);
            Token plus = tok;
            plus.value = "+";
            plus.type(TokenType::Add);
            hi = make_node<BinaryNode>(plus, hi, make_node<IntegerNode>(one));
        }
        return make_node<RangeNode>(tok, lo, hi, step);
    }
    return lo;
}

node_ptr Parser::logicalOr(){
    node_ptr left = logicalAnd();
    while(have(TokenType::Or)||have(TokenType::Xor)){
        Token op = prev();
        if (op.value == "xor" || op.value == "^^") op.value = "xor";
        else op.value = "or";
        node_ptr right = logicalAnd();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::logicalAnd(){
    node_ptr left = bitwiseOr();
    while(have(TokenType::And)){
        Token op = prev(); op.value = "and";
        node_ptr right = bitwiseOr();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::bitwiseOr(){
    node_ptr left = bitwiseXor();
    while(have(TokenType::BinOr)){
        Token op = prev(); node_ptr right = bitwiseXor();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::bitwiseXor(){
    node_ptr left = bitwiseAnd();
    while(have(TokenType::BinXor)){
        Token op = prev(); node_ptr right = bitwiseAnd();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::bitwiseAnd(){
    node_ptr left = equality();
    while(have(TokenType::BinAnd)){
        Token op = prev(); node_ptr right = equality();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::equality(){
    node_ptr left = comparison();
    while(true){
        Token op = token();
        if(have(TokenType::Equal))          { op.value = "=="; left = make_node<BinaryNode>(op, left, comparison()); }
        else if(have(TokenType::NotEqual))  { op.value = "!="; left = make_node<BinaryNode>(op, left, comparison()); }
        else if(have(TokenType::DeepEqual)) { op.value = "==="; left = make_node<BinaryNode>(op, left, comparison()); }
        else if(have(TokenType::NotDeepEqual)){op.value = "!=="; left = make_node<BinaryNode>(op, left, comparison()); }
        else if(have(TokenType::Equals))     { op.value = "==="; left = make_node<BinaryNode>(op, left, comparison()); }
        else break;
    }
    return left;
}

node_ptr Parser::comparison(){
    node_ptr left = shift();
    while(true){
        Token op = token();
        bool is_cmp = false;
        std::string cmp_op;
        if(see(TokenType::Less)) { is_cmp = true; cmp_op = "<"; }
        else if(see(TokenType::Great)) { is_cmp = true; cmp_op = ">"; }
        else if(see(TokenType::LessEqual)) { is_cmp = true; cmp_op = "<="; }
        else if(see(TokenType::GreatEqual)) { is_cmp = true; cmp_op = ">="; }
        
        if(is_cmp) {
            next(); // consume the operator
            op.value = cmp_op;
            node_ptr right = shift();
            // Check for chained comparison
            if(left->type() == NodeType::BINARY) {
                auto* left_bin = static_cast<BinaryNode*>(left.get());
                std::string lop = left_bin->op;
                // Direct comparison on left: a < b → chain as (a < b) AND (b op c)
                if(lop == "<" || lop == ">" || lop == "<=" || lop == ">=" || lop == "==" || lop == "!=") {
                    Token and_tok = op; and_tok.value = "and";
                    auto right_cmp = make_node<BinaryNode>(op, left_bin->right, right);
                    left = make_node<BinaryNode>(and_tok, left, right_cmp);
                    continue;
                }
                // AND chain on left (from previous chaining): dig out rightmost comparison
                if(lop == "and") {
                    // The right side of the AND should be a comparison
                    if(left_bin->right->type() == NodeType::BINARY) {
                        auto* rbin = static_cast<BinaryNode*>(left_bin->right.get());
                        std::string rop = rbin->op;
                        if(rop == "<" || rop == ">" || rop == "<=" || rop == ">=" || rop == "==" || rop == "!=") {
                            Token and_tok = op; and_tok.value = "and";
                            auto new_cmp = make_node<BinaryNode>(op, rbin->right, right);
                            left = make_node<BinaryNode>(and_tok, left, new_cmp);
                            continue;
                        }
                    }
                }
            }
            left = make_node<BinaryNode>(op, left, right);
        }
        else if(have(TokenType::In))      { op.value = "in"; left = make_node<BinaryNode>(op, left, shift()); }
        else if(see(TokenType::Not) && peek().type()==TokenType::In) { next(); next(); op.value = "not in"; left = make_node<BinaryNode>(op, left, shift()); }
        else if(have(TokenType::Is))      { if(have(TokenType::Not)) op.value = "is not"; else op.value = "is"; left = make_node<BinaryNode>(op, left, shift()); }
        else if(have(TokenType::Instanceof)){op.value = "instanceof"; left = make_node<BinaryNode>(op, left, shift()); }
        else break;
    }
    return left;
}

node_ptr Parser::shift(){
    node_ptr left = addition();
    while(have(TokenType::ShiftLeft)||have(TokenType::ShiftRight)){
        Token op = prev(); node_ptr right = addition();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::addition(){
    node_ptr left = multiplication();
    while(have(TokenType::Add)||have(TokenType::Sub)){
        Token op = prev(); node_ptr right = multiplication();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::multiplication(){
    node_ptr left = power();
    while(have(TokenType::Mul)||have(TokenType::Div)||have(TokenType::Mod)||have(TokenType::RevDiv)){
        Token op = prev(); node_ptr right = power();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::power(){
    node_ptr left = unary();
    if(have(TokenType::Exp)){
        Token op = prev(); op.value = "**"; node_ptr right = power();
        left = make_node<BinaryNode>(op, left, right);
    }
    return left;
}

node_ptr Parser::unary(){
    if(have(TokenType::Add)||have(TokenType::Sub)||have(TokenType::Not)||have(TokenType::Complement)
      ||have(TokenType::DoubleAdd)||have(TokenType::DoubleSub)){
        Token op = prev();
        node_ptr operand = unary();
        return make_node<UnaryNode>(op, operand);
    }
    return postfix();
}

node_ptr Parser::postfix(){
    node_ptr expr = primary();
    // Indents consumed to join a continued method chain. The lexer pairs each
    // Indent with a Dedent; since this indent never opened a block, the matching
    // Dedent would otherwise be left for the statement parser, which rejects it.
    int joined_indents = 0;
    while(true){
        // A method chain may continue on the following line:
        //     [1,2,3]
        //         .filter(...)
        // The lexer emits NewLine and Indent between ']' and '.', which ended
        // the statement. Skip them only when a '.' genuinely follows, so
        // ordinary statement boundaries are unaffected.
        {
            int look = 0;
            while(peek(look).type() == TokenType::NewLine
               || peek(look).type() == TokenType::Indent
               || peek(look).type() == TokenType::Dedent) look++;
            if(look > 0 && peek(look).type() == TokenType::Dot){
                for(int k=0;k<look;k++){
                    if(token().type() == TokenType::Indent) joined_indents++;
                    next();
                }
            }
        }
        if(have(TokenType::ParenOpen)){
            // Function call
            Token tok = prev();
            auto call = make_node<CallNode>(tok, expr);
            auto parse_call_arg = [&]() -> node_ptr {
                if(have(TokenType::Mul)){
                    Token star = prev();
                    node_ptr operand = expression();
                    return make_node<UnaryNode>(star, operand);
                }
                if(have(TokenType::Exp)){
                    Token dstar = prev();
                    node_ptr operand = expression();
                    return make_node<UnaryNode>(dstar, operand);
                }
                // Keyword argument: name=value (must look ahead before expression() consumes it as assignment)
                if(see(TokenType::Identifier) && peek(1).type() == TokenType::Assign
                   && peek(2).type() != TokenType::Assign) { // distinguish name=val from name==val
                    Token kw_tok = token();
                    std::string kw_name = kw_tok.value;
                    next(); // consume name
                    next(); // consume =
                    node_ptr kw_val = expression();
                    return make_node<KeywordArgNode>(kw_tok, kw_name, kw_val);
                }
                node_ptr first_expr = expression();
                // Generator expression: expr for var in iter [if cond]
                if(have(TokenType::For)){
                    Token comp_tok = prev();
                    comp_tok.value = identifier(); // var name
                    mustBe(TokenType::In);
                    node_ptr iterable = logicalOr();
                    node_ptr filter_expr = nullptr;
                    if(have(TokenType::If)) filter_expr = expression();
                    auto comp = make_node<ComplexNode>(comp_tok);
                    auto cp = std::static_pointer_cast<ComplexNode>(comp);
                    cp->items.push_back(first_expr);
                    cp->items.push_back(iterable);
                    cp->items.push_back(filter_expr);
                    return comp;
                }
                return first_expr;
            };
            if(!see(TokenType::ParenClose)){
                call->add(parse_call_arg());
                while(have(TokenType::Comma) && !see(TokenType::ParenClose)){
                    call->add(parse_call_arg());
                }
            }
            mustBe(TokenType::ParenClose);
            expr = call;
        } else if(have(TokenType::BracketOpen)){
            // Subscript or slice
            Token tok = prev();
            auto make_int = [&](int v) -> node_ptr {
                Token zt = tok; zt.value = std::to_string(v);
                return make_node<IntegerNode>(zt);
            };
            auto make_none_node = [&]() -> node_ptr {
                Token nt = tok; nt.value = "none";
                return make_node<NoneNode>(nt);
            };
            // Check for [:...] (empty start)
            if(see(TokenType::Colon)) {
                next(); // consume first :
                node_ptr start_expr = make_int(0);
                node_ptr end_expr = nullptr;
                node_ptr step_expr = nullptr;
                if(see(TokenType::Colon)) {
                    // [::step]
                    next(); // consume second :
                    if(!see(TokenType::BracketClose))
                        step_expr = expression();
                } else if(!see(TokenType::BracketClose)) {
                    end_expr = expression();
                    if(have(TokenType::Colon)) {
                        // [:end:step]
                        if(!see(TokenType::BracketClose))
                            step_expr = expression();
                    }
                }
                mustBe(TokenType::BracketClose);
                std::vector<node_ptr> slice_args;
                slice_args.push_back(start_expr);
                if(end_expr) slice_args.push_back(end_expr);
                else if(step_expr) slice_args.push_back(make_none_node());
                if(step_expr) slice_args.push_back(step_expr);
                auto attr = make_node<AttributeNode>(tok, expr, "slice");
                auto call = make_node<CallNode>(tok, attr);
                for(auto& sa : slice_args) call->add(sa);
                expr = call;
            } else {
                node_ptr index = expression();
                if(have(TokenType::Colon)) {
                    // [start:end] or [start:end:step] or [start:]
                    node_ptr end_expr = nullptr;
                    node_ptr step_expr = nullptr;
                    if(!see(TokenType::BracketClose) && !see(TokenType::Colon))
                        end_expr = expression();
                    if(have(TokenType::Colon)) {
                        if(!see(TokenType::BracketClose))
                            step_expr = expression();
                    }
                    mustBe(TokenType::BracketClose);
                    std::vector<node_ptr> slice_args;
                    slice_args.push_back(index);
                    if(end_expr) slice_args.push_back(end_expr);
                    else if(step_expr) slice_args.push_back(make_none_node());
                    if(step_expr) slice_args.push_back(step_expr);
                    auto attr = make_node<AttributeNode>(tok, expr, "slice");
                    auto call = make_node<CallNode>(tok, attr);
                    for(auto& sa : slice_args) call->add(sa);
                    expr = call;
                } else {
                    mustBe(TokenType::BracketClose);
                    expr = make_node<SubscriptNode>(tok, expr, index);
                }
            }
        } else if(have(TokenType::Dot)){
            // Attribute access.
            //
            // An OPERATOR is a legal member name here: `1.+(2, 3)` calls the
            // `+` member of 1, which is how an object language with operators as
            // methods should read. Previously identifier() demanded a Name
            // token, so `1.+(2,3)` failed with "Expected Identifier, but found
            // Add" — the operator method could be defined but never called by
            // name.
            Token tok = token();
            std::string attr;
            if(token().clazz() == TokenClass::Operator
               && !see(TokenType::Dot) && !see(TokenType::ParenOpen)){
                attr = token().value;
                next();
            } else {
                attr = identifier();
            }
            expr = make_node<AttributeNode>(tok, expr, attr);
        } else if(have(TokenType::DoubleAdd)){
            Token tok = prev();
            tok.value = "++";
            expr = make_node<UnaryNode>(tok, expr);
        } else if(have(TokenType::DoubleSub)){
            Token tok = prev();
            tok.value = "--";
            expr = make_node<UnaryNode>(tok, expr);
        } else if(see(TokenType::RightArrow)){
            // Arrow function:  x => body  OR  (params) => body  OR  () => body
            // RightArrow is produced by both  ->  and  =>
            Token arrow_tok = token();
            next(); // consume =>  or  ->
            node_ptr body = expression();
            auto lam = make_node<LambdaNode>(arrow_tok, body);
            // Extract parameters from the left-hand side
            if(expr->type() == NodeType::TUPLE) {
                // (a, b, c) => body  — each element is a param
                auto* tup = static_cast<TupleNode*>(expr.get());
                for(auto& el : tup->elements) lam->add(el);
            } else if(expr->type() == NodeType::VARIABLE) {
                // x => body  — single identifier param
                lam->add(expr);
            }
            // (anything else: zero-param arrow)
            return lam;
        } else if(see(TokenType::Identifier)) {
            // ── Dynamic infix operators ────────────────────────────
            // Check for dynamic keyword used as INFIX_OP, or __dynop: symbol
            auto& dynreg2 = nython::DynamicLangRegistry::instance();
            std::string tok_val = token().value;
            std::string infix_name;
            bool is_dyn_infix = false;
            if (nython::is_dyntok_value(tok_val)) {
                std::string dname = nython::decode_dyntok_name(tok_val);
                if (dynreg2.infix_rule_for(dname)) {
                    infix_name = dname;
                    is_dyn_infix = true;
                }
            } else if (nython::is_dynop_value(tok_val)) {
                std::string dsym = nython::decode_dynop_sym(tok_val);
                auto* dop = dynreg2.find_operator(dsym);
                if (dop && dop->arity == nython::DynamicOperator::Arity::INFIX) {
                    infix_name = dsym;
                    is_dyn_infix = true;
                }
            }
            if (is_dyn_infix) {
                Token op_tok = token();
                next(); // consume the operator token
                node_ptr rhs = unary(); // parse RHS at unary precedence
                expr = make_node<DynBinopNode>(op_tok, infix_name, expr, rhs);
            } else {
                break;
            }
        } else break;
    }
    // Consume the Dedent(s) the lexer paired with the Indent(s) skipped above.
    // Those indents never opened a block, so nothing else will claim them and
    // the statement parser would reject the stray Dedent.
    while(joined_indents > 0){
        if(see(TokenType::Dedent)){ next(); joined_indents--; continue; }
        // The statement's terminating NewLine can sit in front of the Dedent.
        // Consuming it here is safe: statement parsers treat it as optional.
        if(see(TokenType::NewLine) && peek(1).type() == TokenType::Dedent){ next(); continue; }
        break;
    }
    return expr;
}

node_ptr Parser::primary(){
    // await expr — treat as pass-through (no real async runtime needed for basic use)
    if(see(TokenType::Await)) { next(); return unary(); }
    // Handle typeof/sizeof as identifiers that resolve to builtins
    if(see(TokenType::Typeof)||see(TokenType::Sizeof)) {
        Token tok = token();
        tok.value = (tok.value == "typeof") ? "type" : "len";
        next();
        return make_node<VariableNode>(tok);
    }
    return atom();
}

node_ptr Parser::atom(){
    Token tok = token();

    // Literals
    if(have(TokenType::Integer)) return make_node<IntegerNode>(prev());
    if(have(TokenType::Float)||have(TokenType::Float)) return make_node<FloatNode>(prev());
    if(have(TokenType::String)||have(TokenType::String)||have(TokenType::String)
      ||have(TokenType::String)||have(TokenType::String)) {
        Token str_tok = prev();
        // Backtick template literal:  `hello ${name}`  →  treat like f-string with ${} → {}
        // Check if string contains ${...} markers (set by lexer converting ${ → \x02 or left raw)
        // We detect raw ${  in the stored string value and process as interpolation
        std::string& sv = str_tok.value;
        bool has_interp = sv.find("${") != std::string::npos;
        if(has_interp) {
            // Convert ${expr} → same pipeline as f-string {expr}
            // Replace ${ with { for re-use of f-string parser below
            std::string converted;
            for(size_t ti = 0; ti < sv.size(); ti++) {
                if(sv[ti] == '$' && ti+1 < sv.size() && sv[ti+1] == '{') {
                    converted += '{'; ti++; // skip '$', next char is '{'
                } else converted += sv[ti];
            }
            str_tok.value = converted;
            sv = str_tok.value;
            // Fall through to f-string parsing below
            goto parse_fstring;
        }
        return make_node<StringNode>(str_tok);
        parse_fstring: {
            // Reuse f-string interpolation logic
            std::string raw = str_tok.value;
            std::vector<node_ptr> parts;
            std::string current;
            size_t fi = 0;
            while (fi < raw.size()) {
                if (raw[fi] == '{' && fi+1 < raw.size() && raw[fi+1] != '{') {
                    if(!current.empty()) {
                        Token ltok = str_tok; ltok.value = current;
                        parts.push_back(make_node<StringNode>(ltok)); current.clear();
                    }
                    fi++;
                    std::string expr_str; int depth=1;
                    while(fi < raw.size() && depth>0) {
                        if(raw[fi]=='{') depth++;
                        else if(raw[fi]=='}') { depth--; if(depth==0) break; }
                        expr_str += raw[fi]; fi++;
                    }
                    if(fi < raw.size()) fi++;
                    if(!expr_str.empty()) {
                        node_ptr expr_node;
                        try {
                            reader::SourceCode sub_src(expr_str);
                            nython::exception::Reporter sub_reporter(sub_src);
                            auto sub_lex = std::make_shared<Lexer>(sub_src);
                            sub_lex->tokenize();
                            Parser sub_parser(&sub_reporter, runner, sub_lex.get());
                            expr_node = sub_parser.expression();
                        } catch(...) {
                            Token vtok = str_tok; vtok.value = expr_str;
                            expr_node = make_node<VariableNode>(vtok);
                        }
                        Token sfn = str_tok; sfn.value = "str";
                        auto str_fn = make_node<VariableNode>(sfn);
                        auto call = make_node<CallNode>(str_tok, str_fn);
                        call->add(expr_node);
                        parts.push_back(call);
                    }
                } else if(raw[fi]=='{' && fi+1<raw.size() && raw[fi+1]=='{') {
                    current += '{'; fi += 2;
                } else if(raw[fi]=='}' && fi+1<raw.size() && raw[fi+1]=='}') {
                    current += '}'; fi += 2;
                } else { current += raw[fi]; fi++; }
            }
            if(!current.empty()) {
                Token ltok = str_tok; ltok.value = current;
                parts.push_back(make_node<StringNode>(ltok));
            }
            if(parts.empty()) { Token etok = str_tok; etok.value=""; return make_node<StringNode>(etok); }
            node_ptr result = parts[0];
            for(size_t pi=1; pi<parts.size(); pi++) {
                Token op_tok = str_tok; op_tok.value="+";
                result = make_node<BinaryNode>(op_tok, result, parts[pi]);
            }
            return result;
        }
    }
    if(have(TokenType::Complex)) return make_node<ComplexNode>(prev());
    if(have(TokenType::True)) return make_node<BoolNode>(prev(), true);
    if(have(TokenType::False)) return make_node<BoolNode>(prev(), false);
    if(have(TokenType::None)||have(TokenType::None)||have(TokenType::None)) return make_node<NoneNode>(prev());
    if(have(TokenType::Undefined)) return make_node<UndefinedNode>(prev());
    if(have(TokenType::Ellipsis)) {
        // `...` → a special "ellipsis" singleton value; represent as a string "..."
        Token et = prev(); et.value = "...";
        return make_node<StringNode>(et);
    }

    // Self/Super
    if(have(TokenType::Self)||have(TokenType::This)) return make_node<SelfNode>(prev());
    if(have(TokenType::Super)) return make_node<SuperNode>(prev());

    // Identifier (includes f-string detection)
    if(have(TokenType::Identifier)) {
        Token id_tok = prev();
        // F-string: f"hello {expr}"
        if (id_tok.value == "f" && (see(TokenType::String) || token().kind() == TokenKind::String)) {
            Token str_tok = token();
            next(); // consume the string
            std::string raw = str_tok.value;
            // Parse f-string: split on { and } to extract expressions
            std::vector<node_ptr> parts;
            std::string current;
            size_t fi = 0;
            while (fi < raw.size()) {
                if (raw[fi] == '{' && fi + 1 < raw.size() && raw[fi+1] != '{') {
                    if (!current.empty()) {
                        Token ltok = str_tok; ltok.value = current;
                        parts.push_back(make_node<StringNode>(ltok));
                        current.clear();
                    }
                    fi++;
                    std::string expr_str;
                    int depth = 1;
                    while (fi < raw.size() && depth > 0) {
                        if (raw[fi] == '{') depth++;
                        else if (raw[fi] == '}') { depth--; if (depth == 0) break; }
                        expr_str += raw[fi];
                        fi++;
                    }
                    if (fi < raw.size()) fi++;
                    if (!expr_str.empty()) {
                        // Sub-parse the expression string
                        node_ptr expr_node;
                        try {
                            reader::SourceCode sub_src(expr_str);
                            nython::exception::Reporter sub_reporter(sub_src);
                            auto sub_lex = std::make_shared<Lexer>(sub_src);
                            sub_lex->tokenize(); // must populate token stream
                            Parser sub_parser(&sub_reporter, runner, sub_lex.get());
                            expr_node = sub_parser.expression();
                        } catch(nython::exception::SyntaxError& e) {
                            // SyntaxError in sub-parser — print for debug then fallback
                            Token vtok = str_tok; vtok.value = expr_str;
                            expr_node = make_node<VariableNode>(vtok);
                        } catch(...) {
                            Token vtok = str_tok; vtok.value = expr_str;
                            expr_node = make_node<VariableNode>(vtok);
                        }
                        // Wrap in str() call
                        Token sfn = str_tok; sfn.value = "str";
                        auto str_fn = make_node<VariableNode>(sfn);
                        auto call = make_node<CallNode>(str_tok, str_fn);
                        call->add(expr_node);
                        parts.push_back(call);
                    }
                } else if (raw[fi] == '{' && fi + 1 < raw.size() && raw[fi+1] == '{') {
                    current += '{'; fi += 2;
                } else if (raw[fi] == '}' && fi + 1 < raw.size() && raw[fi+1] == '}') {
                    current += '}'; fi += 2;
                } else {
                    current += raw[fi]; fi++;
                }
            }
            if (!current.empty()) {
                Token ltok = str_tok; ltok.value = current;
                parts.push_back(make_node<StringNode>(ltok));
            }
            if (parts.empty()) {
                Token etok = str_tok; etok.value = "";
                return make_node<StringNode>(etok);
            }
            node_ptr result = parts[0];
            for (size_t pi = 1; pi < parts.size(); pi++) {
                Token op_tok = str_tok; op_tok.value = "+";
                result = make_node<BinaryNode>(op_tok, result, parts[pi]);
            }
            return result;
        }
        return make_node<VariableNode>(id_tok);
    }

    // Lambda: lambda params: body  OR  fn(params) => body
    if(see(TokenType::Lambda)) return lambdaExpr();

    // Parenthesized expression or tuple
    if(have(TokenType::ParenOpen)){
        if(have(TokenType::ParenClose)) return make_node<TupleNode>(tok); // empty tuple
        // Walrus operator: (var name = expr)
        if(see(TokenType::Var) && peek(1).type()==TokenType::Identifier && peek(2).type()==TokenType::Assign) {
            next(); // consume 'var'
            std::string wname = identifier();
            mustBe(TokenType::Assign);
            node_ptr init = expression();
            mustBe(TokenType::ParenClose);
            return make_node<WalrusNode>(tok, wname, init);
        }
        node_ptr expr = expression();
        // Standalone generator expression: (expr for var in iter [if cond])
        if(have(TokenType::For)){
            std::string var_name = identifier();
            mustBe(TokenType::In);
            node_ptr iterable = logicalOr();
            node_ptr filter_expr = nullptr;
            if(have(TokenType::If)) filter_expr = expression();
            mustBe(TokenType::ParenClose);
            auto comp = make_node<ComplexNode>(tok);
            auto cp = std::static_pointer_cast<ComplexNode>(comp);
            cp->items.push_back(expr);
            cp->items.push_back(iterable);
            cp->items.push_back(filter_expr);
            cp->_token.value = var_name;
            return comp;
        }
        if(have(TokenType::Comma)){
            // Tuple
            auto tuple = make_node<TupleNode>(tok);
            tuple->add(expr);
            if(!see(TokenType::ParenClose)){
                tuple->add(expression());
                while(have(TokenType::Comma)&&!see(TokenType::ParenClose)) tuple->add(expression());
            }
            mustBe(TokenType::ParenClose);
            return tuple;
        }
        mustBe(TokenType::ParenClose);
        return expr;
    }

    // List literal [a, b, c]
    if(see(TokenType::BracketOpen)) return listLiteral();

    // Map literal {k: v, ...}
    if(see(TokenType::BraceOpen)) return mapLiteral();

    // Keywords used as identifiers (variable references)
    // In Nython, everything is an object - any identifier-like token can name a variable
    {
        TokenType t = tok.type();
        if(t == TokenType::EndBlock || t == TokenType::Fn
           || t == TokenType::Function || t == TokenType::New
           || t == TokenType::Try || t == TokenType::Except
           || t == TokenType::Finally || t == TokenType::Break || t == TokenType::Continue
           || t == TokenType::Return || t == TokenType::If || t == TokenType::Else
           || t == TokenType::For || t == TokenType::While || t == TokenType::Do
           || t == TokenType::Switch || t == TokenType::Case || t == TokenType::Def
           || t == TokenType::Class || t == TokenType::Enum
           || t == TokenType::Not || t == TokenType::And
           || t == TokenType::Or || t == TokenType::Xor
           || t == TokenType::Lambda || t == TokenType::Then
           || t == TokenType::Extends || t == TokenType::Inherits
           || t == TokenType::Implements || t == TokenType::NameSpace
           || t == TokenType::Package || t == TokenType::Interface
           || t == TokenType::Repeat || t == TokenType::Execute || t == TokenType::Delete
           || t == TokenType::Default || t == TokenType::Final || t == TokenType::Loop
           || t == TokenType::Block || t == TokenType::Use || t == TokenType::Global
           || t == TokenType::Static || t == TokenType::Public || t == TokenType::Private
           || t == TokenType::Protected || t == TokenType::Abstract || t == TokenType::Super
           || t == TokenType::Import || t == TokenType::From || t == TokenType::As
           || t == TokenType::Is || t == TokenType::In || t == TokenType::Print
           || t == TokenType::Typeof || t == TokenType::Sizeof || t == TokenType::Yield
           || t == TokenType::Raise || t == TokenType::Pass || t == TokenType::Assert
           || t == TokenType::With || t == TokenType::Ref || t == TokenType::Let
           || t == TokenType::Var || t == TokenType::Const) {
            next();
            Token id_tok = prev();
            return make_node<VariableNode>(id_tok);
        }
    }

    // If we got here, unexpected token — error
    throw SyntaxError(tok.location(), "Unexpected token: " + tok.value);
    return nullptr;
}

// ═══════════════════════════════════════════════════════════════════════════
// STATEMENT IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════

node_ptr Parser::varDecl(bool is_const, bool is_let){
    Token tok = token();
    next(); // consume var/let/const
    
    // Handle nested tuple unpacking: var (a, b), c = ...
    if (see(TokenType::ParenOpen)) {
        // Parse `(name1, name2, ...), more_names = rhs`
        std::vector<std::string> names;
        std::vector<int> nested_starts;  // groups: index -> count of sub-names
        // Parse first group
        next(); // consume (
        nested_starts.push_back((int)names.size());
        int group_start = (int)names.size();
        while (!see(TokenType::ParenClose) && !see(TokenType::End)) {
            if (see(TokenType::Mul)) { next(); names.push_back("*" + identifier()); }
            else names.push_back(identifier());
            have(TokenType::Comma);
        }
        int group_size = (int)names.size() - group_start;
        mustBe(TokenType::ParenClose);
        std::string group_tmp = "__ng" + std::to_string(group_start) + "__";
        // After ), check for more names
        while (have(TokenType::Comma)) {
            names.push_back(identifier());
        }
        // Now parse = rhs
        auto block = make_node<BlockNode>(tok);
        if (have(TokenType::Assign)) {
            std::vector<node_ptr> vals;
            vals.push_back(expression());
            while (have(TokenType::Comma)) vals.push_back(expression());
            // Build outer unpack: n_outer = group_tmp (placeholder) + rest
            // The group_tmp covers a sub-tuple at position 0
            // Outer names: group_tmp, names[group_size], names[group_size+1], ...
            std::vector<std::string> outer_names;
            outer_names.push_back(group_tmp);
            for (int i = group_size; i < (int)names.size(); i++)
                outer_names.push_back(names[i]);
            // Perform outer unpack from vals
            if (vals.size() == 1) {
                std::string outer_src = "__outer_src__";
                block->add(make_node<VarDeclNode>(tok, outer_src, vals[0], false, false));
                for (int i = 0; i < (int)outer_names.size(); i++) {
                    Token tmp_tok = tok; tmp_tok.value = outer_src;
                    auto tmp_var = make_node<VariableNode>(tmp_tok);
                    Token idx_tok = tok; idx_tok.value = std::to_string(i);
                    auto idx_node = make_node<IntegerNode>(idx_tok);
                    auto subscript = make_node<SubscriptNode>(tok, tmp_var, idx_node);
                    block->add(make_node<VarDeclNode>(tok, outer_names[i], subscript, is_const, is_let));
                }
            } else {
                // Multiple RHS values
                for (int i = 0; i < (int)outer_names.size() && i < (int)vals.size(); i++)
                    block->add(make_node<VarDeclNode>(tok, outer_names[i], vals[i], is_const, is_let));
            }
            // Now unpack group_tmp into names[0..group_size-1]
            for (int i = 0; i < group_size; i++) {
                Token tmp_tok = tok; tmp_tok.value = group_tmp;
                auto tmp_var = make_node<VariableNode>(tmp_tok);
                Token idx_tok = tok; idx_tok.value = std::to_string(i);
                auto idx_node = make_node<IntegerNode>(idx_tok);
                auto subscript = make_node<SubscriptNode>(tok, tmp_var, idx_node);
                block->add(make_node<VarDeclNode>(tok, names[i], subscript, is_const, is_let));
            }
        }
        have(TokenType::SemiColon);
        return block;
    }

    // Handle starred first variable: var *head, last = ...
    bool first_is_star = false;
    if (see(TokenType::Mul)) {
        next(); // consume *
        first_is_star = true;
    }
    std::string name = (first_is_star ? "*" : "") + identifier();
    
    // Check for multi-assignment: var a, b = 1, 2  OR var first, *rest = list
    if(see(TokenType::Comma)) {
        std::vector<std::string> names;
        names.push_back(name);
        int star_idx = first_is_star ? 0 : -1;  // index of *rest variable, -1 if none
        while(have(TokenType::Comma)) {
            if(see(TokenType::Mul)) {
                next(); // consume *
                star_idx = (int)names.size();
                names.push_back("*" + identifier());
            } else {
                names.push_back(identifier());
            }
        }
        // Parse = and comma-separated values
        auto block = make_node<BlockNode>(tok);
        if(have(TokenType::Assign)) {
            std::vector<node_ptr> vals;
            vals.push_back(expression());
            while(have(TokenType::Comma)) vals.push_back(expression());
            if (vals.size() == 1 && names.size() > 1) {
                // Single RHS -> list unpacking: var a, b = func()
                std::string tmp = "__unpack_src__";
                block->add(make_node<VarDeclNode>(tok, tmp, vals[0], false, false));
                // Find star index
                int si = -1;
                for(size_t k=0;k<names.size();k++) if(!names[k].empty()&&names[k][0]=='*') { si=(int)k; break; }
                if(si < 0) {
                    // No star: straight index assignment
                    for(size_t i = 0; i < names.size(); i++) {
                        Token tmp_tok = tok; tmp_tok.value = tmp;
                        auto tmp_var = make_node<VariableNode>(tmp_tok);
                        Token idx_tok = tok; idx_tok.value = std::to_string(i);
                        auto idx_node = make_node<IntegerNode>(idx_tok);
                        auto subscript = make_node<SubscriptNode>(tok, tmp_var, idx_node);
                        block->add(make_node<VarDeclNode>(tok, names[i], subscript, is_const, is_let));
                    }
                } else {
                    // Star unpack: first si vars get indices 0..si-1
                    // *star gets slice si..-(names.size()-si-1)
                    // trailing vars get indices from the end
                    int n_after = (int)names.size() - si - 1;
                    for(int i = 0; i < si; i++) {
                        Token tmp_tok = tok; tmp_tok.value = tmp;
                        auto tmp_var = make_node<VariableNode>(tmp_tok);
                        Token idx_tok = tok; idx_tok.value = std::to_string(i);
                        auto idx_node = make_node<IntegerNode>(idx_tok);
                        auto subscript = make_node<SubscriptNode>(tok, tmp_var, idx_node);
                        block->add(make_node<VarDeclNode>(tok, names[i], subscript, is_const, is_let));
                    }
                    // Star variable gets slice(si, -n_after or end)
                    {
                        Token tmp_tok = tok; tmp_tok.value = tmp;
                        auto tmp_var = make_node<VariableNode>(tmp_tok);
                        // Use slice node: tmp[si:-n_after] or tmp[si:]
                        auto start_n = make_node<IntegerNode>(tok); start_n->token().value = std::to_string(si);
                        // Emit a call to slice method: tmp.slice(si, len-n_after)
                        // Generate: var star_name = __unpack_src__.slice(si) or .slice(si, -n_after)
                        std::string star_name = names[si].substr(1); // strip *
                        auto tmp_var2 = make_node<VariableNode>(tmp_tok);
                        auto slice_attr = make_node<AttributeNode>(tok, tmp_var2, "slice");
                        auto slice_call = make_node<CallNode>(tok, slice_attr);
                        Token si_tok=tok; si_tok.value=std::to_string(si); si_tok.type(TokenType::Integer);
                        slice_call->add(make_node<IntegerNode>(si_tok));
                        if(n_after > 0) {
                            Token ne_tok = tok; ne_tok.value = std::to_string(-n_after); ne_tok.type(TokenType::Integer);
                            slice_call->add(make_node<IntegerNode>(ne_tok));
                        }
                        block->add(make_node<VarDeclNode>(tok, star_name, slice_call, is_const, is_let));
                    }
                    // Trailing variables get indices from the end
                    for(int i = 0; i < n_after; i++) {
                        Token tmp_tok = tok; tmp_tok.value = tmp;
                        auto tmp_var = make_node<VariableNode>(tmp_tok);
                        // Index = -(n_after - i)
                        Token idx_tok = tok; idx_tok.value = std::to_string(-(n_after - i)); idx_tok.type(TokenType::Integer);
                        auto idx_node = make_node<IntegerNode>(idx_tok);
                        auto subscript = make_node<SubscriptNode>(tok, tmp_var, idx_node);
                        block->add(make_node<VarDeclNode>(tok, names[si+1+i], subscript, is_const, is_let));
                    }
                }
            } else {
                for(size_t i = 0; i < names.size(); i++) {
                    node_ptr init = (i < vals.size()) ? vals[i] : nullptr;
                    block->add(make_node<VarDeclNode>(tok, names[i], init, is_const, is_let));
                }
            }
        } else {
            for(auto& n : names)
                block->add(make_node<VarDeclNode>(tok, n, nullptr, is_const, is_let));
        }
        have(TokenType::SemiColon); have(TokenType::NewLine);
        return block;
    }
    
    node_ptr init = nullptr;
    if(have(TokenType::Assign)) init = expression();
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<VarDeclNode>(tok, name, init, is_const, is_let);
}

node_ptr Parser::ifStmt(){
    Token tok = token();
    mustBe(TokenType::If);
    // Python style: if cond:  OR  C style: if(cond){  OR walrus: if(var n = expr):
    //
    // The opening paren is only consumed for the walrus form. It used to be
    // consumed unconditionally, after which expression() stopped at the closing
    // paren and mustBe(ParenClose) ran, so anything following the group was a
    // syntax error:
    //     if (a > 0) or (b < 5):   ->  Unexpected token: :
    // Leaving the paren for expression() lets it parse the whole condition,
    // parenthesised sub-groups and all.
    bool walrus_form = see(TokenType::ParenOpen)
                    && peek(1).type()==TokenType::Var
                    && peek(2).type()==TokenType::Identifier
                    && peek(3).type()==TokenType::Assign;
    bool has_paren = false;
    if(walrus_form) has_paren = have(TokenType::ParenOpen);
    node_ptr cond;
    // Walrus operator inside if: if (var name = expr): OR if (var n = expr) > val:
    if(has_paren && see(TokenType::Var) && peek(1).type()==TokenType::Identifier && peek(2).type()==TokenType::Assign) {
        next(); // consume 'var'
        std::string wname = identifier();
        mustBe(TokenType::Assign);
        node_ptr init = expression();
        mustBe(TokenType::ParenClose);
        node_ptr walrus = make_node<WalrusNode>(tok, wname, init);
        has_paren = false; // paren already consumed
        // Check for trailing comparison: (var n = expr) > val, >= val, == val, etc.
        auto tt = token().type();
        if (tt == TokenType::Great     || tt == TokenType::GreatEqual  ||
            tt == TokenType::Less      || tt == TokenType::LessEqual   ||
            tt == TokenType::Equal     || tt == TokenType::NotEqual    ||
            tt == TokenType::And       || tt == TokenType::Or) {
            Token op_tok = token(); next();
            node_ptr rhs = expression();
            cond = make_node<BinaryNode>(op_tok, walrus, rhs);
        } else {
            cond = walrus;
        }
    } else {
        cond = expression();
        if(has_paren) mustBe(TokenType::ParenClose);
    }
    have(TokenType::Colon); have(TokenType::Then);
    node_ptr then_b = blockOrStmt();
    auto node = make_node<IfNode>(tok, cond, then_b);
    auto if_node = std::static_pointer_cast<IfNode>(node);

    // Else-if chains
    while(have(TokenType::NewLine)) {}
    while(have(TokenType::ElseIf)||have(TokenType::ElseIf)||(see(TokenType::Else)&&peek().type()==TokenType::If)){
        if(prev().type()==TokenType::Else) next(); // consume 'if'
        // Same rule as the if-condition above: let expression() own the parens.
        node_ptr eicond = expression();
        have(TokenType::Colon);
        node_ptr eibody = blockOrStmt();
        if_node->elseif_branches.push_back(make_node<IfNode>(tok, eicond, eibody));
        while(have(TokenType::NewLine)) {}
    }

    // Else
    if(have(TokenType::Else)){
        have(TokenType::Colon);
        if_node->else_branch = blockOrStmt();
    }
    return node;
}

node_ptr Parser::whileStmt(){
    Token tok = token();
    mustBe(TokenType::While);
    bool hp = have(TokenType::ParenOpen);
    node_ptr cond;
    // Walrus operator inside while: while (var name = expr) != 0:
    if(hp && see(TokenType::Var) && peek(1).type()==TokenType::Identifier && peek(2).type()==TokenType::Assign) {
        next(); // consume 'var'
        std::string wname = identifier();
        mustBe(TokenType::Assign);
        node_ptr init = expression();
        mustBe(TokenType::ParenClose);
        node_ptr walrus = make_node<WalrusNode>(tok, wname, init);
        hp = false; // paren already consumed
        // Check for trailing comparison: (var n = expr) != 0, > val, etc.
        auto tt = token().type();
        if (tt == TokenType::Great     || tt == TokenType::GreatEqual  ||
            tt == TokenType::Less      || tt == TokenType::LessEqual   ||
            tt == TokenType::Equal     || tt == TokenType::NotEqual    ||
            tt == TokenType::And       || tt == TokenType::Or) {
            Token op_tok = token(); next();
            node_ptr rhs = expression();
            cond = make_node<BinaryNode>(op_tok, walrus, rhs);
        } else {
            cond = walrus;
        }
    } else {
        cond = expression();
        if(hp) mustBe(TokenType::ParenClose);
    }
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    return make_node<WhileNode>(tok, cond, body);
}

node_ptr Parser::forStmt(){
    Token tok = token();
    mustBe(TokenType::For);
    bool hp = have(TokenType::ParenOpen);
    // Check for C-style: for (init; cond; step) body
    // Detect by looking ahead: if next is 'var' or identifier followed by '='
    if(hp && (see(TokenType::Var) || (see(TokenType::Identifier) && peek().type()==TokenType::Assign))) {
        // C-style for loop
        node_ptr init_stmt = statement(); // var i = 0 or i = 0
        have(TokenType::SemiColon); // consume optional ; between init and cond
        node_ptr cond = expression();
        have(TokenType::SemiColon); // consume optional ; between cond and step
        node_ptr step = statement(); // i += 1 or i = i + 1
        mustBe(TokenType::ParenClose);
        have(TokenType::Colon);
        node_ptr body_node = blockOrStmt();
        // Desugar to: { init; while (cond) { body; step; } }
        auto block = make_node<BlockNode>(tok);
        block->add(init_stmt);
        // Build while body: body + step
        auto while_body = make_node<BlockNode>(tok);
        while_body->add(body_node);
        while_body->add(step);
        auto while_node = make_node<WhileNode>(tok, cond, while_body);
        block->add(while_node);
        return block;
    }
    node_ptr var = make_node<VariableNode>(token());
    next(); // consume variable name
    // Check for tuple unpacking: for k, v in ...
    std::vector<node_ptr> unpack_vars;
    while(have(TokenType::Comma)) {
        unpack_vars.push_back(make_node<VariableNode>(token()));
        next();
    }
    mustBe(TokenType::In);
    node_ptr iter = expression();
    if(hp) mustBe(TokenType::ParenClose);
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    auto fnode = make_node<ForNode>(tok, var, iter, body);
    static_cast<ForNode*>(fnode.get())->unpack_vars = std::move(unpack_vars);
    return fnode;
}

node_ptr Parser::functionDecl(bool is_method){
    Token tok = token();
    next(); // consume def/function/fn
    std::string name = identifier();
    std::vector<node_ptr> params;
    if(see(TokenType::ParenOpen)) {
        next(); // consume (
        params = paramList();
        mustBe(TokenType::ParenClose);
    }
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    auto fn = make_node<FunctionNode>(tok, name, body, is_method);
    for(auto& p : params) fn->add(p);
    static_cast<FunctionNode*>(fn.get())->defaults = std::move(param_defaults_);
    return fn;
}


std::vector<node_ptr> Parser::lambdaParamList(){
    std::vector<node_ptr> params;
    param_defaults_.clear();
    if(see(TokenType::Colon)) return params; // no params
    auto parse_one_param = [&]() {
        bool va = have(TokenType::Mul);
        bool kw = !va && have(TokenType::Exp);
        Token ptok = token();
        ptok.value = token().value;
        next();
        auto pnode = make_node<VariableNode>(ptok);
        if(va) static_cast<VariableNode*>(pnode.get())->name = "*" + ptok.value;
        else if(kw) static_cast<VariableNode*>(pnode.get())->name = "**" + ptok.value;
        else static_cast<VariableNode*>(pnode.get())->name = ptok.value;
        params.push_back(pnode);
        if(have(TokenType::Assign)) param_defaults_.push_back(expression());
        else param_defaults_.push_back(nullptr);
    };
    parse_one_param();
    while(have(TokenType::Comma) && !see(TokenType::Colon)){
        parse_one_param();
    }
    return params;
}
std::vector<node_ptr> Parser::paramList(){
    std::vector<node_ptr> params;
    param_defaults_.clear();
    if(!see(TokenType::ParenClose)){
        // Check for *args or **kwargs
        auto parse_one_param = [&]() {
            bool va = have(TokenType::Mul);
            bool kw = !va && have(TokenType::Exp);
            // Accept identifier or keyword as param name
            Token ptok = token();
            ptok.value = token().value; // ensure we get the text
            next();
            auto pnode = make_node<VariableNode>(ptok);
            if(va) static_cast<VariableNode*>(pnode.get())->name = "*" + ptok.value;
            else if(kw) static_cast<VariableNode*>(pnode.get())->name = "**" + ptok.value;
            else static_cast<VariableNode*>(pnode.get())->name = ptok.value;
            params.push_back(pnode);
            if(have(TokenType::Assign)) param_defaults_.push_back(expression());
            else param_defaults_.push_back(nullptr);
        };
        parse_one_param();
        while(have(TokenType::Comma)){
            parse_one_param();
        }
    }
    return params;
}

std::vector<node_ptr> Parser::argList(){
    std::vector<node_ptr> args;
    if(!see(TokenType::ParenClose)){
        auto parse_arg = [&]() -> node_ptr {
            if(have(TokenType::Mul)){
                // *args spread: create UnaryNode with op="*"
                Token star = prev();
                node_ptr operand = expression();
                return make_node<UnaryNode>(star, operand);
            }
            if(have(TokenType::Exp)){
                // **kwargs spread: create UnaryNode with op="**"
                Token dstar = prev();
                node_ptr operand = expression();
                return make_node<UnaryNode>(dstar, operand);
            }
            return expression();
        };
        args.push_back(parse_arg());
        while(have(TokenType::Comma)) args.push_back(parse_arg());
    }
    return args;
}

node_ptr Parser::classDecl(){
    Token tok = token();
    mustBe(TokenType::Class);
    std::string name = identifier();
    // Optional bases: class Foo(Bar, Baz) or class Foo extends Bar
    // Supports: extends, inherits, and parenthesized syntax
    std::vector<node_ptr> bases;
    if(have(TokenType::ParenOpen)){
        if(!see(TokenType::ParenClose)){
            bases.push_back(make_node<VariableNode>(token())); next();
            while(have(TokenType::Comma)){ bases.push_back(make_node<VariableNode>(token())); next(); }
        }
        mustBe(TokenType::ParenClose);
    } else if(have(TokenType::Extends) || have(TokenType::Inherits)) {
        // class Foo extends Bar or class Foo inherits Bar
        bases.push_back(make_node<VariableNode>(token())); next();
        while(have(TokenType::Comma)){ bases.push_back(make_node<VariableNode>(token())); next(); }
    }
    // Optional: implements InterfaceA, InterfaceB
    if(have(TokenType::Implements)) {
        // Store interface names as additional bases for now
        bases.push_back(make_node<VariableNode>(token())); next();
        while(have(TokenType::Comma)){ bases.push_back(make_node<VariableNode>(token())); next(); }
    }
    // Handle colon-based inheritance: class Foo : Bar (only if no extends/inherits)
    if(bases.empty() && have(TokenType::Colon)){
        if(see(TokenType::Identifier)){
            bases.push_back(make_node<VariableNode>(token())); next();
            while(have(TokenType::Comma)){ bases.push_back(make_node<VariableNode>(token())); next(); }
            have(TokenType::Colon);
        }
    }
    have(TokenType::Colon); // consume : before block
    node_ptr body = blockOrStmt();
    auto cls = make_node<ClassNode>(tok, name, body);
    std::static_pointer_cast<ClassNode>(cls)->bases = bases;
    return cls;
}

node_ptr Parser::interfaceDecl(){
    Token tok = token();
    mustBe(TokenType::Interface);
    std::string name = identifier();
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    return make_node<InterfaceNode>(tok, name, body);
}

node_ptr Parser::enumDecl(){
    Token tok = token();
    mustBe(TokenType::Enum);
    std::string name = identifier();
    have(TokenType::Colon);
    bool has_brace = have(TokenType::BraceOpen);
    have(TokenType::NewLine);
    bool has_indent = have(TokenType::Indent);
    auto en = make_node<EnumNode>(tok, name);
    auto end_check = [&]() -> bool {
        if(has_brace) return see(TokenType::BraceClose);
        if(has_indent) return see(TokenType::Dedent);
        return see(TokenType::End)||see(TokenType::NewLine);
    };
    while(!end_check()&&!see(TokenType::End)){
        while(have(TokenType::NewLine)) {}
        if(end_check()) break;
        Token itok = token();
        std::string iname = identifier();
        node_ptr ival = nullptr;
        if(have(TokenType::Assign)) ival = expression();
        en->add(make_node<EnumItemNode>(itok, iname, ival));
        have(TokenType::Comma); have(TokenType::NewLine);
    }
    if(has_brace) have(TokenType::BraceClose);
    if(has_indent) have(TokenType::Dedent);
    have(TokenType::NewLine);
    return en;
}

node_ptr Parser::namespaceDecl(){
    Token tok = token();
    mustBe(TokenType::NameSpace);
    std::string name = identifier();
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    return make_node<NameSpaceNode>(tok, name, body);
}

node_ptr Parser::returnStmt(){
    Token tok = token();
    mustBe(TokenType::Return);
    node_ptr expr = nullptr;
    if(!see(TokenType::NewLine)&&!see(TokenType::SemiColon)&&!see(TokenType::End))
        expr = expression();
    // Support multiple return values: return a, b, c -> return [a, b, c]
    if(see(TokenType::Comma) && expr) {
        auto list = make_node<ListNode>(tok);
        list->add(expr);
        while(have(TokenType::Comma)) {
            list->add(expression());
        }
        expr = list;
    }
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<ReturnNode>(tok, expr);
}

node_ptr Parser::breakStmt(){
    Token tok = token(); mustBe(TokenType::Break);
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<BreakNode>(tok);
}

node_ptr Parser::continueStmt(){
    Token tok = token(); mustBe(TokenType::Continue);
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<ContinueNode>(tok);
}

node_ptr Parser::passStmt(){
    Token tok = token(); mustBe(TokenType::Pass);
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<PassNode>(tok);
}

node_ptr Parser::yieldStmt(){
    Token tok = token(); mustBe(TokenType::Yield);
    // yield from <iterable>
    if(have(TokenType::From)){
        node_ptr src = expression();
        have(TokenType::SemiColon); have(TokenType::NewLine);
        return make_node<YieldFromNode>(tok, src);
    }
    node_ptr expr = nullptr;
    if(!see(TokenType::NewLine)&&!see(TokenType::SemiColon)) expr = expression();
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<YieldNode>(tok, expr);
}

node_ptr Parser::printStmt(){
    Token tok = token(); mustBe(TokenType::Print);
    auto node = make_node<PrintNode>(tok);
    if(!see(TokenType::NewLine)&&!see(TokenType::SemiColon)&&!see(TokenType::End)){
        node->add(expression());
        while(have(TokenType::Comma)) node->add(expression());
    }
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return node;
}

node_ptr Parser::importStmt(){
    Token tok = token();
    if(have(TokenType::From)){
        std::string mod = dottedName();
        mustBe(TokenType::Import);
        auto imp = make_node<ImportNode>(tok, mod);
        auto& names = std::static_pointer_cast<ImportNode>(imp)->names;
        if(have(TokenType::Mul)){
            names.push_back("*");
        } else {
            names.push_back(identifier());
            while(have(TokenType::Comma)) names.push_back(identifier());
        }
        have(TokenType::SemiColon); have(TokenType::NewLine);
        return imp;
    }
    mustBe(TokenType::Import);
    std::string mod = dottedName();
    auto imp = make_node<ImportNode>(tok, mod);
    if(have(TokenType::As)){
        std::static_pointer_cast<ImportNode>(imp)->alias = identifier();
    }
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return imp;
}

node_ptr Parser::tryStmt(){
    Token tok = token();
    mustBe(TokenType::Try);
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    auto try_node = make_node<TryNode>(tok, body);
    auto tn = std::static_pointer_cast<TryNode>(try_node);
    while(have(TokenType::NewLine)) {}
    while(see(TokenType::Except)){
        next(); // consume 'except'
        std::string ename, ealias;
        if(see(TokenType::As)){
            // "except as e:" — catch-all with alias
            next(); // consume 'as'
            if(see(TokenType::Identifier)) ealias = identifier();
        } else if(see(TokenType::Identifier)){
            ename = identifier();
            if(have(TokenType::As)) ealias = identifier();
        }
        have(TokenType::Colon);
        node_ptr ebody = blockOrStmt();
        tn->except_clauses.push_back(make_node<ExceptNode>(tok, ename, ealias, ebody));
        while(have(TokenType::NewLine)) {}
    }
    return try_node;
}

node_ptr Parser::raiseStmt(){
    Token tok = token(); next(); // consume raise/throw
    node_ptr expr = nullptr;
    if(!see(TokenType::NewLine)&&!see(TokenType::SemiColon)) expr = expression();
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<RaiseNode>(tok, expr);
}

node_ptr Parser::assertStmt(){
    Token tok = token(); mustBe(TokenType::Assert);
    node_ptr cond = expression();
    node_ptr msg = nullptr;
    if(have(TokenType::Comma)) msg = expression();
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<AssertNode>(tok, cond, msg);
}

node_ptr Parser::switchStmt(){
    Token tok = token(); mustBe(TokenType::Switch);
    bool hp = have(TokenType::ParenOpen);
    node_ptr subject = expression();
    if(hp) mustBe(TokenType::ParenClose);
    have(TokenType::Colon);
    bool has_brace = have(TokenType::BraceOpen);
    have(TokenType::NewLine);
    bool has_indent = have(TokenType::Indent);
    auto sw = make_node<SwitchNode>(tok, subject);
    auto sn = std::static_pointer_cast<SwitchNode>(sw);
    // Parse case/default blocks
    auto at_end = [&]() -> bool {
        if(has_brace && see(TokenType::BraceClose)) return true;
        if(has_indent && see(TokenType::Dedent)) return true;
        if(see(TokenType::End)) return true;
        return false;
    };
    while(!at_end()){
        while(have(TokenType::NewLine)) {}
        if(at_end()) break;
        // Consume any stale indent/dedent from case bodies
        while(have(TokenType::Indent)||have(TokenType::Dedent)) {}
        while(have(TokenType::NewLine)) {}
        if(at_end()) break;
        if(have(TokenType::Case)){
            node_ptr val = expression();
            mustBe(TokenType::Colon);
            node_ptr body = blockOrStmt();
            sn->cases.push_back(make_node<CaseNode>(tok, val, body));
        } else if(have(TokenType::Default)){
            mustBe(TokenType::Colon);
            sn->default_case = make_node<DefaultNode>(tok, blockOrStmt());
        } else break;
    }
    if(has_indent) have(TokenType::Dedent);
    if(has_brace) have(TokenType::BraceClose);
    have(TokenType::NewLine);
    return sw;
}

node_ptr Parser::deleteStmt(){
    Token tok = token(); mustBe(TokenType::Delete);
    node_ptr target = expression();
    have(TokenType::SemiColon); have(TokenType::NewLine);
    return make_node<DeleteNode>(tok, target);
}

node_ptr Parser::withStmt(){
    Token tok = token(); mustBe(TokenType::With);
    node_ptr expr = expression();
    std::string alias;
    if(have(TokenType::As)) alias = identifier();
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    return make_node<WithNode>(tok, expr, alias, body);
}

node_ptr Parser::lambdaExpr(){
    Token tok = token(); mustBe(TokenType::Lambda);
    std::vector<node_ptr> params;
    // Only parse params if not immediately followed by ':'
    if(!see(TokenType::Colon)){
        params = lambdaParamList();
    }
    mustBe(TokenType::Colon);
    node_ptr body = expression();
    auto lam = make_node<LambdaNode>(tok, body);
    for(auto& p : params) lam->add(p);
    static_cast<LambdaNode*>(lam.get())->defaults = std::move(param_defaults_);
    return lam;
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOCK PARSING (supports Python-style indent, C-style braces, Lua do/end)
// ═══════════════════════════════════════════════════════════════════════════

node_ptr Parser::block(){
    Token tok = token();
    auto blk = make_node<BlockNode>(tok);
    if(have(TokenType::BraceOpen)){
        // C/JS style
        while(have(TokenType::NewLine)||have(TokenType::Indent)||have(TokenType::Dedent)) {}
        while(!see(TokenType::BraceClose)&&!see(TokenType::End)){
            blk->add(stmt());
            while(have(TokenType::NewLine)||have(TokenType::SemiColon)||have(TokenType::Indent)||have(TokenType::Dedent)) {}
        }
        have(TokenType::Dedent);
        mustBe(TokenType::BraceClose);
    } else if(have(TokenType::Do)){
        // Lua style
        while(have(TokenType::NewLine)||have(TokenType::Indent)||have(TokenType::Dedent)) {}
        while(!see(TokenType::EndBlock)&&!see(TokenType::End)){
            blk->add(stmt());
            while(have(TokenType::NewLine)||have(TokenType::SemiColon)||have(TokenType::Indent)||have(TokenType::Dedent)) {}
        }
        have(TokenType::EndBlock)||have(TokenType::End);
    } else {
        // Python style: indent-based (uses Indent/Dedent tokens from lexer)
        have(TokenType::NewLine);
        if(have(TokenType::Indent)){
            while(!see(TokenType::Dedent)&&!see(TokenType::End)){
                blk->add(stmt());
                while(have(TokenType::NewLine)||have(TokenType::SemiColon)) {}
            }
            have(TokenType::Dedent);
            have(TokenType::EndBlock)||have(TokenType::End); // consume trailing 'end' for then/end syntax
        } else {
            // Single statement
            blk->add(statement());
        }
    }
    return blk;
}

node_ptr Parser::blockOrStmt(){
    // Consume EVERY pending newline, not just one. A header whose expression
    // spans lines — `for j in ["x", "y",` / `"z"]:` — leaves more than one
    // NewLine token queued, so after eating a single newline the next token was
    // another NewLine rather than Indent. The indented suite was therefore not
    // recognised as a block and the first statement of the body was parsed as a
    // lone inline statement, which failed with a bare "Unexpected token".
    // Symptom: a `var` declaration as the first line of a body under a
    // multi-line loop header was a syntax error, while the same loop with the
    // list on one line parsed fine.
    while(have(TokenType::NewLine)) { }
    if(see(TokenType::BraceOpen)||see(TokenType::Do)||see(TokenType::Indent))
        return block();
    consumed_semi_ = false;
    node_ptr first = statement();
    // An inline suite may hold several statements separated by semicolons:
    //     def set_pos(self, x, y): self.x = x; self.y = y
    // Only the first was parsed; everything after the ';' was silently dropped,
    // so set_pos() assigned x and left y untouched. That is what drew the IDE's
    // output console at the top of the window instead of inside the panel.
    // Semicolons already worked at top level (see script()/stmt()); they now
    // work here too.
    if(!consumed_semi_) return first;
    auto blk = make_node<BlockNode>(this->token());
    if(first) blk->add(first);
    while(consumed_semi_){
        if(see(TokenType::NewLine)||see(TokenType::End)) break;
        consumed_semi_ = false;
        node_ptr more = statement();
        if(more) blk->add(more);
    }
    have(TokenType::NewLine);
    return blk;
}

// ═══════════════════════════════════════════════════════════════════════════
// COLLECTION LITERALS
// ═══════════════════════════════════════════════════════════════════════════

node_ptr Parser::listLiteral(){
    Token tok = token();
    mustBe(TokenType::BracketOpen);
    if(see(TokenType::BracketClose)){
        next();
        return make_node<ListNode>(tok); // empty list []
    }
    // Parse first expression
    node_ptr first = expression();
    // Check for list comprehension: [expr for var in iterable (for var2 in iter2)*]
    if(have(TokenType::For)){
        // Support tuple unpacking: for a, b in ...
        std::string var_name = identifier();
        std::string var_names_combined = var_name;
        while(see(TokenType::Comma)){
            have(TokenType::Comma);
            if(see(TokenType::In)) break; // trailing comma
            var_names_combined += "," + identifier();
        }
        var_name = var_names_combined;
        mustBe(TokenType::In);
        node_ptr iterable = logicalOr();
        // Check for nested for:
        std::string var_name2;
        node_ptr iterable2 = nullptr;
        if(have(TokenType::For)) {
            var_name2 = identifier();
            mustBe(TokenType::In);
            iterable2 = logicalOr();
        }
        node_ptr filter_expr = nullptr;
        if(have(TokenType::If)){
            filter_expr = expression();
        }
mustBe(TokenType::BracketClose);
        // Build a ComprehensionNode
        auto comp = make_node<ComplexNode>(tok);
        auto comp_ptr = std::static_pointer_cast<ComplexNode>(comp);
        comp_ptr->items.push_back(first);        // [0] = expr to evaluate
        comp_ptr->items.push_back(iterable);     // [1] = iterable
        if(filter_expr) comp_ptr->items.push_back(filter_expr); // [2] = optional filter
        else comp_ptr->items.push_back(nullptr);
        // Nested for: store var2 and iterable2
        if(iterable2) {
            Token v2tok = tok; v2tok.value = var_name2;
            comp_ptr->items.push_back(make_node<VariableNode>(v2tok)); // [3] = var2
            comp_ptr->items.push_back(iterable2);                      // [4] = iterable2
        }
        comp_ptr->_token.value = var_name;
        return comp;
    }
    // Regular list literal
    auto list = make_node<ListNode>(tok);
    list->add(first);
    while(have(TokenType::Comma)&&!see(TokenType::BracketClose))
        list->add(expression());
    mustBe(TokenType::BracketClose);
    return list;
}

node_ptr Parser::loopStmt(){
    Token tok = token();
    mustBe(TokenType::Loop);
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    // loop is just while(true) { body }
    auto cond = make_node<BoolNode>(tok, true);
    return make_node<WhileNode>(tok, cond, body);
}

node_ptr Parser::blockStmt(){
    Token tok = token();
    mustBe(TokenType::Block);
    have(TokenType::Colon);
    return blockOrStmt();
}

node_ptr Parser::repeatStmt(){
    Token tok = token();
    mustBe(TokenType::Repeat);
    // Counted form: `repeat N:` runs the body N times. Only the
    // `repeat: ... until cond` form existed, so a count was parsed as the start
    // of the body and the parser then demanded `until`, reporting
    // "Expected Until, but found Colon".
    if(!see(TokenType::Colon) && !see(TokenType::NewLine) && !see(TokenType::BraceOpen)){
        node_ptr count = expression();
        have(TokenType::Colon);
        node_ptr rbody = blockOrStmt();
        // Desugar to:  var __repeat_i = 0
        //              while __repeat_i < N:  body; __repeat_i = __repeat_i + 1
        static int repeat_seq = 0;
        std::string ctr = "__repeat_i" + std::to_string(repeat_seq++);
        Token id_tok = tok; id_tok.value = ctr;
        Token zero_tok = tok; zero_tok.value = "0";
        Token one_tok  = tok; one_tok.value  = "1";
        Token lt_tok   = tok; lt_tok.value   = "<";
        Token add_tok  = tok; add_tok.value  = "+";

        auto zero  = make_node<IntegerNode>(zero_tok);
        auto decl  = make_node<VarDeclNode>(tok, ctr, zero);
        auto cond  = make_node<BinaryNode>(lt_tok, make_node<VariableNode>(id_tok), count);
        auto inc   = make_node<AssignmentNode>(tok, make_node<VariableNode>(id_tok),
                        make_node<BinaryNode>(add_tok, make_node<VariableNode>(id_tok),
                                              make_node<IntegerNode>(one_tok)));
        auto inner = make_node<BlockNode>(tok);
        inner->add(rbody);
        inner->add(inc);
        auto outer = make_node<BlockNode>(tok);
        outer->add(decl);
        outer->add(make_node<WhileNode>(tok, cond, inner));
        return outer;
    }
    have(TokenType::Colon);
    node_ptr body = blockOrStmt();
    // repeat...until: execute body, then check condition
    // Transform to: do { body } while(!condition)
    mustBe(TokenType::Until);
    bool has_paren = have(TokenType::ParenOpen);
    node_ptr cond = expression();
    if(has_paren) mustBe(TokenType::ParenClose);
    // Create: while(true) { body; if(cond) break; }
    auto block = make_node<BlockNode>(tok);
    block->add(body);
    auto brk = make_node<BreakNode>(tok);
    auto if_break = make_node<IfNode>(tok, cond, brk);
    block->add(if_break);
    auto true_cond = make_node<BoolNode>(tok, true);
    return make_node<WhileNode>(tok, true_cond, block);
}

node_ptr Parser::mapLiteral(){
    Token tok = token();
    mustBe(TokenType::BraceOpen);
    // Could be a map or a block — if first token is identifier followed by colon, it's a map
    if(see(TokenType::BraceClose)){
        next(); return make_node<MapNode>(tok); // empty map
    }
    auto map = make_node<MapNode>(tok);
    node_ptr key = expression();
    if(have(TokenType::Colon)){
        // It's a map
        node_ptr val = expression();
        // Check for dict comprehension: {k: v for var in iterable if cond}
        if(see(TokenType::For)) {
            next(); // consume 'for'
            std::string var_name = identifier();
            // Check for tuple unpacking: for k, v in ...
            std::string var_name2;
            if(have(TokenType::Comma)) {
                var_name2 = identifier();
            }
            mustBe(TokenType::In);
            node_ptr iter = logicalOr(); // don't consume 'if' as ternary
            // Optional filter
            node_ptr filter_expr = nullptr;
            if(have(TokenType::If)) {
                filter_expr = expression();
            }
            mustBe(TokenType::BraceClose);
            // Transform into: (lambda: var __d={} \n for var_name in iter: __d[key_expr]=val_expr \n return __d)()
            // Simpler: create a special ComprehensionNode that builds a map
            // For now, generate equivalent AST:
            auto block = make_node<BlockNode>(tok);
            // var __dictcomp__ = {}
            auto empty_map = make_node<MapNode>(tok);
            block->add(make_node<VarDeclNode>(tok, "__dictcomp__", empty_map, false, false));
            // for var_name in iter:
            Token var_tok = tok; var_tok.value = var_name;
            auto loop_var = make_node<VariableNode>(var_tok);
            // __dictcomp__[key] = val
            Token dc_tok = tok; dc_tok.value = "__dictcomp__";
            auto dc_var = make_node<VariableNode>(dc_tok);
            auto subscr = make_node<SubscriptNode>(tok, dc_var, key);
            auto assign = make_node<AssignmentNode>(tok, subscr, val);
            // Build for body: optionally wrap in if filter
            node_ptr for_body;
            if (filter_expr) {
                // Create: if cond: assign (with no else)
                auto if_block = make_node<IfNode>(tok, filter_expr, assign);
                for_body = if_block;
            } else {
                for_body = assign;
            }
            auto for_node = make_node<ForNode>(tok, loop_var, iter, for_body);
            // Add tuple unpacking vars
            if (!var_name2.empty()) {
                Token v2tok = tok; v2tok.value = var_name2;
                for_node->add(make_node<VariableNode>(v2tok));
                static_cast<ForNode*>(for_node.get())->unpack_vars.push_back(make_node<VariableNode>(v2tok));
            }
            block->add(for_node);
            // return __dictcomp__
            Token dc_tok2 = tok; dc_tok2.value = "__dictcomp__";
            block->add(make_node<VariableNode>(dc_tok2));
            return block;
        }
        map->add(make_node<MapEntryNode>(tok, key, val));
        while(have(TokenType::Comma)&&!see(TokenType::BraceClose)){
            node_ptr k = expression();
            mustBe(TokenType::Colon);
            node_ptr v = expression();
            map->add(make_node<MapEntryNode>(tok, k, v));
        }
        mustBe(TokenType::BraceClose);
        return map;
    }
    // Set literal: {expr1, expr2, ...}
    // Build as: set([expr1, expr2, ...])
    // Set literal or set comprehension: {expr ...}
    // Check for set comprehension: {expr for var in iter [if cond]}
    if (see(TokenType::For)) {
        next(); // consume 'for'
        std::string var_name = identifier();
        std::string var_name2;
        if (have(TokenType::Comma)) var_name2 = identifier();
        mustBe(TokenType::In);
        node_ptr iter = logicalOr();
        node_ptr filter_expr = nullptr;
        if (have(TokenType::If)) filter_expr = expression();
        mustBe(TokenType::BraceClose);
        // Generate: var __setcomp__ = set([]) \n for var in iter: if cond: __setcomp__.add(key)\n return __setcomp__
        auto block = make_node<BlockNode>(tok);
        // var __setcomp__ = set([])
        auto empty_list = make_node<ListNode>(tok);
        Token set_tok2 = tok; set_tok2.value = "set";
        auto set_var2 = make_node<VariableNode>(set_tok2);
        auto set_call = make_node<CallNode>(tok, set_var2);
        set_call->add(empty_list);
        block->add(make_node<VarDeclNode>(tok, "__setcomp__", set_call, false, false));
        // for var_name in iter: __setcomp__.add(key)
        Token sc_tok = tok; sc_tok.value = "__setcomp__";
        auto sc_var = make_node<VariableNode>(sc_tok);
        Token add_tok = tok; add_tok.value = "add";
        auto add_attr = make_node<AttributeNode>(tok, sc_var, "add");
        auto add_call = make_node<CallNode>(tok, add_attr);
        add_call->add(key);
        node_ptr for_body = filter_expr ? (node_ptr)make_node<IfNode>(tok, filter_expr, add_call) : (node_ptr)add_call;
        Token var_tok = tok; var_tok.value = var_name;
        auto loop_var = make_node<VariableNode>(var_tok);
        auto for_node = make_node<ForNode>(tok, loop_var, iter, for_body);
        if (!var_name2.empty()) {
            Token v2tok = tok; v2tok.value = var_name2;
            static_cast<ForNode*>(for_node.get())->unpack_vars.push_back(make_node<VariableNode>(v2tok));
        }
        block->add(for_node);
        Token sc_tok2 = tok; sc_tok2.value = "__setcomp__";
        block->add(make_node<VariableNode>(sc_tok2));
        return block;
    }
    auto list = make_node<ListNode>(tok);
    list->add(key);
    while(have(TokenType::Comma) && !see(TokenType::BraceClose)){
        list->add(expression());
    }
    mustBe(TokenType::BraceClose);
    // Wrap in set([...]) call
    Token set_tok = tok; set_tok.value = "set";
    auto set_var = make_node<VariableNode>(set_tok);
    auto call = make_node<CallNode>(tok, set_var);
    call->add(list);
    return call;
}

node_ptr Parser::tupleLiteral(){
    Token tok = token();
    mustBe(TokenType::ParenOpen);
    auto tuple = make_node<TupleNode>(tok);
    if(!see(TokenType::ParenClose)){
        tuple->add(expression());
        while(have(TokenType::Comma)) tuple->add(expression());
    }
    mustBe(TokenType::ParenClose);
    return tuple;
}

} // namespace nython::parser

#pragma GCC diagnostic pop
