#pragma once// VirtualMachine.hpp — Nython Bytecode VM
// Compiler: AST → Bytecode. VM: Stack-based execution engine.
#ifndef __VIRTUAL_MACHINE__HPP
#define __VIRTUAL_MACHINE__HPP

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmisleading-indentation"

#include <memory>
#include <vector>
#include <deque>
#include <string>
#include <unordered_map>
#include <functional>
#include <unordered_set>
#include <optional>
#include <cassert>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cmath>
#include <stdexcept>
#include <algorithm>
#include <limits>
#include <fstream>
#include <sys/stat.h>
#include <sys/types.h>
#ifndef _WIN32
#include <sys/resource.h>
#include <dirent.h>
#include <unistd.h>
#include <pthread.h>
#endif
#include <ctime>
#include <cstdlib>
#include <thread>
#include <chrono>
#include <functional>
#include <unordered_set>
#include <cerrno>
#include <random>

#include "Value.hpp"
#include "Object.hpp"
#include "Lexer.hpp"
#include "Parser.hpp"
#include "Runnable.hpp"
#include "GarbageCollector.hpp"
#include "ASTNodes.hpp"
#include "Context.hpp"

using nython::Runnable;
using nython::kernel::Value;
using nython::kernel::ValueType;
using nython::kernel::Object;
using nython::gc::GarbageCollector;

namespace nython::vm {

// ═══════════════════════════════════════════════════════════════════════════
// OPCODE
// ═══════════════════════════════════════════════════════════════════════════
enum class Op : uint8_t {
    LOAD_CONST, LOAD_NAME, STORE_NAME, DEFINE_NAME,
    LOAD_ATTR,  STORE_ATTR, LOAD_SUBSCR, STORE_SUBSCR, DELETE_SUBSCR, DELETE_ATTR,
    BUILD_LIST, BUILD_MAP,
    DUP_TOP, POP_TOP, ROT_TWO, ROT_THREE,
    BINARY_ADD, BINARY_SUB, BINARY_MUL, BINARY_DIV,
    BINARY_MOD, BINARY_POW, BINARY_FLOOR_DIV,
    BINARY_AND, BINARY_OR,  BINARY_XOR, BINARY_LSHIFT, BINARY_RSHIFT,
    COMPARE_EQ, COMPARE_NE, COMPARE_LT, COMPARE_LE,
    COMPARE_GT, COMPARE_GE, COMPARE_IN, COMPARE_NOT_IN,
    COMPARE_IS, COMPARE_IS_NOT,
    COMPARE_IS_TYPE, COMPARE_IS_NOT_TYPE,
    UNARY_NEG, UNARY_NOT, UNARY_BITNOT, UNARY_POS,
    JUMP_FORWARD, JUMP_IF_TRUE, JUMP_IF_FALSE, JUMP_ABSOLUTE,
    JUMP_IF_TRUE_OR_POP, JUMP_IF_FALSE_OR_POP,
    MAKE_FUNCTION, CALL_FUNCTION, CALL_METHOD, RETURN_VALUE, YIELD_VALUE, YIELD_FROM_OP,
    MAKE_CLASS, LOAD_SELF,
    GET_ITER, FOR_ITER, UNPACK_SEQ,
    PRINT, IMPORT_NAME, NOP, HALT,
    IADD, ISUB, IMUL, IDIV, IMOD,
    RAISE_ERROR, SETUP_EXCEPT, END_EXCEPT, CALL_KW, CALL_EX,
    LIST_EXTEND, LIST_APPEND, LOAD_SUPER,
    RAISE, STORE_EXCEPT_AS,
    LOAD_SELF_ATTR, STORE_SELF_ATTR,
};

// ═══════════════════════════════════════════════════════════════════════════
// INSTRUCTION
// ═══════════════════════════════════════════════════════════════════════════
struct Instruction {
    Op  op;
    int arg;
    int line;
    Instruction(Op o, int a=0, int ln=0) : op(o), arg(a), line(ln) {}
};

// ═══════════════════════════════════════════════════════════════════════════
// VMVAL  — runtime value for the VM stack
// ═══════════════════════════════════════════════════════════════════════════
enum class VMType : uint8_t {
    NONE, BOOL, INT, FLOAT, STRING, LIST, MAP,
    FUNCTION, CLASS, INSTANCE, ITERATOR, GENERATOR, NATIVE, UNDEFINED, SUPER_PROXY,
};

struct VMCode;  // forward declaration (defined after VMVal)
using NativeFunc = std::function<struct VMVal(std::vector<struct VMVal>&)>;

struct VMVal {
    VMType type = VMType::NONE;
    bool   b    = false;
    int64_t i   = 0;
    double  d   = 0.0;
    std::string s;
    std::shared_ptr<std::vector<VMVal>>                        list;
    std::shared_ptr<std::unordered_map<std::string,VMVal>>     map;
    std::shared_ptr<VMCode>                                    code;
    NativeFunc                                                 native;
    std::shared_ptr<std::pair<int,std::vector<VMVal>>>         iter;
    std::shared_ptr<struct GenState>                           gen;
    std::string class_name;
    // Closure environment: captured variables from enclosing scope
    std::shared_ptr<std::unordered_map<std::string,VMVal>>     closure_env;

    static VMVal make_none()              { return {}; }
    static VMVal make_bool(bool v)        { VMVal x; x.type=VMType::BOOL;  x.b=v; return x; }
    static VMVal make_int(int64_t v)      { VMVal x; x.type=VMType::INT;   x.i=v; return x; }
    static VMVal make_float(double v)     { VMVal x; x.type=VMType::FLOAT; x.d=v; return x; }
    static VMVal make_str(std::string v)  { VMVal x; x.type=VMType::STRING;x.s=std::move(v); return x; }
    static VMVal make_list(std::vector<VMVal> items={}) {
        VMVal x; x.type=VMType::LIST;
        x.list=std::make_shared<std::vector<VMVal>>(std::move(items)); return x;
    }
    static VMVal make_map() {
        VMVal x; x.type=VMType::MAP;
        x.map=std::make_shared<std::unordered_map<std::string,VMVal>>(); return x;
    }
    static VMVal make_func(std::shared_ptr<VMCode> c) {
        VMVal x; x.type=VMType::FUNCTION; x.code=c; return x;
    }
    static VMVal make_class(std::shared_ptr<VMCode> c, std::string name) {
        VMVal x; x.type=VMType::CLASS; x.code=c; x.class_name=std::move(name); return x;
    }
    static VMVal make_instance(std::string cname,
        std::shared_ptr<std::unordered_map<std::string,VMVal>> attrs) {
        VMVal x; x.type=VMType::INSTANCE; x.class_name=std::move(cname); x.map=attrs; return x;
    }
    static VMVal make_native(NativeFunc f) {
        VMVal x; x.type=VMType::NATIVE; x.native=std::move(f); return x;
    }
    static VMVal make_iter(std::vector<VMVal> items) {
        VMVal x; x.type=VMType::ITERATOR;
        x.iter=std::make_shared<std::pair<int,std::vector<VMVal>>>(0,std::move(items)); return x;
    }

    bool is_truthy() const {
        switch(type){
        case VMType::NONE:   return false;
        case VMType::BOOL:   return b;
        case VMType::INT:    return i!=0;
        case VMType::FLOAT:  return d!=0.0;
        case VMType::STRING: return !s.empty();
        case VMType::LIST:   return list&&!list->empty();
        case VMType::MAP:    return map&&!map->empty();
        default:             return true;
        }
    }

    std::string to_string() const;
    std::string repr() const;

    bool operator==(const VMVal& o) const {
        if(type!=o.type){
            if(type==VMType::INT&&o.type==VMType::FLOAT) return (double)i==o.d;
            if(type==VMType::FLOAT&&o.type==VMType::INT) return d==(double)o.i;
            return false;
        }
        switch(type){
        case VMType::NONE:   return true;
        case VMType::BOOL:   return b==o.b;
        case VMType::INT:    return i==o.i;
        case VMType::FLOAT:  return d==o.d;
        case VMType::STRING: return s==o.s;
        case VMType::LIST:
            if(!list&&!o.list) return true;
            if(!list||!o.list) return false;
            if(list->size()!=o.list->size()) return false;
            for(size_t idx=0;idx<list->size();idx++)
                if(!((*list)[idx]==(*o.list)[idx])) return false;
            return true;
        case VMType::MAP:
            if(!map&&!o.map) return true;
            if(!map||!o.map) return false;
            if(map->size()!=o.map->size()) return false;
            for(auto& [k,v]:*map){
                auto it=o.map->find(k);
                if(it==o.map->end()||!(v==it->second)) return false;}
            return true;
        case VMType::INSTANCE:
            // Two instances are equal only if same pointer (identity comparison)
            return map.get()==o.map.get();
        default:             return false;
        }
    }
    bool operator!=(const VMVal& o) const { return !(*this==o); }
    bool operator<(const VMVal& o) const {
        if(type==VMType::INT&&o.type==VMType::INT) return i<o.i;
        if(type==VMType::FLOAT||o.type==VMType::FLOAT){
            double a=type==VMType::FLOAT?d:(double)i;
            double bb=o.type==VMType::FLOAT?o.d:(double)o.i;
            return a<bb;
        }
        if(type==VMType::STRING&&o.type==VMType::STRING) return s<o.s;
        return false;
    }
    bool operator<=(const VMVal& o) const { return *this==o||*this<o; }
    bool operator> (const VMVal& o) const { return o<*this; }
    bool operator>=(const VMVal& o) const { return o<=*this; }
};

// ═══════════════════════════════════════════════════════════════════════════
// VMCODE — compiled code object
// ═══════════════════════════════════════════════════════════════════════════
struct ExceptionEntry {
    int try_start = 0;
    int try_end   = 0;
    // One entry per `except` clause, tried in source order - mirrors the
    // interpreter's evalTry (NythonExecutor.hpp), which walks tn->except_clauses
    // and runs the first one whose declared type matches (or is a parent of)
    // the raised exception's type, or that has no declared type at all. The
    // VM used to have a single `handler`/`alias` here and always ran the
    // FIRST except clause's body regardless of its declared type - every
    // other clause's body wasn't even compiled.
    struct Clause {
        std::string type_name;   // empty = catch-all, matches any exception
        std::string bind_var;    // empty = don't bind (bare "except:")
        int handler = 0;         // bytecode offset of this clause's body
    };
    std::vector<Clause> clauses;
    // Bytecode offset of the `else` clause's body (runs only if the try body
    // did NOT raise), or -1 if there is none. Previously not compiled at all.
    int else_handler = -1;
    // Offset immediately after the whole try/except/else, used when an
    // exception is raised but no clause's type matches - the interpreter
    // silently falls through to `finally` in that case rather than
    // re-raising, so the VM matches that instead of leaving the exception
    // to propagate further up.
    int end = 0;
};

struct VMCode {
    std::string              name;
    std::string              parent_class;
    std::string              owner_class;   // class that defines this method
    std::vector<Instruction> instructions;
    std::vector<VMVal>       constants;
    std::vector<std::string> names;
    std::vector<std::string> param_names;
    std::vector<VMVal>       param_defaults; // parallel to param_names; UNDEFINED = no default
    bool                     is_class      = false;
    bool                     is_method     = false;
    bool                     is_static     = false;
    bool                     is_classmethod= false;
    bool                     is_generator  = false;
    std::shared_ptr<std::unordered_map<std::string,VMVal>> closure_env;
    std::vector<std::shared_ptr<VMCode>> sub_codes;
    std::vector<ExceptionEntry>          exc_table;

    int add_const(VMVal v) {
        if(v.type==VMType::NONE){
            for(int i=0;i<(int)constants.size();i++)
                if(constants[i].type==VMType::NONE) return i;
        }
        if(v.type==VMType::STRING){
            for(int i=0;i<(int)constants.size();i++)
                if(constants[i].type==VMType::STRING&&constants[i].s==v.s) return i;
        }
        constants.push_back(std::move(v));
        return (int)constants.size()-1;
    }
    int add_name(const std::string& n) {
        for(int i=0;i<(int)names.size();i++) if(names[i]==n) return i;
        names.push_back(n);
        return (int)names.size()-1;
    }
    int  emit(Op op, int arg=0, int line=0) {
        instructions.emplace_back(op,arg,line);
        return (int)instructions.size()-1;
    }
    void patch(int idx, int arg) { instructions[idx].arg=arg; }
    bool has_yield() const {
        for(auto& ins:instructions) if(ins.op==Op::YIELD_VALUE||ins.op==Op::YIELD_FROM_OP) return true;
        for(auto& sub:sub_codes) if(sub && sub->has_yield()) return true;
        return false;
    }
    int  here() const { return (int)instructions.size(); }
};


// ── VMVal method bodies (defined after VMCode is complete) ────────────────
inline std::string VMVal::to_string() const {
    switch(type){
    case VMType::NONE:    return "none";
    case VMType::BOOL:    return b?"true":"false";
    case VMType::INT:     return std::to_string(i);
    case VMType::FLOAT:{
        // 15 significant digits, matching the interpreter. The default stream
        // precision is 6, so the same computation printed differently
        // depending on which engine ran it: 1.0/3.0 gave 0.333333 here and
        // 0.333333333333333 there.
        std::ostringstream oss; oss<<std::setprecision(15)<<d;
        std::string r=oss.str();
        if(r.find('.')==std::string::npos&&r.find('e')==std::string::npos
           &&r.find("inf")==std::string::npos&&r.find("nan")==std::string::npos) r+=".0";
        return r;
    }
    case VMType::STRING:  return s;
    case VMType::LIST:{
        std::string r="[";
        if(list) for(size_t k=0;k<list->size();k++){if(k)r+=", ";r+=(*list)[k].repr();}
        return r+"]";
    }
    case VMType::MAP:{
        std::string r="{"; bool first=true;
        if(map) for(auto&[k,v]:*map){if(!first)r+=", ";r+=k+": "+v.repr();first=false;}
        return r+"}";
    }
    case VMType::FUNCTION: return "<function "+(code?code->name:"?")+">"; 
    case VMType::CLASS:    return "<class "+class_name+">";
    case VMType::INSTANCE: {
        if(map){
            auto it=map->find("msg");
            if(it!=map->end()&&it->second.type==VMType::STRING)
                return class_name+": "+it->second.s;
        }
        return "<"+class_name+" instance>";
    }
    case VMType::NATIVE:   return "<native>";
    case VMType::ITERATOR: return "<iterator>";
        case VMType::GENERATOR: return "<generator>";
    default:               return "undefined";
    }
}
inline std::string VMVal::repr() const {
    // Single quotes, matching the interpreter: str(["a"]) must render the same
    // on both engines, otherwise any test or program comparing stringified
    // containers gets different answers depending on how it was run.
    if(type==VMType::STRING) return "'"+s+"'";
    return to_string();
}


// ═══════════════════════════════════════════════════════════════════════════
// COMPILER  —  AST  →  VMCode
// ═══════════════════════════════════════════════════════════════════════════
// Names that denote a TYPE rather than a variable, used when compiling `is`.
// Free function because both the Compiler and the VM need it and it has no
// state. A lowercase bare name stays a value comparison; a capitalised one is
// treated as a class name, which is resolved against class_reg_ at runtime.
inline bool isTypeNameToken(const std::string& n) {
    static const std::set<std::string> t = {
        "int","Integer","integer","float","Float","double","Double",
        "str","String","string","bool","Boolean","boolean",
        "list","List","array","Array","map","Map","dict","Dict",
        "none","None","function","Function","Object","object","any","Any"
    };
    if(t.count(n)) return true;
    return !n.empty() && n[0]>='A' && n[0]<='Z';
}

class Compiler {
    std::shared_ptr<VMCode>              code_;
    std::vector<std::shared_ptr<VMCode>> code_stack_;
    int comp_counter_ = 0;

    void push_code(const std::string& name, bool is_class=false) {
        auto c=std::make_shared<VMCode>(); c->name=name; c->is_class=is_class;
        code_stack_.push_back(code_); code_=c;
    }
    std::shared_ptr<VMCode> pop_code() {
        auto c=code_; code_=code_stack_.back(); code_stack_.pop_back();
        // If this code is a method inside a class, tag its owner_class
        if(code_->is_class && c->owner_class.empty())
            c->owner_class = code_->name;
        code_->sub_codes.push_back(c); return c;
    }
    VMCode& C() { return *code_; }

    void emit(Op op,int arg=0,int ln=0)    { C().emit(op,arg,ln); }
    void emit_lc(VMVal v,int ln=0)         { emit(Op::LOAD_CONST,  C().add_const(std::move(v)),ln); }
    void emit_ln(const std::string& n,int l=0){ emit(Op::LOAD_NAME,  C().add_name(n),l); }
    void emit_sn(const std::string& n,int l=0){ emit(Op::STORE_NAME, C().add_name(n),l); }
    void emit_dn(const std::string& n,int l=0){ emit(Op::DEFINE_NAME,C().add_name(n),l); }
    int  ln(nython::node::node_ptr nd) { return nd?nd->token().location().row:0; }

    static constexpr int BREAK_PH=-9991, CONT_PH=-9992;
    // is_for: the loop keeps an iterator on the value stack between iterations
    // (pushed by GET_ITER, popped by FOR_ITER on exhaustion). A `break` jumps
    // past FOR_ITER, so it must pop that iterator itself or it is left behind
    // and the *enclosing* loop's FOR_ITER advances it instead of its own.
    struct LoopCtx { int start; std::vector<int> breaks,conts; bool is_for=false; };
    std::vector<LoopCtx> loops_;

public:
    Compiler() : code_(std::make_shared<VMCode>()) { code_->name="<module>"; }

    std::shared_ptr<VMCode> compile(nython::node::node_ptr root) {
        if(!root) return code_;
        visit(root);
        emit(Op::HALT);
        return code_;
    }

private:
    using NT = nython::node::NodeType;
    using np = nython::node::node_ptr;

    // ─── statement wrapper — pops discarded expression results ─────────────
    void visit_stmt(np nd) {
        if(!nd) return;
        auto nt=nd->type();
        visit(nd);
        // Pop the result if this is a call-as-statement (result unused)
        bool is_expr_stmt = (nt==NT::CALL || nt==NT::TUPLE || nt==NT::LIST);
        if(is_expr_stmt) emit(Op::POP_TOP,0,ln(nd));
    }

    // ─── dispatch ──────────────────────────────────────────────────────────
    void visit(np nd) {
        if(!nd) return;
        int l=ln(nd);
        if(nd->type()==NT::WALRUS) std::cerr<<"[DBG] visit WALRUS node!\n";
        switch(nd->type()) {
        // Literals
        case NT::INTEGER: emit_lc(VMVal::make_int(std::stoll(nd->token().value)),l); break;
        case NT::FLOAT:   emit_lc(VMVal::make_float(std::stod(nd->token().value)),l); break;
        case NT::STRING:  emit_lc(VMVal::make_str(nd->token().value),l); break;
        case NT::TRUE:    emit_lc(VMVal::make_bool(true),l); break;
        case NT::FALSE:   emit_lc(VMVal::make_bool(false),l); break;
        case NT::NONE:    emit_lc(VMVal::make_none(),l); break;

        // Names
        case NT::VARIABLE: emit_ln(nd->token().value,l); break;
        case NT::SELF:     emit(Op::LOAD_SELF,0,l); break;
        case NT::SUPER:    emit(Op::LOAD_SUPER,0,l); break;

        // Var decl
        case NT::VARIABLE_DECL: {
            auto vd=std::static_pointer_cast<nython::node::VarDeclNode>(nd);
            if(vd->init) visit(vd->init); else emit_lc(VMVal::make_none(),l);
            emit_dn(vd->name,l); break;
        }

        // Assign
        case NT::ASSIGNMENT: {
            auto an=std::static_pointer_cast<nython::node::AssignmentNode>(nd);
            // Special case: slice assignment obj[s:e] = val
            // (parser encodes as CallNode(obj.slice, [s,e]) as target)
            if(an->target && an->target->type()==NT::CALL) {
                auto cn=std::static_pointer_cast<nython::node::CallNode>(an->target);
                if(cn->callee && cn->callee->type()==NT::ATTRIBUTE) {
                    auto attr=std::static_pointer_cast<nython::node::AttributeNode>(cn->callee);
                    if(attr->attr=="slice" && cn->args.size()>=2) {
                        // STORE_SUBSCR pops: idx=TOS, obj=TOS1, val=TOS2
                        // So emit order (bottom→top): val, obj, [start,end]
                        visit(an->value_node);         // push val FIRST (lands at bottom)
                        visit(attr->object);           // push obj
                        visit(cn->args[0]);            // push start
                        visit(cn->args[1]);            // push end
                        emit(Op::BUILD_LIST,2,l);      // pop start,end → push [start,end]
                        emit(Op::STORE_SUBSCR,0,l);    // idx=TOS=[s,e], obj=TOS1=obj, val=TOS2=val ✓
                        break;
                    }
                }
                // Unknown call target: evaluate and discard
                visit(an->value_node);
                emit(Op::POP_TOP,0,l);
                break;
            }
            // Collect chained targets: a = b = 5 → [a, b], val=5
            {
                std::vector<nython::node::AssignmentNode*> chain;
                auto cur=an.get();
                while(cur->value_node && cur->value_node->type()==NT::ASSIGNMENT){
                    chain.push_back(cur);
                    cur=std::static_pointer_cast<nython::node::AssignmentNode>(cur->value_node).get();
                }
                chain.push_back(cur);  // last in chain
                // Emit the actual value (bottom of chain)
                visit(cur->value_node);
                // Store into each target from first to last, DUP_TOP before all but last
                for(int ci=0;ci<(int)chain.size();ci++){
                    if(ci<(int)chain.size()-1) emit(Op::DUP_TOP,0,l);
                    store(chain[ci]->target,l);
                }
            }
            break;
        }
        case NT::ASSIGNMENT_AUG: {
            auto an=std::static_pointer_cast<nython::node::AugAssignNode>(nd);
            // Load current value of target
            load_target(an->target,l);
            // Load new value and apply op
            visit(an->value_node);
            emit(aug_op(an->op),0,l);
            // Store back
            store(an->target,l); break;
        }

        // Attr / subscript
        case NT::ATTRIBUTE: {
            auto a=std::static_pointer_cast<nython::node::AttributeNode>(nd);
            visit(a->object); emit(Op::LOAD_ATTR,C().add_name(a->attr),l); break;
        }
        case NT::SUBSCRIPT: {
            auto s=std::static_pointer_cast<nython::node::SubscriptNode>(nd);
            visit(s->object); visit(s->index); emit(Op::LOAD_SUBSCR,0,l); break;
        }

        // Unary
        case NT::UNARY: {
            auto u=std::static_pointer_cast<nython::node::UnaryNode>(nd);
            visit(u->operand);
            std::string op=u->op;
            if(op=="-"||op=="neg")      emit(Op::UNARY_NEG,0,l);
            else if(op=="not"||op=="!") emit(Op::UNARY_NOT,0,l);
            else if(op=="~")            emit(Op::UNARY_BITNOT,0,l);
            else                        emit(Op::UNARY_POS,0,l);
            break;
        }

        // Binary
        case NT::BINARY: {
            auto b=std::static_pointer_cast<nython::node::BinaryNode>(nd);
            std::string op=b->op;
            if(op=="and"||op=="&&") {
                visit(b->left); int j=C().here();
                emit(Op::JUMP_IF_FALSE_OR_POP,0,l); visit(b->right);
                C().patch(j,C().here()); break;
            }
            if(op=="or"||op=="||") {
                visit(b->left); int j=C().here();
                emit(Op::JUMP_IF_TRUE_OR_POP,0,l); visit(b->right);
                C().patch(j,C().here()); break;
            }
            // `x is int` / `x is MyClass`: the right operand names a TYPE, not
            // a value. Compiling it as an ordinary load would look `int` up as a
            // variable — which since round 52 raises NameError rather than
            // yielding none. A distinct opcode carrying the name as a constant
            // keeps `x is int` and `x is "int"` different things.
            if((op=="is"||op=="is not") && b->right
               && b->right->type()==NT::VARIABLE){
                const std::string& tn=b->right->token().value;
                if(isTypeNameToken(tn)){
                    visit(b->left);
                    emit_lc(VMVal::make_str(tn),l);
                    emit(op=="is"?Op::COMPARE_IS_TYPE:Op::COMPARE_IS_NOT_TYPE,0,l);
                    break;
                }
            }
            visit(b->left); visit(b->right); emit(bin_op(op),0,l); break;
        }

        // Block/stmts/script
        case NT::SCRIPT: case NT::BLOCK: case NT::STATEMENTS: case NT::STATEMENT:
            for(auto& ch : nd->statements()) if(ch) visit_stmt(ch); break;

        // Print
        case NT::PRINT: {
            auto pn=std::static_pointer_cast<nython::node::PrintNode>(nd);
            // Flatten single-tuple arg (print("a", b) parsed as PrintNode with 1 TupleNode arg)
            std::vector<np> flat_args;
            for(auto& a: pn->args){
                if(a && a->type()==NT::TUPLE){
                    auto tn=std::static_pointer_cast<nython::node::TupleNode>(a);
                    for(auto& e:tn->elements) flat_args.push_back(e);
                } else flat_args.push_back(a);
            }
            if(!flat_args.empty()){
                // Convert first arg to string
                flat_args[0] ? visit(flat_args[0]) : emit_lc(VMVal::make_str(""),l);
                // Convert to string via str() if not already string-like
                for(size_t _pi=1;_pi<flat_args.size();_pi++){
                    emit_lc(VMVal::make_str(" "),l);
                    emit(Op::BINARY_ADD,0,l);
                    visit(flat_args[_pi]);
                    emit(Op::BINARY_ADD,0,l);
                }
            } else emit_lc(VMVal::make_str(""),l);
            emit(Op::PRINT,0,l); break;
        }

        // Return
        case NT::RETURN: {
            auto rn=std::static_pointer_cast<nython::node::ReturnNode>(nd);
            if(rn->expr) visit(rn->expr); else emit_lc(VMVal::make_none(),l);
            emit(Op::RETURN_VALUE,0,l); break;
        }

        // If
        case NT::IF: visit_if(std::static_pointer_cast<nython::node::IfNode>(nd)); break;
        // While
        case NT::WHILE: visit_while(std::static_pointer_cast<nython::node::WhileNode>(nd)); break;
        // For
        case NT::FOR:   visit_for(std::static_pointer_cast<nython::node::ForNode>(nd)); break;
        // Function
        case NT::FUNCTION: visit_func(std::static_pointer_cast<nython::node::FunctionNode>(nd)); break;
        // Lambda:  lambda x, y: expr
        case NT::LAMBDA: {
            auto lm=std::static_pointer_cast<nython::node::LambdaNode>(nd);
            push_code("<lambda>");
            for(auto& p:lm->params){
                std::string pn=p->value(); if(pn=="self") continue;
                C().param_names.push_back(pn); C().add_name(pn);
            }
            if(lm->body){ visit(lm->body); emit(Op::RETURN_VALUE,0,l); }
            else{ emit_lc(VMVal::make_none(),l); emit(Op::RETURN_VALUE,0,l); }
            pop_code();
            emit(Op::MAKE_FUNCTION,(int)C().sub_codes.size()-1,l); break;
        }
        // Tuple (treat as list)
        case NT::TUPLE: {
            auto tn=std::static_pointer_cast<nython::node::TupleNode>(nd);
            for(auto& e:tn->elements) visit(e);
            emit(Op::BUILD_LIST,(int)tn->elements.size(),l); break;
        }
        case NT::YIELD: {
            auto yn=std::static_pointer_cast<nython::node::YieldNode>(nd);
            if(yn->expr) visit(yn->expr); else emit(Op::LOAD_CONST,C().add_const(VMVal::make_none()),l);
            emit(Op::YIELD_VALUE,0,l);
            break;
        }
        // yield from iterable: iterate it, yield each item
        case NT::YIELD_FROM: {
            auto yn=std::static_pointer_cast<nython::node::YieldFromNode>(nd);
            visit(yn->expr);
            emit(Op::YIELD_FROM_OP,0,l);
            break;
        }
        // Walrus operator (var n = expr) → eval expr, dup, store, leave on stack
        case NT::WALRUS: {
            auto wn=std::static_pointer_cast<nython::node::WalrusNode>(nd);
            visit(wn->init);
            emit(Op::DUP_TOP,0,l);
            emit_dn(wn->name,l);
            // DEBUG: verify DUP_TOP leaves a value
            std::cerr<<"[DBG] WALRUS compiled: init, DUP_TOP, DEFINE_NAME("<<wn->name<<")\n";
            break;
        }
        // Pass / global / nonlocal
        case NT::PASS: case NT::GLOBAL:
            break;
        // del target  (variable, subscript, attribute)
        case NT::DELETE: {
            auto dn=std::static_pointer_cast<nython::node::DeleteNode>(nd);
            if(!dn->target) break;
            if(dn->target->type()==NT::VARIABLE){
                emit_lc(VMVal::make_none(),l);
                emit_sn(dn->target->token().value,l);
            } else if(dn->target->type()==NT::SUBSCRIPT){
                // del obj[key] — emit: LOAD obj, LOAD key, DELETE_SUBSCR
                auto s=std::static_pointer_cast<nython::node::SubscriptNode>(dn->target);
                visit(s->object); visit(s->index); emit(Op::DELETE_SUBSCR,0,l);
            } else if(dn->target->type()==NT::ATTRIBUTE){
                // del obj.attr — emit: LOAD obj, DELETE_ATTR
                auto a=std::static_pointer_cast<nython::node::AttributeNode>(dn->target);
                visit(a->object); emit(Op::DELETE_ATTR,C().add_name(a->attr),l);
            } else if(dn->target->type()==NT::CALL){
                // del lst[s:e] — slice delete (no-op for now)
                break;
            }
            break;
        }
        // Switch/match
        case NT::WITH: {
            auto wn=std::static_pointer_cast<nython::node::WithNode>(nd);
            int l2=ln(wn);
            // Store ctx manager in a hidden temp var
            static int with_cnt=0;
            std::string ctx_tmp="__with_ctx"+std::to_string(with_cnt++)+"__";
            visit(wn->expr);
            emit_dn(ctx_tmp,l2);
            // Call __enter__, bind result to alias
            emit_ln(ctx_tmp,l2);
            emit_lc(VMVal::make_str("__enter__"),l2);
            emit(Op::CALL_METHOD,0,l2);
            if(!wn->alias.empty()) emit_dn(wn->alias,l2);
            else emit(Op::POP_TOP,0,l2);
            // Body protected by SETUP_EXCEPT
            int exc_entry=C().here(); emit(Op::SETUP_EXCEPT,0,l2);
            if(wn->body) visit_stmt(wn->body);
            emit(Op::END_EXCEPT,0,l2);
            // Normal exit: ctx.__exit__(none,none,none)
            emit_ln(ctx_tmp,l2);
            emit_lc(VMVal::make_str("__exit__"),l2);
            emit_lc(VMVal::make_none(),l2);
            emit_lc(VMVal::make_none(),l2);
            emit_lc(VMVal::make_none(),l2);
            emit(Op::CALL_METHOD,3,l2);
            emit(Op::POP_TOP,0,l2);
            int end_jmp=C().here(); emit(Op::JUMP_FORWARD,0,l2);
            // Exception exit: ctx.__exit__(exc_type,exc_val,tb)
            C().patch(exc_entry,C().here());
            emit_ln(ctx_tmp,l2);
            emit_lc(VMVal::make_str("__exit__"),l2);
            emit_lc(VMVal::make_none(),l2);
            emit_lc(VMVal::make_none(),l2);
            emit_lc(VMVal::make_none(),l2);
            emit(Op::CALL_METHOD,3,l2);
            emit(Op::POP_TOP,0,l2);
            C().patch(end_jmp,C().here());
            break;
        }
        case NT::SWITCH: {
            auto sw=std::static_pointer_cast<nython::node::SwitchNode>(nd);
            visit(sw->subject);
            std::vector<int> end_jumps;
            bool wildcard_handled=false;
            for(auto& c:sw->cases){
                auto cn=std::static_pointer_cast<nython::node::CaseNode>(c);
                // Python-style `case _:` wildcard. The interpreter's
                // evalSwitch (NythonExecutor.hpp) special-cases a case value
                // of exactly "_" as always-match rather than a variable
                // lookup; this compiled it as an ordinary comparison
                // instead (subject == <value of undefined name _>, which
                // reads none and is never equal), so `case _:` never ran
                // on the VM.
                if(cn->value_node && cn->value_node->value()=="_"){
                    emit(Op::POP_TOP,0,l);
                    if(cn->body) visit(cn->body);
                    wildcard_handled=true;
                    break;
                }
                emit(Op::DUP_TOP,0,l);
                visit(cn->value_node);
                emit(Op::COMPARE_EQ,0,l);
                int jf=C().here(); emit(Op::JUMP_IF_FALSE,0,l);
                emit(Op::POP_TOP,0,l);
                if(cn->body) visit(cn->body);
                end_jumps.push_back(C().here()); emit(Op::JUMP_FORWARD,0,l);
                C().patch(jf,C().here());
            }
            if(!wildcard_handled){
                emit(Op::POP_TOP,0,l);
                if(sw->default_case) visit(sw->default_case);
            }
            int end=C().here();
            for(int j:end_jumps) C().patch(j,end);
            break;
        }
        // Class
        case NT::CLASS: visit_class(std::static_pointer_cast<nython::node::ClassNode>(nd)); break;
        // Call
        case NT::CALL: visit_call(std::static_pointer_cast<nython::node::CallNode>(nd)); break;

        // List literal
        // List comprehension (ComplexNode)
        case NT::COMPLEX: {
            auto cn=std::static_pointer_cast<nython::node::ComplexNode>(nd);
            // items: [0]=expr, [1]=iterable, [2]=filter(or null), 
            //        optionally [3]=var2, [4]=iterable2
            std::string var_name = cn->token().value;
            std::string tmp_name = "__lc" + std::to_string(comp_counter_++);
            // __tmp = []
            emit(Op::BUILD_LIST, 0, l);
            emit(Op::DEFINE_NAME, C().add_name(tmp_name), l);
            // Outer loop: for var_name in items[1]
            visit(cn->items[1]);                   // push iterable
            emit(Op::GET_ITER, 0, l);              // push iterator
            int loop_top = C().here();
            int for_iter_pos = C().here();
            emit(Op::FOR_ITER, 0, l);             // patch exit later
            // Handle tuple unpacking: "a,b" means UNPACK_SEQ 2
            if(var_name.find(',') != std::string::npos) {
                // Split var_name by comma and emit UNPACK_SEQ + STORE_NAME each
                std::vector<std::string> vnames;
                std::string tmp2; for(char ch:var_name){if(ch==','){vnames.push_back(tmp2);tmp2="";}else tmp2+=ch;}
                vnames.push_back(tmp2);
                emit(Op::UNPACK_SEQ, (int)vnames.size(), l);
                for(auto& vn : vnames) emit(Op::STORE_NAME, C().add_name(vn), l);
            } else {
                emit(Op::STORE_NAME, C().add_name(var_name), l);
            }
            // If nested for (items size >= 5)
            if(cn->items.size()>=5 && cn->items[3] && cn->items[4]) {
                std::string var2 = cn->items[3]->token().value;
                visit(cn->items[4]);
                emit(Op::GET_ITER, 0, l);
                int loop2_top = C().here();
                int for_iter2_pos = C().here();
                emit(Op::FOR_ITER, 0, l);
                emit(Op::STORE_NAME, C().add_name(var2), l);
                // Filter
                int filter_jmp = -1;
                if(cn->items[2]) {
                    visit(cn->items[2]);
                    filter_jmp = C().here();
                    emit(Op::JUMP_IF_FALSE, 0, l);
                }
                // __tmp.append(expr)
                emit(Op::LOAD_NAME, C().add_name(tmp_name), l);
                emit(Op::LOAD_ATTR, C().add_name("append"), l);
                visit(cn->items[0]);
                emit(Op::CALL_FUNCTION, 1, l);
                emit(Op::POP_TOP, 0, l);
                if(filter_jmp>=0) C().patch(filter_jmp, C().here());
                emit(Op::JUMP_ABSOLUTE, loop2_top, l);
                C().patch(for_iter2_pos, C().here());
                emit(Op::JUMP_ABSOLUTE, loop_top, l);
            } else {
                // Filter (items[2])
                int filter_jmp = -1;
                if(cn->items.size()>2 && cn->items[2]) {
                    visit(cn->items[2]);
                    filter_jmp = C().here();
                    emit(Op::JUMP_IF_FALSE, 0, l);
                }
                // __tmp.append(expr)  
                emit(Op::LOAD_NAME, C().add_name(tmp_name), l);
                emit(Op::LOAD_ATTR, C().add_name("append"), l);
                visit(cn->items[0]);
                emit(Op::CALL_FUNCTION, 1, l);
                emit(Op::POP_TOP, 0, l);
                if(filter_jmp>=0) C().patch(filter_jmp, C().here());
                emit(Op::JUMP_ABSOLUTE, loop_top, l);
            }
            C().patch(for_iter_pos, C().here());
            // Load result
            emit(Op::LOAD_NAME, C().add_name(tmp_name), l);
            break;
        }

        case NT::LIST: {
            auto ln_=std::static_pointer_cast<nython::node::ListNode>(nd);
            for(auto& e:ln_->elements) visit(e);
            emit(Op::BUILD_LIST,(int)ln_->elements.size(),l); break;
        }
        // Map literal
        case NT::MAP: {
            auto m=std::static_pointer_cast<nython::node::MapNode>(nd);
            for(auto& e:m->entries){
                auto ep=std::static_pointer_cast<nython::node::MapEntryNode>(e);
                visit(ep->key); visit(ep->val);
            }
            emit(Op::BUILD_MAP,(int)m->entries.size(),l); break;
        }

        // Break / Continue
        case NT::BREAK:
            // A break in a `for` must discard the iterator FOR_ITER would have
            // popped on natural exit; otherwise it outlives the loop.
            if(!loops_.empty() && loops_.back().is_for) emit(Op::POP_TOP,0,l);
            emit(Op::JUMP_ABSOLUTE,-9991,l); break;
        case NT::CONTINUE: emit(Op::JUMP_ABSOLUTE,-9992,l); break;

        // Import
        case NT::IMPORT: {
            auto in=std::static_pointer_cast<nython::node::ImportNode>(nd);
            std::string mn=in->module_name;
            if(mn.size()>=2&&(mn[0]=='"'||mn[0]=='\'')) mn=mn.substr(1,mn.size()-2);
            // `import "x" as m` — the alias travels with the module name so the
            // runtime can bind the namespace. The interpreter now does this;
            // without it here the same program would bind an alias on one
            // engine and not the other.
            if(!in->alias.empty())
                mn = mn + "\x01" + in->alias;
            emit(Op::IMPORT_NAME,C().add_name(mn),l); break;
        }


        // Raise
        case NT::RAISE: {
            auto rn=std::static_pointer_cast<nython::node::RaiseNode>(nd);
            if(rn->expr) visit(rn->expr);
            else emit_lc(VMVal::make_str("Exception"),l);
            emit(Op::RAISE_ERROR,0,l); break;
        }
        // Assert
        case NT::ASSERT: {
            auto an=std::static_pointer_cast<nython::node::AssertNode>(nd);
            visit(an->condition);
            int jt=C().here(); emit(Op::JUMP_IF_TRUE,0,l);
            if(an->message) visit(an->message);
            else emit_lc(VMVal::make_str("AssertionError"),l);
            emit(Op::RAISE_ERROR,0,l);
            C().patch(jt,C().here()); break;
        }
        // Try/except — exception table approach
        case NT::TRY: {
            auto tn=std::static_pointer_cast<nython::node::TryNode>(nd);
            ExceptionEntry ee;
            ee.try_start = C().here();
            // Compile try body
            if(tn->body) visit(tn->body);
            ee.try_end = C().here();
            // Jump over the handlers when no exception was raised.
            int jmp_over = C().here(); emit(Op::JUMP_FORWARD,0,l);
            // Compile EVERY except clause as its own handler entry point -
            // previously only the first clause's body was even compiled, so
            // `except TypeError:` after `except ValueError:` was dead code
            // and every exception ran the ValueError handler regardless of
            // its actual type. Which handler to jump to is decided at
            // runtime by match_except_handler(), comparing the raised
            // exception's type against each clause's type_name in order -
            // mirroring the interpreter's evalTry (NythonExecutor.hpp).
            std::vector<int> end_jumps;
            auto compile_clause=[&](const std::string& type_filter, const std::string& bind_var, node_ptr body){
                ExceptionEntry::Clause cl;
                cl.type_name=type_filter; cl.bind_var=bind_var;
                cl.handler=C().here();
                if(!bind_var.empty()) emit_dn(bind_var,l);
                else emit(Op::POP_TOP,0,l);
                if(body) visit(body);
                end_jumps.push_back(C().here()); emit(Op::JUMP_FORWARD,0,l);
                ee.clauses.push_back(std::move(cl));
            };
            for(auto& ec:tn->except_clauses){
                auto en=std::static_pointer_cast<nython::node::ExceptNode>(ec);
                // 'except e:'          -> name="e", alias=""    -> catch-all, bind "e"
                // 'except Err as e:'    -> name="Err", alias="e"  -> type "Err", bind "e"
                // 'except:'            -> name="", alias=""     -> catch-all, no bind
                bool has_type = !en->alias.empty();
                compile_clause(has_type?en->name:std::string(), has_type?en->alias:en->name, en->body);
            }
            if(tn->except_clauses.empty()){
                // try/finally with no except at all: give the dispatch a
                // catch-all landing spot that just discards the exception.
                compile_clause(std::string(),std::string(),nullptr);
            }
            // No-exception path (and "no clause matched") lands here.
            C().patch(jmp_over,C().here());
            ee.else_handler = tn->else_clause ? C().here() : -1;
            if(tn->else_clause) visit(tn->else_clause);
            int end_pos=C().here();
            for(int j:end_jumps) C().patch(j,end_pos);
            ee.end=end_pos;
            C().exc_table.push_back(ee);
            if(tn->finally_clause) visit(tn->finally_clause);
            break;
        }
        // Expression statement (discard result)
        case NT::RANGE: {
            auto rn=std::static_pointer_cast<nython::node::RangeNode>(nd);
            emit_ln("range",l);
            if(rn->start)visit(rn->start); else emit_lc(VMVal::make_int(0),l);
            if(rn->end_node)visit(rn->end_node); else emit_lc(VMVal::make_int(0),l);
            int rargc=2;
            if(rn->step){visit(rn->step);rargc=3;}
            emit(Op::CALL_FUNCTION,rargc,l); break;
        }
        case NT::SLICE: {
            // For subscript slicing: build a list [start,end,step]
            auto sn=std::static_pointer_cast<nython::node::SliceNode>(nd);
            if(sn->step){
                // Stepped slice: emit [start,end,step] with NONE marking an
                // omitted bound, because with a negative step "omitted" means
                // the *far* end, which 0/-1 cannot express. The two-element
                // form below is left exactly as it was so unstepped slices
                // keep their existing behaviour.
                if(sn->start)visit(sn->start); else emit_lc(VMVal::make_none(),l);
                if(sn->end_node)visit(sn->end_node); else emit_lc(VMVal::make_none(),l);
                visit(sn->step);
                emit(Op::BUILD_LIST,3,l); break;
            }
            if(sn->start)visit(sn->start); else emit_lc(VMVal::make_int(0),l);
            if(sn->end_node)visit(sn->end_node); else emit_lc(VMVal::make_int(-1),l);
            emit(Op::BUILD_LIST,2,l); break;
        }
        default: emit(Op::NOP,0,l); break;
        }
    }

    // ─── if ─────────────────────────────────────────────────────────────
    // NB: the branches below deliberately use visit(), not visit_stmt(). Nython
    // has no separate ternary node — `a if c else b` is also an IfNode — so
    // emitting POP_TOP here would discard the ternary's value. (It did: a dict
    // literal containing a ternary whose branch was a call came out with its
    // keys and values swapped.) The consequence is that a bare call as an
    // if-branch still leaves its result on the stack on the VM; fixing that
    // needs the parser to distinguish statement-ifs from ternaries first.
    void visit_if(std::shared_ptr<nython::node::IfNode> nd) {
        int l=ln(nd);
        visit(nd->condition);
        int jf=C().here(); emit(Op::JUMP_IF_FALSE,0,l);
        visit(nd->then_branch);
        std::vector<int> ends; ends.push_back(C().here());
        emit(Op::JUMP_FORWARD,0,l);
        C().patch(jf,C().here());
        for(auto& ei:nd->elseif_branches){
            auto eif=std::static_pointer_cast<nython::node::IfNode>(ei);
            visit(eif->condition);
            int jf2=C().here(); emit(Op::JUMP_IF_FALSE,0,l);
            visit(eif->then_branch);
            ends.push_back(C().here()); emit(Op::JUMP_FORWARD,0,l);
            C().patch(jf2,C().here());
        }
        if(nd->else_branch) visit(nd->else_branch);
        int end=C().here();
        for(int j:ends) C().patch(j,end);
    }

    // ─── while ──────────────────────────────────────────────────────────
    void visit_while(std::shared_ptr<nython::node::WhileNode> nd) {
        int l=ln(nd);
        int start=C().here();
        loops_.push_back({start,{},{},false});
        visit(nd->condition);
        int je=C().here(); emit(Op::JUMP_IF_FALSE,0,l);
        visit_stmt(nd->body);
        emit(Op::JUMP_ABSOLUTE,start,l);
        int end=C().here(); C().patch(je,end);
        patch_loop(start,end);
        loops_.pop_back();
        // while-else: condition failed (natural exit) → falls through to else
        // break → jumps to 'end', then needs to skip else
        if(nd->else_branch){
            visit_stmt(nd->else_branch);
            int else_end=C().here();
            // Re-patch break jumps: JUMP_ABSOLUTE to 'end' → jump to 'else_end'
            for(int i=start;i<end;i++){
                auto& ins=C().instructions[i];
                if(ins.op==Op::JUMP_ABSOLUTE&&ins.arg==end)
                    ins.arg=else_end;
            }
        }
    }

    // ─── for ────────────────────────────────────────────────────────────
    void visit_for(std::shared_ptr<nython::node::ForNode> nd) {
        int l=ln(nd);
        visit(nd->iterable); emit(Op::GET_ITER,0,l);
        int start=C().here();
        // visit_stmt, not visit: the parser yields a BARE expression node as the
        // body when the statement is a single expression (e.g. after a
        // multi-line list literal in the loop header), and only BLOCK bodies
        // reach visit_stmt's POP_TOP. Without it a call-as-body left its return
        // value on the stack every iteration; FOR_ITER reads stack_.back(), so
        // it then read that leftover instead of the iterator and the loop ran
        // exactly once — silently, with no error.
        loops_.push_back({start,{},{},true});
        int fi=C().here(); emit(Op::FOR_ITER,0,l);
        if(!nd->unpack_vars.empty()) {
            // for a, b, c in ...: FOR_ITER pushed [a_val, b_val,...]; unpack by index
            std::string tmp="__for_unpack__";
            emit_dn(tmp,l);
            // Assign first var (nd->var)
            int idx0=C().add_const(VMVal::make_int(0));
            emit_ln(tmp,l); emit(Op::LOAD_CONST,idx0,l); emit(Op::LOAD_SUBSCR,0,l);
            emit_sn(nd->var?nd->var->value():"_",l);
            // Assign rest (nd->unpack_vars)
            for(int ui=0;ui<(int)nd->unpack_vars.size();ui++){
                int ci=C().add_const(VMVal::make_int(ui+1));
                emit_ln(tmp,l); emit(Op::LOAD_CONST,ci,l); emit(Op::LOAD_SUBSCR,0,l);
                emit_sn(nd->unpack_vars[ui]->value(),l);
            }
        } else {
            emit_sn(nd->var?nd->var->value():"_",l);
        }
        visit_stmt(nd->body);
        emit(Op::JUMP_ABSOLUTE,start,l);
        int end=C().here(); C().patch(fi,end);
        patch_loop(start,end);
        loops_.pop_back();
        // for-else:
        // Natural exit (iterator exhausted) → FOR_ITER jumped to 'end' → falls to else block
        // Break → jumps to else_end (skips else)
        if(nd->else_branch){
            // Natural exit: FOR_ITER already jumps to 'end' (= current position = else_start)
            int else_start = end; // else_start == end, already patched by C().patch(fi,end)
            visit_stmt(nd->else_branch);
            int else_end = C().here();
            // Re-patch break jumps: change JUMP_ABSOLUTE to 'end' → jump to 'else_end' (skip else)
            for(int i=start; i<else_start; i++){
                auto& ins=C().instructions[i];
                if(ins.op==Op::JUMP_ABSOLUTE && ins.arg==end)
                    ins.arg=else_end;
            }
        }
    }

    void patch_loop(int start, int end) {
        for(int i=start;i<end;i++){
            auto& ins=C().instructions[i];
            if(ins.op==Op::JUMP_ABSOLUTE){
                if(ins.arg==-9991) ins.arg=end;
                if(ins.arg==-9992) ins.arg=start;
            }
        }
    }

    // ─── function ───────────────────────────────────────────────────────
    void visit_func(std::shared_ptr<nython::node::FunctionNode> fn) {
        int l=ln(fn);
        push_code(fn->name);
        C().is_method=!fn->params.empty()&&fn->params[0]->value()=="self";
        int param_idx=0;
        for(int i=0;i<(int)fn->params.size();i++){
            std::string pn=fn->params[i]->value(); if(pn=="self") continue;
            C().param_names.push_back(pn); C().add_name(pn);
            // Defaults used to be left UNDEFINED here and filled in at runtime by
            // MAKE_FUNCTION. Class methods never go through MAKE_FUNCTION — they
            // are invoked straight out of sub_codes — so every method default was
            // silently dropped and the parameter arrived as none. A constructor
            // like __init__(self, x_or_w, y=0, w=0, h=0) then took the wrong
            // branch of `if w == 0`, building a wrong object with no error.
            // Literal defaults are therefore folded at compile time, which covers
            // the common cases; non-literal defaults still fall back to the
            // MAKE_FUNCTION path for plain functions.
            VMVal dflt{VMType::UNDEFINED};
            if(i<(int)fn->defaults.size()&&fn->defaults[i]){
                auto& dn=fn->defaults[i];
                switch(dn->type()){
                    case NT::INTEGER: dflt=VMVal::make_int(std::stoll(dn->token().value)); break;
                    case NT::FLOAT:   dflt=VMVal::make_float(std::stod(dn->token().value)); break;
                    case NT::STRING:  dflt=VMVal::make_str(dn->token().value); break;
                    case NT::TRUE:    dflt=VMVal::make_bool(true); break;
                    case NT::FALSE:   dflt=VMVal::make_bool(false); break;
                    case NT::NONE:    dflt=VMVal::make_none(); break;
                    default: break;
                }
            }
            C().param_defaults.push_back(dflt);
            param_idx++;
        }
        // Emit default-filling prologue: for each param with default, if not supplied
        // We use a different approach: emit assignments at top of function body
        for(int i=0;i<(int)fn->params.size();i++){
            std::string pn=fn->params[i]->value(); if(pn=="self") continue;
            if(i<(int)fn->defaults.size()&&fn->defaults[i]){
                // Emit: if param is UNDEFINED/not set, assign default
                // We encode this as: LOAD_NAME pn, JUMP_IF_DEFINED skip, <default>, STORE_NAME pn, skip:
                // Simplest: emit LOAD_NAME, check UNDEFINED, if so set default
                // Use a special CHECK_DEFAULT opcode or just emit conditional at start
                // Actually emit: LOAD_CONST undefined → if LOAD_NAME is NONE?
                // Simplest approach: just emit the default assignment in a prologue
                // using a special "HAS_ARG" check. We'll use LOAD_NAME + COMPARE:
                // Actually SIMPLEST: emit at top of function:
                //   if name == None: name = default_expr
                // But "None" is a valid value. Better: use LOAD_LOCAL_OR_DEFAULT opcode.
                // HACK: emit instructions that check if local is UNDEFINED by trying to load
                // We can't easily check UNDEFINED in current ops. Let's use a different way:
                // Emit at top: LOAD_CONST <default_val>, STORE_DEFAULT pn
                // where STORE_DEFAULT only assigns if pn is not already set.
                // 
                // SIMPLEST CORRECT approach: store default VMVals in VMCode.param_defaults
                // and in exec_code, apply them when args.size() < param_names.size().
                // For this we need to EVALUATE the default at compile time... but defaults
                // can be expressions. Let's just handle literal defaults:
                // For now, emit NO code (handled in exec_code by pre-evaluating defaults)
                // We store the default AST node in VMCode... but VMCode is a runtime struct.
                // 
                // BEST APPROACH: Emit default value as a constant and store in VMCode.
                // Evaluate simple literal defaults to VMVal during compilation:
                // Visit the default AST node to compile it, but we need the VALUE not code.
                // Use a "constant folding" trick: for simple literals.
            }
        }
        if(fn->body) visit(fn->body);
        emit_lc(VMVal::make_none(),l); emit(Op::RETURN_VALUE,0,l);
        // Now store defaults: compile each default expr and store result
        // We can't easily do this at compile time for non-literal defaults.
        // Store default AST nodes → evaluate at MAKE_FUNCTION time (runtime).
        auto& sub=C().sub_codes.back(); // last pushed sub_code
        pop_code();
        int idx=(int)C().sub_codes.size()-1;
        // Compile defaults: emit instructions to evaluate each default, 
        // collect them at MAKE_FUNCTION time using a separate "defaults code"
        // For now: use a simpler approach - emit them into the parent context
        // and have MAKE_FUNCTION pop N defaults from stack.
        int n_defaults=0;
        for(int i=0;i<(int)fn->defaults.size();i++){
            if(fn->defaults[i]){ visit(fn->defaults[i]); n_defaults++; }
        }
        // MAKE_FUNCTION arg = idx | (n_defaults << 16)
        emit(Op::MAKE_FUNCTION, idx|(n_defaults<<16), l);
        emit_dn(fn->name,l);
    }

    // ─── class ──────────────────────────────────────────────────────────
    void visit_class(std::shared_ptr<nython::node::ClassNode> cn) {
        int l=ln(cn);
        push_code(cn->name,true);
        code_->is_class=true;  // mark this sub_code as a class
        if(!cn->bases.empty()){
            auto base=std::static_pointer_cast<nython::node::VariableNode>(cn->bases[0]);
            code_->parent_class=base->token().value;
        }
        if(cn->body) for(auto& s:cn->body->statements()) visit(s);
        emit(Op::HALT,0,l);
        pop_code();
        int idx=(int)C().sub_codes.size()-1;
        emit(Op::MAKE_CLASS,idx,l); emit_dn(cn->name,l);
    }

    // ─── call ───────────────────────────────────────────────────────────
    void visit_call(std::shared_ptr<nython::node::CallNode> cn) {
        int l=ln(cn);
        // Separate positional from keyword args (AssignmentNode = keyword arg)
        std::vector<np> pos_args, kw_vals;
        std::vector<std::string> kw_names;
        bool has_star=false;
        for(auto& arg:cn->args){
            // The parser represents `f(x=1)` as a KeywordArgNode, not an
            // AssignmentNode. Matching only ASSIGNMENT meant every keyword
            // argument fell through to the positional branch, where visit()
            // emitted a NOP for it while argc still counted it — so
            // CALL_FUNCTION popped one item too many and took the callee as an
            // argument. Keyword arguments therefore never worked in the VM:
            // f(1, key=2) crashed on an operand-stack underflow.
            if(arg->type()==NT::KEYWORD_ARG){
                auto kn=std::static_pointer_cast<nython::node::KeywordArgNode>(arg);
                kw_names.push_back(kn->name);
                kw_vals.push_back(kn->val);
            } else if(arg->type()==NT::ASSIGNMENT){
                auto an=std::static_pointer_cast<nython::node::AssignmentNode>(arg);
                kw_names.push_back(an->target ? an->target->token().value : std::string());
                kw_vals.push_back(an->value_node);
            } else {
                if(arg->type()==NT::UNARY){
                    auto u=std::static_pointer_cast<nython::node::UnaryNode>(arg);
                    if(u->op=="*") has_star=true;
                }
                pos_args.push_back(arg);
            }
        }
        bool has_kw=!kw_names.empty();
        int argc=(int)pos_args.size();
        // ── *args spread call: fn(*list) ─────────────────────────────────
        if(has_star){
            // Build a combined positional args list:
            // emit [] then for each arg: if *x → LIST_EXTEND, else push x + LIST_APPEND
            if(cn->callee->type()==NT::ATTRIBUTE){
                auto a=std::static_pointer_cast<nython::node::AttributeNode>(cn->callee);
                visit(a->object); emit_lc(VMVal::make_str(a->attr),l);
                emit(Op::BUILD_LIST,0,l); // fresh empty list per call (not a constant!)
                for(auto& arg:pos_args){
                    if(arg->type()==NT::UNARY){
                        auto u=std::static_pointer_cast<nython::node::UnaryNode>(arg);
                        if(u->op=="*"){ visit(u->operand); emit(Op::LIST_EXTEND,0,l); continue; }
                    }
                    visit(arg); emit(Op::LIST_APPEND,0,l);
                }
                emit(Op::CALL_EX,-1,l); // method mode, 1 combined list arg
            } else {
                visit(cn->callee);
                emit(Op::BUILD_LIST,0,l); // fresh empty list per call (not a constant!)
                for(auto& arg:pos_args){
                    if(arg->type()==NT::UNARY){
                        auto u=std::static_pointer_cast<nython::node::UnaryNode>(arg);
                        if(u->op=="*"){ visit(u->operand); emit(Op::LIST_EXTEND,0,l); continue; }
                    }
                    visit(arg); emit(Op::LIST_APPEND,0,l);
                }
                emit(Op::CALL_EX,1,l); // 1 combined list arg
            }
            return;
        }
        if(cn->callee->type()==NT::ATTRIBUTE){
            auto a=std::static_pointer_cast<nython::node::AttributeNode>(cn->callee);
            visit(a->object); emit_lc(VMVal::make_str(a->attr),l);
            for(auto& arg:pos_args) visit(arg);
            if(has_kw){
                for(size_t i=0;i<kw_names.size();i++){
                    emit_lc(VMVal::make_str(kw_names[i]),l); visit(kw_vals[i]);
                }
                emit(Op::BUILD_MAP,(int)kw_names.size(),l);
                emit(Op::CALL_KW,argc+1,l);
            } else emit(Op::CALL_METHOD,argc,l);
        } else {
            visit(cn->callee);
            for(auto& arg:pos_args) visit(arg);
            if(has_kw){
                for(size_t i=0;i<kw_names.size();i++){
                    emit_lc(VMVal::make_str(kw_names[i]),l); visit(kw_vals[i]);
                }
                emit(Op::BUILD_MAP,(int)kw_names.size(),l);
                emit(Op::CALL_KW,argc+1,l);
            } else emit(Op::CALL_FUNCTION,argc,l);
        }
    }

    // ─── load target value (for augmented assignment) ──────────────────────────
    void load_target(np tgt, int l) {
        if(tgt->type()==NT::VARIABLE) {
            emit_ln(tgt->token().value,l);
        } else if(tgt->type()==NT::ATTRIBUTE) {
            auto a=std::static_pointer_cast<nython::node::AttributeNode>(tgt);
            visit(a->object); emit(Op::LOAD_ATTR,C().add_name(a->attr),l);
        } else if(tgt->type()==NT::SUBSCRIPT) {
            auto s=std::static_pointer_cast<nython::node::SubscriptNode>(tgt);
            visit(s->object); visit(s->index); emit(Op::LOAD_SUBSCR,0,l);
        }
    }

    // ─── store target ───────────────────────────────────────────────────
    void store(np tgt, int l) {
        if(tgt->type()==NT::VARIABLE) {
            emit_sn(tgt->token().value,l);
        } else if(tgt->type()==NT::ATTRIBUTE) {
            auto a=std::static_pointer_cast<nython::node::AttributeNode>(tgt);
            visit(a->object); emit(Op::STORE_ATTR,C().add_name(a->attr),l);
        } else if(tgt->type()==NT::SUBSCRIPT) {
            auto s=std::static_pointer_cast<nython::node::SubscriptNode>(tgt);
            visit(s->object); visit(s->index); emit(Op::STORE_SUBSCR,0,l);
        } else if(tgt->type()==NT::CALL) {
            // Should be handled in ASSIGNMENT case above, but fallback: pop
            emit(Op::POP_TOP,0,l);
        }
    }

    // ─── opcode maps ────────────────────────────────────────────────────
    static Op bin_op(const std::string& op) {
        if(op=="+"||op=="concat") return Op::BINARY_ADD;
        if(op=="-")  return Op::BINARY_SUB;
        if(op=="*")  return Op::BINARY_MUL;
        if(op=="/")  return Op::BINARY_DIV;
        if(op=="%")  return Op::BINARY_MOD;
        if(op=="**"||op=="pow") return Op::BINARY_POW;
        if(op=="\\"||op=="//")  return Op::BINARY_FLOOR_DIV;
        if(op=="&")  return Op::BINARY_AND;
        if(op=="|")  return Op::BINARY_OR;
        if(op=="^")  return Op::BINARY_XOR;
        if(op=="<<"||op=="lshift") return Op::BINARY_LSHIFT;
        if(op==">>"||op=="rshift") return Op::BINARY_RSHIFT;
        if(op=="==") return Op::COMPARE_EQ;
        if(op=="!="||op=="<>") return Op::COMPARE_NE;
        if(op=="<")  return Op::COMPARE_LT;
        if(op=="<=") return Op::COMPARE_LE;
        if(op==">")  return Op::COMPARE_GT;
        if(op==">=") return Op::COMPARE_GE;
        if(op=="in") return Op::COMPARE_IN;
        if(op=="not in") return Op::COMPARE_NOT_IN;
        if(op=="is") return Op::COMPARE_IS;
        if(op=="is not") return Op::COMPARE_IS_NOT;
        return Op::NOP;
    }
    static Op aug_op(const std::string& op) {
        if(op=="+=") return Op::IADD;
        if(op=="-=") return Op::ISUB;
        if(op=="*=") return Op::IMUL;
        if(op=="/=") return Op::BINARY_DIV;
        if(op=="%=") return Op::BINARY_MOD;
        // These fell through to NOP, which the ASSIGNMENT_AUG case treats as
        // "combine target and new value" - with no combining opcode emitted,
        // the target was just silently replaced by the right-hand operand
        // (x=24; x//=5 left x==5, the unmodified operand, instead of 4).
        if(op=="//=") return Op::BINARY_FLOOR_DIV;
        if(op=="**=") return Op::BINARY_POW;
        if(op=="&=") return Op::BINARY_AND;
        if(op=="|=") return Op::BINARY_OR;
        if(op=="^=") return Op::BINARY_XOR;
        if(op=="<<=") return Op::BINARY_LSHIFT;
        if(op==">>=") return Op::BINARY_RSHIFT;
        return Op::NOP;
    }
};


// ═══════════════════════════════════════════════════════════════════════════
// CALLFRAME
// ═══════════════════════════════════════════════════════════════════════════

struct GenState {
    std::shared_ptr<VMCode> code;
    size_t ip=0;
    std::unordered_map<std::string,VMVal> locals;
    std::optional<VMVal> self_val;
    std::shared_ptr<std::unordered_map<std::string,VMVal>> closure;
    bool done=false;
    std::vector<VMVal> saved_stack; // intermediate stack at yield point
    size_t stack_base=0;           // stack level when generator was entered
};


inline VMVal make_generator_val(std::shared_ptr<VMCode> code,
                            std::vector<VMVal> args,
                            std::optional<VMVal> self,
                            std::shared_ptr<std::unordered_map<std::string,VMVal>> closure=nullptr) {
    VMVal g; g.type=VMType::GENERATOR;
    g.gen=std::make_shared<GenState>();
    g.gen->code=code; g.gen->ip=0; g.gen->self_val=self; g.gen->closure=closure;
    int n=(int)code->param_names.size();
    int arg_idx=0;
    for(int i=0;i<n;i++){
        const std::string& pn=code->param_names[i];
        if(pn.size()>=2&&pn[0]=='*'&&pn[1]=='*'){
            // **kwargs: build map from remaining args (simplified)
            g.gen->locals[pn.substr(2)]=args.size()>(size_t)arg_idx?args[arg_idx]:VMVal::make_map();
            arg_idx=(int)args.size();
        } else if(!pn.empty()&&pn[0]=='*'){
            // *args: collect ALL remaining positional args into a list
            std::vector<VMVal> rest(args.begin()+arg_idx, args.end());
            g.gen->locals[pn.substr(1)]=VMVal::make_list(std::move(rest));
            arg_idx=(int)args.size();
        } else if(arg_idx<(int)args.size()){
            g.gen->locals[pn]=args[arg_idx++];
        } else if(!code->param_defaults.empty()&&i<(int)code->param_defaults.size()
                  &&code->param_defaults[i].type!=VMType::UNDEFINED){
            g.gen->locals[pn]=code->param_defaults[i];
        }
    }
    g.gen->done=false;
    return g;
}

struct CallFrame {
    std::shared_ptr<VMCode>                       code;
    int                                           ip = 0;
    std::unordered_map<std::string,VMVal>         locals;
    std::optional<VMVal>                          self_val;
    // Shared closure environment (shared with enclosing scope)
    std::shared_ptr<std::unordered_map<std::string,VMVal>> closure_env;

    bool has_local(const std::string& n) const {
        if(locals.count(n)) return true;
        if(closure_env && closure_env->count(n)) return true;
        return false;
    }
    VMVal get_local(const std::string& n) const {
        auto it=locals.find(n);
        if(it!=locals.end()) return it->second;
        if(closure_env){ auto it2=closure_env->find(n); if(it2!=closure_env->end()) return it2->second; }
        // Return undefined to signal not found
        VMVal undef; undef.type=VMType::UNDEFINED; return undef;
    }
    VMVal& local(const std::string& n)           { return locals[n]; }
    void   set(const std::string& n, VMVal v)    {
        // If var exists in closure_env (and is NOT a local param), update closure_env
        if(closure_env && closure_env->count(n) && !locals.count(n)){
            (*closure_env)[n]=std::move(v);
        } else {
            locals[n]=std::move(v);
        }
    }
    void define(const std::string& n, VMVal v) { locals[n]=std::move(v); }
    std::shared_ptr<GenState>  gen_state;   // non-null when executing a generator
};

struct VMReturn   { VMVal value; };
struct VMYield    { VMVal value; };
enum   class VMResult { SUCCESS, COMPILE_ERROR, RUNTIME_ERROR };

// ═══════════════════════════════════════════════════════════════════════════
// VIRTUAL MACHINE
// ═══════════════════════════════════════════════════════════════════════════
class VirtualMachine : public Runnable {
    friend class gc::GarbageCollector;
    using gc_ptr = std::shared_ptr<GarbageCollector>;

    gc_ptr                                             gc_;
    std::vector<VMVal>                                 stack_;
    // deque, not vector: run_loop() holds `CallFrame& fr = call_stack_.back()`
    // for the duration of an instruction, and several opcodes (CALL_KW, and any
    // path reaching exec_code_bound) push a frame while that reference is live.
    // A vector reallocates on growth, leaving `fr` dangling — which showed up as
    // a segfault on any keyword-argument call, e.g. g(1, key=2) or
    // sorted(xs, key=...). deque::push_back does not invalidate references to
    // existing elements.
    std::deque<CallFrame>                              call_stack_;
    std::unordered_map<std::string,VMVal>              globals_;
    std::unordered_map<std::string,std::shared_ptr<VMCode>> class_reg_;
    std::unordered_map<std::string,std::unordered_map<std::string,VMVal>> class_vars_;
    VMVal last_exception_obj_;
    bool vm_trace_ = getenv("NY_VM_TRACE") != nullptr;
    bool export_to_globals_ = false;   // true while executing an import
    std::string cwd_ = ".";            // working directory for imports

    // Stack helpers
    void   push(VMVal v)       { stack_.push_back(std::move(v)); }
    // Guarded: popping an empty operand stack was undefined behaviour and
    // crashed the process. A stack imbalance is a compiler/opcode bug, but it
    // should surface as a diagnosable error rather than a segfault.
    VMVal  pop() {
        if(stack_.empty()){
            if(getenv("NY_VM_TRACE")) fprintf(stderr,"[vm] operand stack underflow\n");
            return VMVal::make_none();
        }
        VMVal v=std::move(stack_.back()); stack_.pop_back(); return v;
    }
    VMVal& peek(int off=0) {
        static VMVal s_none = VMVal::make_none();
        if(off < 0 || (size_t)off >= stack_.size()) return s_none;
        return stack_[stack_.size()-1-off];
    }

    // Variable resolution
    // ── Interpreter builtin bridge ──────────────────────────────────────────
    // The VM implements about 64 builtins of its own; the interpreter registers
    // 536. Everything else silently evaluated to none here, so most of the
    // standard library was simply unreachable from a program run with --vm.
    //
    // These hooks are installed from main.cpp, where both VMVal and the
    // interpreter's Value are complete types (VirtualMachine.hpp is included by
    // NythonExecutor.hpp, so this header cannot name Value directly).
public:
    static std::function<bool(const std::string&)>& bridge_exists() {
        static std::function<bool(const std::string&)> f; return f;
    }
    static std::function<VMVal(const std::string&, std::vector<VMVal>&)>& bridge_call() {
        static std::function<VMVal(const std::string&, std::vector<VMVal>&)> f; return f;
    }

private:
    VMVal load_var(const std::string& n) {
        for(int i=(int)call_stack_.size()-1;i>=0;i--){
            auto v=call_stack_[i].get_local(n);
            if(v.type!=VMType::UNDEFINED) return v;
        }
        auto it=globals_.find(n);
        if(it!=globals_.end()) return it->second;
        // Fall back to an interpreter builtin of this name, wrapped as a native.
        // Only names the interpreter actually registers are wrapped, so an
        // undefined variable still reads as none rather than becoming callable.
        if(bridge_exists() && bridge_exists()(n)){
            std::string nm=n;
            return VMVal::make_native([nm](std::vector<VMVal>& a)->VMVal{
                if(bridge_call()) return bridge_call()(nm,a);
                return VMVal::make_none();
            });
        }
        return VMVal::make_none();
    }
    void store_var(const std::string& n, VMVal v) {
        // Walk frames: if found in locals or closure_env, update there
        for(int i=(int)call_stack_.size()-1;i>=0;i--){
            if(call_stack_[i].locals.count(n)){
                call_stack_[i].locals[n]=std::move(v); return;
            }
            if(call_stack_[i].closure_env && call_stack_[i].closure_env->count(n)){
                (*call_stack_[i].closure_env)[n]=std::move(v); return;
            }
        }
        if(!call_stack_.empty()) call_stack_.back().locals[n]=std::move(v);
        else globals_[n]=std::move(v);
    }
    void define_var(const std::string& n, VMVal v) {
        if(export_to_globals_) { globals_[n]=std::move(v); return; }
        if(!call_stack_.empty()) call_stack_.back().set(n,std::move(v));
        else globals_[n]=std::move(v);
    }

public:
    void register_builtin(const std::string& name, NativeFunc fn) {
        globals_[name]=VMVal::make_native(std::move(fn));
    }
    void set_cwd(const std::string& d) { cwd_=d; }
    // Directory of the script being run, with a trailing separator, so imports
    // resolve relative to the file rather than to the working directory.
    void set_script_dir(const std::string& f) {
        size_t cut = f.find_last_of("/\\");
        script_dir_ = (cut==std::string::npos) ? std::string() : f.substr(0,cut+1);
    }
    std::string script_dir_;
    const std::string& get_cwd() const { return cwd_; }

    explicit VirtualMachine(Reporter* r=nullptr)
        : Runnable(r, RunnableType::COMPILER)
        , gc_(std::make_shared<GarbageCollector>(GarbageCollectorConfig{},this))
    { register_all_builtins(); }
    explicit VirtualMachine(Runnable* r)
        : Runnable((Reporter*)r, RunnableType::COMPILER)
        , gc_(std::make_shared<GarbageCollector>(GarbageCollectorConfig{},this))
    { register_all_builtins(); }

    // 171 general-purpose builtins (map, filter, reduce, any, all, next, set,
    // tuple, getattr, exp, log, sin, read_file, mkdir, ...) were only ever
    // registered by register_nytorch_builtins(), which runs on `import nytorch`
    // and nowhere else — so without that import they resolved to none on the VM
    // while working fine on the interpreter. They are registered first so that
    // the 11 names both blocks define keep register_builtins()' versions, which
    // is the behaviour the parity tests were written against.
    void register_all_builtins() {
        register_nytorch_builtins();
        register_builtins();
    }

    ~VirtualMachine() override = default;

    // Compile + run an AST
    VMResult run(nython::node::node_ptr ast) {
        try {
            Compiler c; auto code=c.compile(ast);
            exec_code(code,{},std::nullopt);
            return VMResult::SUCCESS;
        } catch(std::exception& e) {
            std::cerr<<"\x1b[31m[VMError] "<<e.what()<<"\x1b[0m\n";
            return VMResult::RUNTIME_ERROR;
        }
    }

    // Compile only
    std::shared_ptr<VMCode> compile_ast(nython::node::node_ptr ast) {
        Compiler c; return c.compile(ast);
    }

    // Disassemble to string
    std::string disassemble(const VMCode& code, int depth=0) const {
        std::ostringstream oss;
        std::string ind(depth*2,' ');
        oss<<ind<<"=== "<<code.name<<" ===\n";
        oss<<ind<<"  Constants:\n";
        for(int i=0;i<(int)code.constants.size();i++)
            oss<<ind<<"    ["<<i<<"] "<<code.constants[i].repr()<<"\n";
        oss<<ind<<"  Names: ";
        for(int i=0;i<(int)code.names.size();i++){if(i)oss<<", ";oss<<i<<":"<<code.names[i];}
        oss<<"\n"<<ind<<"  Instructions:\n";
        for(int i=0;i<(int)code.instructions.size();i++){
            const auto& ins=code.instructions[i];
            oss<<ind<<"    "<<std::setw(4)<<i<<"  "<<std::left<<std::setw(24)<<op_name(ins.op)<<ins.arg;
            if(ins.op==Op::LOAD_CONST&&ins.arg<(int)code.constants.size())
                oss<<"  ("<<code.constants[ins.arg].repr()<<")";
            else if((ins.op==Op::LOAD_NAME||ins.op==Op::STORE_NAME||
                     ins.op==Op::DEFINE_NAME||ins.op==Op::LOAD_ATTR||
                     ins.op==Op::STORE_ATTR||ins.op==Op::IMPORT_NAME)
                     &&ins.arg<(int)code.names.size())
                oss<<"  ("<<code.names[ins.arg]<<")";
            if(ins.line) oss<<"  ; line "<<ins.line;
            oss<<"\n";
        }
        for(auto& sub:code.sub_codes) oss<<"\n"<<disassemble(*sub,depth+1);
        return oss.str();
    }

    template<typename T> T* create() {
        auto cell=gc_->allocate(); T* o=new T(this); cell->value=o; return o;
    }
    template<typename T, typename First, typename... Args>
    T* create(First&& first, Args&&... args) {
        auto cell=gc_->allocate();
        T* o=new T(this, std::forward<First>(first), std::forward<Args>(args)...);
        cell->value=o; return o;
    }

private:
    // ── Execute a VMCode object ──────────────────────────────────────────
    // ── UTF-8 index helpers ─────────────────────────────────────────────────
    // The VM measured strings in bytes throughout, while the interpreter's len()
    // counted characters. Non-ASCII text therefore behaved differently on the
    // two engines, and a slice could cut mid-character and emit invalid UTF-8.
    static inline bool u8_cont(unsigned char c){ return (c & 0xC0) == 0x80; }
    static size_t u8_chars(const std::string& s){
        size_t n=0; for(unsigned char c : s) if(!u8_cont(c)) n++; return n;
    }
    static size_t u8_byte_at(const std::string& s, size_t ci){
        size_t chars=0;
        for(size_t i=0;i<s.size();i++){
            if(!u8_cont((unsigned char)s[i])){ if(chars==ci) return i; chars++; }
        }
        return s.size();
    }
    static size_t u8_char_at(const std::string& s, size_t bi){
        size_t chars=0;
        for(size_t i=0;i<s.size() && i<bi;i++) if(!u8_cont((unsigned char)s[i])) chars++;
        return chars;
    }

    VMVal exec_code_bound(std::shared_ptr<VMCode> code,
                          std::unordered_map<std::string,VMVal> locs,
                          std::optional<VMVal> self,
                          std::shared_ptr<std::unordered_map<std::string,VMVal>> closure=nullptr) {
        CallFrame fr; fr.code=code; fr.ip=0;
        if(self) fr.self_val=self;
        fr.closure_env=closure;
        fr.locals=std::move(locs);
        call_stack_.push_back(std::move(fr));
        VMVal result=VMVal::make_none();
        try { result=run_loop(); }
        catch(VMReturn& r){ result=r.value; }
        catch(...){ call_stack_.pop_back(); throw; }
        call_stack_.pop_back();
        return result;
    }
    VMVal exec_code(std::shared_ptr<VMCode> code,
                    std::vector<VMVal> args,
                    std::optional<VMVal> self,
                    std::shared_ptr<std::unordered_map<std::string,VMVal>> closure=nullptr) {
        size_t _stack_base=stack_.size();
        CallFrame fr; fr.code=code; fr.ip=0;
        if(self) fr.self_val=self;
        // Store closure env in frame (shared reference, not copy)
        fr.closure_env = closure;
        // Parameters go into locals; apply defaults and *args
        int n_params=(int)code->param_names.size();
        int arg_idx=0;
        for(int i=0;i<n_params;i++){
            const std::string& pn=code->param_names[i];
            if(!pn.empty()&&pn[0]=='*'){
                // *args: collect all remaining positional args into a list
                std::string vararg_name=pn.substr(1); // strip *
                std::vector<VMVal> rest(args.begin()+arg_idx,args.end());
                fr.define(vararg_name, VMVal::make_list(std::move(rest)));
                arg_idx=(int)args.size(); // consumed all
            } else if(arg_idx<(int)args.size()){
                fr.define(pn, args[arg_idx++]);
            } else if(!code->param_defaults.empty()&&i<(int)code->param_defaults.size()
                      &&code->param_defaults[i].type!=VMType::UNDEFINED){
                fr.define(pn, code->param_defaults[i]);
            }
        }
        call_stack_.push_back(std::move(fr));
        VMVal result=VMVal::make_none();
        try { result=run_loop(); }
        catch(VMReturn& r){ result=r.value; }
        catch(...){ call_stack_.pop_back(); if(stack_.size()>_stack_base) stack_.resize(_stack_base); throw; }
        call_stack_.pop_back();
        if(stack_.size()>_stack_base) stack_.resize(_stack_base);
        return result;
    }

    // ── Main dispatch loop ───────────────────────────────────────────────
    // Resume a generator; returns {value, done} as VMVal (NONE if done)
    VMVal gen_next(VMVal& gv) {
        if(gv.type!=VMType::GENERATOR||!gv.gen||gv.gen->done) return VMVal::make_none();
        auto& gs=*gv.gen;
        // Restore saved stack (iterators held across yields)
        gs.stack_base = stack_.size();
        for(auto& sv : gs.saved_stack) stack_.push_back(sv);
        gs.saved_stack.clear();
        CallFrame fr; fr.code=gs.code; fr.ip=gs.ip;
        fr.locals=gs.locals;
        fr.self_val=gs.self_val;
        fr.closure_env=gs.closure;
        fr.gen_state=gv.gen;
        call_stack_.push_back(std::move(fr));
        VMVal result=VMVal::make_none();
        try {
            run_loop();
            // Generator function returned without yield → done
            gs.done=true;
            // Clean up any remaining stack from generator
            if(stack_.size() > gs.stack_base) stack_.resize(gs.stack_base);
        } catch(VMYield& y) {
            result=y.value;
            // Stack state was already saved in YIELD_VALUE handler
        } catch(VMReturn& r) {
            gs.done=true; result=r.value;
            if(stack_.size() > gs.stack_base) stack_.resize(gs.stack_base);
        } catch(...) {
            if(!call_stack_.empty()) call_stack_.pop_back();
            gs.done=true;
            if(stack_.size() > gs.stack_base) stack_.resize(gs.stack_base);
            throw;
        }
        if(!call_stack_.empty()) call_stack_.pop_back();
        return result;
    }

    static int cmp_val(const VMVal& a, const VMVal& b) {
        if(a.type==VMType::INT&&b.type==VMType::INT) return a.i<b.i?-1:(a.i>b.i?1:0);
        if((a.type==VMType::INT||a.type==VMType::FLOAT)&&
           (b.type==VMType::INT||b.type==VMType::FLOAT)){
            double da=(a.type==VMType::FLOAT)?a.d:(double)a.i;
            double db=(b.type==VMType::FLOAT)?b.d:(double)b.i;
            return da<db?-1:(da>db?1:0);
        }
        if(a.type==VMType::STRING&&b.type==VMType::STRING)
            return a.s<b.s?-1:(a.s>b.s?1:0);
        return a.to_string()<b.to_string()?-1:(a.to_string()>b.to_string()?1:0);
    }

        VMVal call_dunder(const VMVal& obj, const std::string& dunder, std::vector<VMVal> args) {
        if(obj.type!=VMType::INSTANCE) return VMVal::make_none();
        std::string cls=obj.class_name;
        while(!cls.empty()){
            auto cit=class_reg_.find(cls);
            if(cit==class_reg_.end()) break;
            for(auto& sub:cit->second->sub_codes)
                if(sub->name==dunder&&!sub->is_class){
                    // Generator method (has yield) → return lazy generator
                    if(sub->has_yield())
                        return make_generator_val(sub, args, obj);
                    return exec_code(sub,args,obj);
                }
            cls=cit->second->parent_class;
        }
        return VMVal::make_none();
    }
    bool instance_truthy(VMVal& v) {
        VMVal r = call_dunder(v, "__bool__", {});
        if(r.type != VMType::NONE) return r.is_truthy();
        VMVal lr = call_dunder(v, "__len__", {});
        if(lr.type != VMType::NONE) return lr.i != 0;
        return true; // default: instances are truthy
    }

        VMVal run_loop() {
        while(true){
            CallFrame& fr=call_stack_.back();
            if(fr.ip>=(int)fr.code->instructions.size()) return VMVal::make_none();
            const Instruction& ins=fr.code->instructions[fr.ip++];
            if(vm_trace_) fprintf(stderr,"[vm] op=%d arg=%d depth=%d\n",(int)ins.op,ins.arg,(int)stack_.size());
            try {
            switch(ins.op){

            case Op::NOP: break;
            case Op::HALT: return VMVal::make_none();

            case Op::LOAD_CONST:  push(fr.code->constants[ins.arg]); break;
            case Op::LOAD_NAME:   push(load_var(fr.code->names[ins.arg])); break;
            case Op::STORE_NAME: {
                if(export_to_globals_&&!call_stack_.empty()&&call_stack_.size()==1)
                    globals_[fr.code->names[ins.arg]]=pop();
                else {
                    VMVal sv=pop();
                    store_var(fr.code->names[ins.arg], sv);
                    // Also sync to shared closure_env so inner functions see update
                    if(fr.closure_env && fr.closure_env->count(fr.code->names[ins.arg]))
                        (*fr.closure_env)[fr.code->names[ins.arg]] = sv;
                }
                break;
            }
            case Op::DEFINE_NAME: {
                VMVal dv=pop();
                define_var(fr.code->names[ins.arg], dv);
                // Sync to shared closure_env if it exists
                if(fr.closure_env)
                    (*fr.closure_env)[fr.code->names[ins.arg]] = dv;
                break;
            }
            case Op::LOAD_SELF:   push(fr.self_val.value_or(VMVal::make_none())); break;

            case Op::LOAD_SUPER: {
                // Push a SUPER_PROXY: find parent of the DEFINING class (owner_class),
                // not self's runtime class (which would break chained super() calls)
                VMVal self_v = fr.self_val.value_or(VMVal::make_none());
                std::string cur_cls = fr.code->owner_class.empty() ? self_v.class_name : fr.code->owner_class;
                std::string parent_cls;
                if(!cur_cls.empty()){
                    auto it=class_reg_.find(cur_cls);
                    if(it!=class_reg_.end()&&it->second&&!it->second->parent_class.empty())
                        parent_cls=it->second->parent_class;
                }
                VMVal proxy;
                proxy.type=VMType::SUPER_PROXY;
                proxy.s=parent_cls.empty()?cur_cls:parent_cls;
                proxy.list=std::make_shared<std::vector<VMVal>>();
                proxy.list->push_back(self_v);
                push(proxy);
                break;
            }

            case Op::LOAD_ATTR: {
                VMVal obj=pop(); push(get_attr(obj,fr.code->names[ins.arg])); break;
            }
            case Op::STORE_ATTR: {
                VMVal obj=pop(); VMVal val=pop();
                set_attr(obj,fr.code->names[ins.arg],std::move(val)); break;
            }
            case Op::LOAD_SUBSCR: {
                VMVal idx=pop(),obj=pop();
                if(obj.type==VMType::INSTANCE){VMVal res=call_dunder(obj,"__getitem__",{idx});if(res.type!=VMType::NONE){push(res);break;}}
                push(get_sub(obj,idx)); break;
            }
            case Op::STORE_SUBSCR:{
                VMVal idx=pop(),obj=pop(),val=pop();
                if(obj.type==VMType::INSTANCE){VMVal res=call_dunder(obj,"__setitem__",{idx,val});if(res.type!=VMType::NONE) break;}
                set_sub(obj,idx,std::move(val)); break;
            }
            case Op::DELETE_SUBSCR: {
                VMVal key=pop(), obj=pop();
                if((obj.type==VMType::MAP||obj.type==VMType::INSTANCE)&&obj.map)
                    obj.map->erase(key.to_string());
                else if(obj.type==VMType::LIST&&obj.list){
                    int i=(int)to_d(key);
                    if(i<0) i+=(int)obj.list->size();
                    if(i>=0&&i<(int)obj.list->size())
                        obj.list->erase(obj.list->begin()+i);
                }
                break;
            }
            case Op::DELETE_ATTR: {
                VMVal obj=pop();
                if((obj.type==VMType::MAP||obj.type==VMType::INSTANCE)&&obj.map)
                    obj.map->erase(fr.code->names[ins.arg]);
                break;
            }

            case Op::BUILD_LIST: {
                int n=ins.arg; std::vector<VMVal> items(n);
                for(int i=n-1;i>=0;i--) items[i]=pop();
                push(VMVal::make_list(std::move(items))); break;
            }
            case Op::BUILD_MAP: {
                int n=ins.arg;
                std::vector<std::pair<VMVal,VMVal>> pairs(n);
                for(int i=n-1;i>=0;i--){pairs[i].second=pop();pairs[i].first=pop();}
                auto m=VMVal::make_map();
                for(auto&[k,v]:pairs) (*m.map)[k.to_string()]=std::move(v);
                push(std::move(m)); break;
            }

            case Op::DUP_TOP:  { VMVal v=peek(); push(v); break; }
            case Op::POP_TOP:  pop(); break;
            case Op::ROT_TWO:  { VMVal a=pop(),b=pop(); push(a); push(b); break; }
            case Op::ROT_THREE:{ VMVal a=pop(),b=pop(),c=pop(); push(a); push(c); push(b); break; }

            // Arithmetic
            case Op::BINARY_ADD: { VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__add__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                if(r.type==VMType::INSTANCE&&lv.type==VMType::STRING){
                    VMVal sv=call_dunder(r,"__str__",{});
                    r=sv.type!=VMType::NONE?sv:VMVal::make_str(r.to_string());
                }
                push(op_add(lv,r)); break; }
            case Op::BINARY_SUB: { VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__sub__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(op_arith(lv,r,'-')); break; }
            case Op::BINARY_MUL: { VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__mul__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                if(r.type==VMType::INSTANCE){VMVal res=call_dunder(r,"__rmul__",{lv});if(res.type!=VMType::NONE){push(res);break;}}
                // list * int  or  int * list  → replicate list
                if(lv.type==VMType::LIST&&r.type==VMType::INT&&lv.list){
                    std::vector<VMVal> rep; for(int64_t k=0;k<r.i;k++) for(auto& x:*lv.list) rep.push_back(x);
                    push(VMVal::make_list(std::move(rep))); break;
                }
                if(r.type==VMType::LIST&&lv.type==VMType::INT&&r.list){
                    std::vector<VMVal> rep; for(int64_t k=0;k<lv.i;k++) for(auto& x:*r.list) rep.push_back(x);
                    push(VMVal::make_list(std::move(rep))); break;
                }
                // string * int  (already handled by op_arith but make explicit)
                push(op_arith(lv,r,'*')); break; }
            case Op::BINARY_DIV:      { VMVal r=pop(),l=pop(); push(op_div(l,r,false)); break; }
            case Op::BINARY_MOD:      { VMVal r=pop(),l=pop(); push(op_mod(l,r));       break; }
            case Op::BINARY_POW:      { VMVal r=pop(),l=pop();
                // Return int when both args are ints and exponent >= 0
                if(l.type==VMType::INT&&r.type==VMType::INT&&r.i>=0){
                    int64_t base=l.i,exp=r.i,res2=1;
                    for(int64_t k=0;k<exp;k++) res2*=base;
                    push(VMVal::make_int(res2)); break;
                }
                push(VMVal::make_float(std::pow(to_d(l),to_d(r)))); break; }
            case Op::BINARY_FLOOR_DIV:{ VMVal r=pop(),l=pop(); push(op_div(l,r,true));  break; }
            case Op::BINARY_AND:      { VMVal r=pop(),l=pop();
                if(l.type==VMType::LIST&&r.type==VMType::LIST&&l.list&&r.list){
                    std::unordered_set<std::string> other; for(auto& v:*r.list) other.insert(v.to_string());
                    std::vector<VMVal> res;
                    for(auto& v:*l.list) if(other.count(v.to_string())) res.push_back(v);
                    push(VMVal::make_list(std::move(res))); break;
                }
                push(op_bit(l,r,'&')); break; }
            case Op::BINARY_OR:       { VMVal r=pop(),l=pop();
                if(l.type==VMType::LIST&&r.type==VMType::LIST&&l.list&&r.list){
                    // set union
                    auto res=*l.list;
                    std::unordered_set<std::string> seen; for(auto& v:res) seen.insert(v.to_string());
                    for(auto& v:*r.list) if(!seen.count(v.to_string())){seen.insert(v.to_string());res.push_back(v);}
                    push(VMVal::make_list(std::move(res))); break;
                }
                push(op_bit(l,r,'|')); break; }
            case Op::BINARY_XOR:      { VMVal r=pop(),l=pop(); push(op_bit(l,r,'^'));    break; }
            case Op::BINARY_LSHIFT:   { VMVal r=pop(),l=pop(); push(op_bit(l,r,'<'));    break; }
            case Op::BINARY_RSHIFT:   { VMVal r=pop(),l=pop(); push(op_bit(l,r,'>'));    break; }
            // Compares
            case Op::COMPARE_EQ: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__eq__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv==r)); break;
            }
            case Op::COMPARE_NE: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__ne__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv!=r)); break;
            }
            case Op::COMPARE_LT: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__lt__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv<r)); break;
            }
            case Op::COMPARE_LE: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__le__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv<=r)); break;
            }
            case Op::COMPARE_GT: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__gt__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv>r)); break;
            }
            case Op::COMPARE_GE: {
                VMVal r=pop(),lv=pop();
                if(lv.type==VMType::INSTANCE){VMVal res=call_dunder(lv,"__ge__",{r});if(res.type!=VMType::NONE){push(res);break;}}
                push(VMVal::make_bool(lv>=r)); break;
            }
            case Op::COMPARE_IN:       { VMVal c=pop(),it=pop(); push(VMVal::make_bool(op_in(it,c))); break; }
            case Op::COMPARE_NOT_IN:   { VMVal c=pop(),it=pop(); push(VMVal::make_bool(!op_in(it,c))); break; }
            case Op::COMPARE_IS:       { VMVal r=pop(),l=pop(); push(VMVal::make_bool(op_is(l,r))); break; }
            case Op::COMPARE_IS_NOT:   { VMVal r=pop(),l=pop(); push(VMVal::make_bool(!op_is(l,r))); break; }
            case Op::COMPARE_IS_TYPE:  { VMVal t=pop(),v=pop(); push(VMVal::make_bool(value_is_type(v,t.s))); break; }
            case Op::COMPARE_IS_NOT_TYPE:{ VMVal t=pop(),v=pop(); push(VMVal::make_bool(!value_is_type(v,t.s))); break; }
            // Unary
            case Op::UNARY_NEG: {
                VMVal v=pop();
                if(v.type==VMType::INT)   push(VMVal::make_int(-v.i));
                else if(v.type==VMType::FLOAT) push(VMVal::make_float(-v.d));
                else if(v.type==VMType::INSTANCE){
                    VMVal r=call_dunder(v,"__neg__",{});
                    push(r.type!=VMType::NONE?r:VMVal::make_none());
                }
                else push(VMVal::make_none()); break;
            }
            case Op::UNARY_NOT:    push(VMVal::make_bool(!pop().is_truthy())); break;
            case Op::UNARY_BITNOT: { VMVal v=pop(); push(v.type==VMType::INT?VMVal::make_int(~v.i):VMVal::make_none()); break; }
            case Op::UNARY_POS:    break;

            // Jumps
            case Op::JUMP_FORWARD:         fr.ip=ins.arg; break;
            case Op::JUMP_ABSOLUTE:        fr.ip=ins.arg; break;
            case Op::JUMP_IF_FALSE: {
                VMVal v=pop();
                bool t = (v.type==VMType::INSTANCE) ? instance_truthy(v) : v.is_truthy();
                if(!t) fr.ip=ins.arg; break;
            }
            case Op::JUMP_IF_TRUE: {
                VMVal v=pop();
                bool t = (v.type==VMType::INSTANCE) ? instance_truthy(v) : v.is_truthy();
                if(t) fr.ip=ins.arg; break;
            }
            case Op::JUMP_IF_FALSE_OR_POP: { if(!peek().is_truthy()) fr.ip=ins.arg; else pop(); break; }
            case Op::JUMP_IF_TRUE_OR_POP:  { if(peek().is_truthy())  fr.ip=ins.arg; else pop(); break; }

            // Make function/class
            case Op::MAKE_FUNCTION: {
                int fn_idx = ins.arg & 0xFFFF;
                int n_defs = (ins.arg >> 16) & 0xFF;
                // Pop defaults from stack (pushed in order, last default on top)
                std::vector<VMVal> defs(n_defs);
                for(int i=n_defs-1;i>=0;i--) defs[i]=pop();
                auto fn_val = VMVal::make_func(fr.code->sub_codes[fn_idx]);
                // Store defaults into the function's sub_code
                if(n_defs>0 && fn_val.code){
                    int n_params=(int)fn_val.code->param_names.size();
                    fn_val.code->param_defaults.resize(n_params, VMVal{VMType::UNDEFINED});
                    // Defaults align to the END of param list
                    for(int i=0;i<n_defs&&i<n_params;i++)
                        fn_val.code->param_defaults[n_params-n_defs+i]=defs[i];
                }
                // Capture enclosing locals as closure environment ONLY when inside a function
                bool in_function = (fr.code->name != "<module>" && !fr.code->is_class);
                if(in_function){
                    // Create shared closure_env on first inner function in this frame
                    // so ALL inner functions share the SAME cell for mutable variables
                    if(!fr.closure_env){
                        fr.closure_env = std::make_shared<std::unordered_map<std::string,VMVal>>(fr.locals);
                    } else {
                        // Sync any new locals into the shared closure_env
                        for(auto& kv : fr.locals)
                            if(!fr.closure_env->count(kv.first))
                                (*fr.closure_env)[kv.first] = kv.second;
                    }
                    fn_val.closure_env = fr.closure_env;
                }
                if(!fn_val.closure_env && fr.closure_env && !fr.closure_env->empty()){
                    fn_val.closure_env = fr.closure_env;
                }
                push(std::move(fn_val)); break;
            }
            case Op::MAKE_CLASS: {
                auto sub=fr.code->sub_codes[ins.arg];
                // Statically scan class body to collect class-level variable initializations
                // (LOAD_CONST followed by DEFINE_NAME = class variable)
                {
                    std::unordered_map<std::string,VMVal> cvars;
                    const auto& insts = sub->instructions;
                    for(size_t ci=0;ci+1<insts.size();ci++){
                        const auto& prev_ins = insts[ci];
                        const auto& cur_ins  = insts[ci+1];
                        if(cur_ins.op==Op::DEFINE_NAME&&
                           prev_ins.op==Op::LOAD_CONST){
                            std::string vname=sub->names.size()>(size_t)cur_ins.arg?
                                              sub->names[cur_ins.arg]:"";
                            if(!vname.empty()){
                                VMVal val=VMVal::make_none();
                                if(sub->constants.size()>(size_t)prev_ins.arg)
                                    val=sub->constants[prev_ins.arg];
                                cvars[vname]=val;
                            }
                        }
                        // Nested class: MAKE_CLASS followed by DEFINE_NAME
                        if(cur_ins.op==Op::DEFINE_NAME&&prev_ins.op==Op::MAKE_CLASS){
                            std::string vname=sub->names.size()>(size_t)cur_ins.arg?
                                              sub->names[cur_ins.arg]:"";
                            if(!vname.empty()&&prev_ins.arg<(int)sub->sub_codes.size()){
                                auto nsub=sub->sub_codes[prev_ins.arg];
                                VMVal cv=VMVal::make_class(nsub,nsub->name);
                                cvars[vname]=cv;
                                class_reg_[nsub->name]=nsub;
                            }
                        }
                    }
                    if(!cvars.empty()) class_vars_[sub->name]=std::move(cvars);
                }
                push(VMVal::make_class(sub,sub->name));
                class_reg_[sub->name]=sub; break;
            }

            // Calls
            case Op::CALL_KW: {
                int total=ins.arg;
                std::vector<VMVal> all_args(total);
                for(int i=total-1;i>=0;i--) all_args[i]=pop();
                VMVal callee=pop();
                VMVal kwargs_map=all_args.back(); all_args.pop_back();
                int n_pos=(int)all_args.size();
                if(callee.type==VMType::FUNCTION&&callee.code){
                    auto& pnames=callee.code->param_names;
                    std::vector<VMVal> bound;
                    int arg_idx=0;
                    for(int pi=0;pi<(int)pnames.size();pi++){
                        const std::string& pn=pnames[pi];
                        if(pn.size()>=2&&pn[0]=='*'&&pn[1]=='*'){bound.push_back(kwargs_map);arg_idx=(int)all_args.size();}
                        else if(!pn.empty()&&pn[0]=='*'){std::vector<VMVal> rest(all_args.begin()+arg_idx,all_args.end());bound.push_back(VMVal::make_list(std::move(rest)));arg_idx=(int)all_args.size();}
                        else if(arg_idx<n_pos) bound.push_back(all_args[arg_idx++]);
                        else if(kwargs_map.map&&kwargs_map.map->count(pn)) bound.push_back((*kwargs_map.map)[pn]);
                        else if(pi<(int)callee.code->param_defaults.size()&&callee.code->param_defaults[pi].type!=VMType::UNDEFINED) bound.push_back(callee.code->param_defaults[pi]);
                        else bound.push_back(VMVal::make_none());
                    }
                    // Build locals map and call without re-expansion
                    std::unordered_map<std::string,VMVal> locs;
                    for(int bi=0;bi<(int)pnames.size()&&bi<(int)bound.size();bi++){
                        const std::string& pn2=pnames[bi];
                        std::string ln2=(pn2.size()>=2&&pn2[0]=='*'&&pn2[1]=='*')?pn2.substr(2):(!pn2.empty()&&pn2[0]=='*')?pn2.substr(1):pn2;
                        locs[ln2]=bound[bi];
                    }
                    push(exec_code_bound(callee.code,std::move(locs),std::nullopt,callee.closure_env));
                } else {
                    // Native: append kwargs_map as last arg so natives can check by name
                    if(kwargs_map.type==VMType::MAP) all_args.push_back(kwargs_map);
                    std::optional<VMVal> no_self=std::nullopt;
                    push(vm_call(callee,all_args,no_self));
                }
                break;
            }
            case Op::LIST_EXTEND: {
                // TOS = iterable to extend with; TOS1 = list to extend
                VMVal ext=pop(); VMVal& lst=stack_.back();
                if(lst.type==VMType::LIST&&lst.list){
                    if(ext.type==VMType::LIST&&ext.list)
                        for(auto& v:*ext.list) lst.list->push_back(v);
                }
                break;
            }
            case Op::LIST_APPEND: {
                // TOS = item to append; TOS1 = list
                VMVal item=pop(); VMVal& lst=stack_.back();
                if(lst.type==VMType::LIST&&lst.list) lst.list->push_back(item);
                break;
            }
            case Op::CALL_EX: {
                // CALL_EX: stack has [callee, arg0, ..., argN-1, star_list]
                // ins.arg = n_args_pushed (includes star_list as last arg if positive)
                // negative ins.arg = method call mode: [obj, attr_str, ..., star_list]
                bool method_mode = ins.arg < 0;
                // Pop all stack items: the last one is the star_list
                // Determine how many items were pushed (excluding callee/obj+attr)
                // We don't know exactly how many non-star args were pushed — 
                // so we collect everything and the last item is the star list:
                // In our emit, we push: callee, then for each arg either visit(arg) 
                // or visit(u->operand) for *arg. Last arg is always the spread list.
                // ins.arg for non-method = n_pos_args (counting star as 1 item)
                // We need to pop n_pos_args items + the callee.
                int n_pushed = method_mode ? (-ins.arg) : ins.arg;
                std::vector<VMVal> raw(n_pushed);
                for(int i=n_pushed-1;i>=0;i--) raw[i]=pop();
                // The last element of raw is the star-list; spread it
                VMVal star_arg = raw.back(); raw.pop_back();
                std::vector<VMVal> args = std::move(raw);
                if(star_arg.type==VMType::LIST&&star_arg.list)
                    for(auto& v:*star_arg.list) args.push_back(v);
                else args.push_back(star_arg); // not a list, just append
                if(method_mode){
                    VMVal mname=pop(); VMVal obj=pop();
                    push(vm_call_method(obj,mname.s,args));
                } else {
                    VMVal callee=pop();
                    push(vm_call(callee,args,std::nullopt));
                }
                break;
            }
            case Op::CALL_FUNCTION: {
                int argc=ins.arg;
                std::vector<VMVal> args(argc);
                for(int i=argc-1;i>=0;i--) args[i]=pop();
                VMVal callee=pop();
                // Calling something that does not exist returned none and
                // carried on, exactly as the interpreter used to. The
                // interpreter now raises NameError, so without this the SAME
                // program errors on one engine and silently misbehaves on the
                // other — a divergence introduced by fixing only one side.
                //
                // The callee value no longer carries its name, but the
                // preceding LOAD_NAME does: recover it from the instruction
                // before this one so the message can name the identifier.
                if(callee.type==VMType::NONE||callee.type==VMType::UNDEFINED){
                    std::string called = calleeNameBefore(fr, fr.ip - 1);
                    if(!called.empty() && !globals_.count(called))
                        throw std::string("__exc__:NameError:'" + called
                            + "' is not defined at line " + std::to_string(ins.line));
                }
                push(vm_call(callee,args,std::nullopt)); break;
            }
            case Op::CALL_METHOD: {
                int argc=ins.arg;
                std::vector<VMVal> args(argc);
                for(int i=argc-1;i>=0;i--) args[i]=pop();
                VMVal mname=pop(); VMVal obj=pop();
                push(vm_call_method(obj,mname.s,args)); break;
            }
            case Op::RETURN_VALUE: throw VMReturn{pop()};
            case Op::YIELD_VALUE: {
                VMVal yv=pop();
                auto& cfr=call_stack_.back();
                if(cfr.gen_state){
                    cfr.gen_state->ip=cfr.ip;   // ip points past YIELD_VALUE
                    cfr.gen_state->locals=cfr.locals;
                    // Save stack slice above stack_base (holds loop iterators etc.)
                    size_t base=cfr.gen_state->stack_base;
                    cfr.gen_state->saved_stack.clear();
                    if(stack_.size() > base){
                        cfr.gen_state->saved_stack.assign(stack_.begin()+base, stack_.end());
                        stack_.resize(base);
                    }
                }
                throw VMYield{yv};
            }

            // yield from: get iterator from TOS, yield each item in turn
            case Op::YIELD_FROM_OP: {
                VMVal src=pop();
                // Convert to iterator
                VMVal it_val;
                if(src.type==VMType::GENERATOR||src.type==VMType::ITERATOR){it_val=src;}
                else if(src.type==VMType::LIST&&src.list){
                    std::vector<VMVal> copy=*src.list; it_val=VMVal::make_iter(std::move(copy));
                } else if(src.type==VMType::INSTANCE){
                    VMVal ir=call_dunder(src,"__iter__",{});
                    it_val=(ir.type!=VMType::NONE?ir:src);
                } else {it_val=src;}
                // Yield each item one by one
                // We re-use the stack save mechanism: save it_val above stack_base, re-enter YIELD_FROM_OP
                // by decrementing ip. But simpler: collect all & yield via FOR_ITER pattern.
                // For correctness: just iterate fully and yield each item inline.
                while(true){
                    VMVal item;
                    bool got=false;
                    if(it_val.type==VMType::GENERATOR){
                        if(!it_val.gen||it_val.gen->done) break;
                        item=gen_next(it_val);
                        if(it_val.gen&&it_val.gen->done) break;
                        got=true;
                    } else if(it_val.type==VMType::ITERATOR){
                        if(!it_val.iter||it_val.iter->first>=(int)it_val.iter->second.size()) break;
                        item=it_val.iter->second[it_val.iter->first++];
                        got=true;
                    } else break;
                    if(!got) break;
                    // Yield item: save generator state with it_val on saved_stack
                    auto& cfr=call_stack_.back();
                    if(cfr.gen_state){
                        cfr.gen_state->ip=cfr.ip-1; // re-execute YIELD_FROM_OP on resume
                        cfr.gen_state->locals=cfr.locals;
                        size_t base=cfr.gen_state->stack_base;
                        cfr.gen_state->saved_stack.clear();
                        // Save it_val (with updated iterator position) so resume can continue
                        push(it_val);
                        if(stack_.size()>base){
                            cfr.gen_state->saved_stack.assign(stack_.begin()+base,stack_.end());
                            stack_.resize(base);
                        }
                        throw VMYield{item};
                    }
                    // Not in a generator context (shouldn't happen) - just push
                }
                break;
            }

            // Iteration
            case Op::GET_ITER: {
                VMVal it=pop();
                if(it.type==VMType::GENERATOR){push(it);break;}
                if(it.type==VMType::ITERATOR){push(it);break;}
                if(it.type==VMType::INSTANCE){
                    // Call __iter__ if defined, else push as-is for __next__ protocol
                    VMVal iter_res=call_dunder(it,"__iter__",{});
                    push(iter_res.type!=VMType::NONE?iter_res:it); break;
                }
                if(it.type==VMType::LIST&&it.list){
                    std::vector<VMVal> copy=*it.list; push(VMVal::make_iter(std::move(copy))); break;
                }
                if(it.type==VMType::MAP&&it.map){
                    std::vector<VMVal> keys;
                    for(auto& [k,v]:*it.map) keys.push_back(VMVal::make_str(k));
                    push(VMVal::make_iter(std::move(keys))); break;
                }
                if(it.type==VMType::STRING){
                    std::vector<VMVal> chars;
                    for(char ch:it.s) chars.push_back(VMVal::make_str(std::string(1,ch)));
                    push(VMVal::make_iter(std::move(chars))); break;
                }
                // Fallback: use the old make_iter(VMVal&) helper
                push(make_iter(it)); break;
            }
            case Op::FOR_ITER: {
                // NOTE: use index not reference — gen_next/call_dunder may reallocate stack_
                int it_idx = (int)stack_.size()-1;
                if(it_idx < 0){ fr.ip=ins.arg; break; }
                VMType it_type = stack_[it_idx].type;
                if(it_type==VMType::INSTANCE){
                    VMVal it_copy = stack_[it_idx]; // copy since stack may reallocate
                    VMVal nv;
                    bool stop_iter=false;
                    try { nv=call_dunder(it_copy,"__next__",{}); }
                    catch(std::runtime_error&){ stop_iter=true; }
                    // Sync back in case gen_next moved it
                    if(stop_iter||nv.type==VMType::NONE){ pop(); fr.ip=ins.arg; break; }
                    push(nv); break;
                }
                if(it_type==VMType::GENERATOR){
                    if(!stack_[it_idx].gen||stack_[it_idx].gen->done){ pop(); fr.ip=ins.arg; break; }
                    VMVal yv=gen_next(stack_[it_idx]); // pass by ref through index
                    if(!stack_[it_idx].gen||stack_[it_idx].gen->done){ pop(); fr.ip=ins.arg; break; }
                    push(yv); break;
                }
                if(it_type==VMType::ITERATOR&&stack_[it_idx].iter){
                    auto&[cur,items]=*stack_[it_idx].iter;
                    if(cur<(int)items.size()) push(items[cur++]);
                    else { pop(); fr.ip=ins.arg; }
                } else { pop(); fr.ip=ins.arg; }
                break;
            }
            case Op::UNPACK_SEQ: {
                VMVal seq=pop(); int n=ins.arg;
                std::vector<VMVal> items;
                if(seq.type==VMType::LIST&&seq.list) items=*seq.list;
                else if(seq.type==VMType::STRING)
                    for(char c:seq.s) items.push_back(VMVal::make_str(std::string(1,c)));
                while((int)items.size()<n) items.push_back(VMVal::make_none());
                for(int i=n-1;i>=0;i--) push(items[i]); break;
            }

            case Op::PRINT: {
                VMVal v=pop(); std::string out;
                if(v.type==VMType::INSTANCE){
                    bool found=false;
                    for(auto dname : {"__str__","__repr__"}){
                        if(found) break;
                        std::string cls=v.class_name;
                        while(!cls.empty()&&!found){
                            auto cit=class_reg_.find(cls);
                            if(cit==class_reg_.end()) break;
                            for(auto& sub:cit->second->sub_codes)
                                if(sub->name==dname&&!sub->is_class){
                                    std::vector<VMVal> na; out=exec_code(sub,na,v).to_string(); found=true; break;
                                }
                            cls=cit->second->parent_class;
                        }
                    }
                    if(!found) out=v.to_string();
                } else out=v.to_string();
                std::cout<<out<<"\n"; break;
            }
            case Op::IMPORT_NAME: vm_import(fr.code->names[ins.arg]); break;

            // Exception handling
            case Op::RAISE: {
                VMVal ev=pop();
                std::string msg;
                if(ev.type==VMType::INSTANCE){
                    // Store the instance as the current exception object (for except as e:)
                    std::string cls=ev.class_name;
                    bool found=false;
                    while(!cls.empty()&&!found){
                        auto cit=class_reg_.find(cls);
                        if(cit==class_reg_.end()) break;
                        for(auto& sub:cit->second->sub_codes)
                            if(sub->name=="__str__"&&!sub->is_class){
                                std::vector<VMVal> na; msg=exec_code(sub,na,ev).to_string(); found=true; break;
                            }
                        cls=cit->second->parent_class;
                    }
                    if(!found) msg=ev.to_string();
                    // Encode the instance into the error message so it survives the catch
                    // We wrap: encode as JSON-like to recover in except handler
                    last_exception_obj_=ev;
                } else {
                    msg=ev.to_string();
                    last_exception_obj_=VMVal::make_none();
                }
                throw std::runtime_error(msg);
            }
            case Op::SETUP_EXCEPT: break;   // marker only; handled structurally
            case Op::END_EXCEPT:   break;   // marker only
            case Op::STORE_EXCEPT_AS: {
                // exception value is on stack; store under alias name
                VMVal exc=stack_.empty()?VMVal::make_str("Exception"):pop();
                define_var(fr.code->names[ins.arg], exc); break;
            }
            case Op::LOAD_SELF_ATTR: {
                VMVal self_v = fr.self_val.value_or(VMVal::make_none());
                push(get_attr(self_v, fr.code->names[ins.arg])); break;
            }
            case Op::STORE_SELF_ATTR: {
                VMVal val = pop();
                VMVal& self_v = *fr.self_val;
                set_attr(self_v, fr.code->names[ins.arg], std::move(val)); break;
            }

            case Op::RAISE_ERROR: {
                VMVal ev=pop();
                std::string msg;
                VMVal exc_obj;
                if(ev.type==VMType::INSTANCE){
                    // Raised an instance — call __str__ for the message
                    exc_obj=ev;
                    last_exception_obj_=ev;
                    VMVal s=call_dunder(ev,"__str__",{});
                    msg=s.type!=VMType::NONE?s.to_string():ev.to_string();
                } else {
                    msg=ev.to_string();
                    exc_obj=VMVal::make_str(msg);
                    last_exception_obj_=VMVal::make_none();
                }
                // Check exception table for a matching handler
                int ip_at_raise = fr.ip - 1;
                bool handled = false;
                for(auto& ee : fr.code->exc_table){
                    if(ip_at_raise >= ee.try_start && ip_at_raise < ee.try_end){
                        push(exc_obj);
                        fr.ip = match_except_handler(ee, exc_obj);
                        handled = true;
                        last_exception_obj_=VMVal::make_none();
                        break;
                    }
                }
                if(!handled) throw std::runtime_error(msg);
                break;
            }
                push(VMVal::make_str(pop().to_string())); break;

            case Op::IADD: {
                VMVal r=pop(),l=pop();
                if(l.type==VMType::INSTANCE){
                    VMVal res=call_dunder(l,"__iadd__",{r});
                    if(res.type!=VMType::NONE){push(res);break;}
                }
                push(op_add(l,r)); break;
            }
            case Op::ISUB: { VMVal r=pop(),l=pop();
                if(l.type==VMType::INSTANCE){ VMVal res=call_dunder(l,"__isub__",{r}); if(res.type!=VMType::NONE){push(res);break;} }
                push(op_arith(l,r,'-')); break; }
            case Op::IMUL: { VMVal r=pop(),l=pop();
                if(l.type==VMType::INSTANCE){ VMVal res=call_dunder(l,"__imul__",{r}); if(res.type!=VMType::NONE){push(res);break;} }
                push(op_arith(l,r,'*')); break; }
            case Op::IDIV: { VMVal r=pop(),l=pop(); push(op_div(l,r,false)); break; }
            case Op::IMOD: { VMVal r=pop(),l=pop(); push(op_mod(l,r)); break; }

            default: break;
            } // end switch
            } catch(VMReturn& r) { throw; }  // propagate returns
              catch(std::runtime_error& exc) {
                CallFrame& fr2=call_stack_.back();
                std::string emsg=exc.what();
                // Use the exception object if available (raised via 'raise instance')
                VMVal exc_val = (last_exception_obj_.type==VMType::INSTANCE) ?
                    last_exception_obj_ : VMVal::make_str(emsg);
                last_exception_obj_ = VMVal::make_none(); // clear after use
                bool handled=false;
                // 1) Check exc_table (structured try/except blocks)
                int ip_at_raise=fr2.ip-1;
                for(auto& ee:fr2.code->exc_table){
                    if(ip_at_raise>=ee.try_start && ip_at_raise<=ee.try_end){
                        push(exc_val);
                        fr2.ip=match_except_handler(ee, exc_val);
                        handled=true; break;
                    }
                }
                // 2) Fallback: find SETUP_EXCEPT instruction (used by `with`,
                // see NT::WITH). Must skip any SETUP_EXCEPT whose block
                // already exited normally (reached its matching END_EXCEPT)
                // - otherwise an exception raised anywhere after a completed
                // `with` block, with nothing else to catch it, walked back
                // into that `with`'s stale handler instead of propagating,
                // re-ran the code after the `with` block, hit the same raise
                // again, and looped forever.
                if(!handled){
                    int skip=0;
                    for(int i=fr2.ip-1;i>=0;i--){
                        Op op2=fr2.code->instructions[i].op;
                        if(op2==Op::END_EXCEPT){ skip++; continue; }
                        if(op2==Op::SETUP_EXCEPT){
                            if(skip>0){ skip--; continue; }
                            push(exc_val);
                            fr2.ip=fr2.code->instructions[i].arg;
                            handled=true; break;
                        }
                    }
                }
                if(!handled) throw;
              }
        }
    }

    // ── JSON parser ─────────────────────────────────────────────────────────
    static std::pair<VMVal,size_t> json_parse_val(const std::string& s, size_t pos) {
        // Skip whitespace
        while(pos<s.size()&&(s[pos]==' '||s[pos]=='\t'||s[pos]=='\r'||s[pos]=='\n')) pos++;
        if(pos>=s.size()) return {VMVal::make_none(),pos};
        char c=s[pos];
        if(c=='"') {
            // Parse string
            size_t start=pos+1; std::string val;
            pos=start;
            while(pos<s.size()&&s[pos]!='"'){
                if(s[pos]=='\\'&&pos+1<s.size()){
                    char esc=s[pos+1];
                    if(esc=='n') val+='\n';
                    else if(esc=='t') val+='\t';
                    else val+=esc;
                    pos+=2;
                } else { val+=s[pos++]; }
            }
            return {VMVal::make_str(val), pos+1};
        }
        if(c=='{') {
            // Parse object
            auto map=std::make_shared<std::unordered_map<std::string,VMVal>>();
            pos++;
            while(pos<s.size()){
                while(pos<s.size()&&(s[pos]==' '||s[pos]=='\t'||s[pos]=='\r'||s[pos]=='\n')) pos++;
                if(pos>=s.size()||s[pos]=='}'){pos++;break;}
                if(s[pos]==','){pos++;continue;}
                auto [key,p1]=json_parse_val(s,pos); pos=p1;
                while(pos<s.size()&&s[pos]!=':') pos++;
                pos++; // skip ':'
                auto [val,p2]=json_parse_val(s,pos); pos=p2;
                (*map)[key.s]=std::move(val);
            }
            VMVal r; r.type=VMType::MAP; r.map=map; return {std::move(r),pos};
        }
        if(c=='[') {
            // Parse array
            std::vector<VMVal> items; pos++;
            while(pos<s.size()){
                while(pos<s.size()&&(s[pos]==' '||s[pos]=='\t'||s[pos]=='\r'||s[pos]=='\n')) pos++;
                if(pos>=s.size()||s[pos]==']'){pos++;break;}
                if(s[pos]==','){pos++;continue;}
                auto [val,p]=json_parse_val(s,pos); pos=p;
                items.push_back(std::move(val));
            }
            return {VMVal::make_list(std::move(items)),pos};
        }
        if(s.substr(pos,4)=="null"||s.substr(pos,4)=="none") return {VMVal::make_none(),pos+4};
        if(s.substr(pos,4)=="true") return {VMVal::make_bool(true),pos+4};
        if(s.substr(pos,5)=="false") return {VMVal::make_bool(false),pos+5};
        // Number
        size_t start=pos;
        bool is_float=false;
        if(pos<s.size()&&(s[pos]=='-')) pos++;
        while(pos<s.size()&&::isdigit((unsigned char)s[pos])) pos++;
        if(pos<s.size()&&s[pos]=='.'){is_float=true;pos++;while(pos<s.size()&&::isdigit((unsigned char)s[pos]))pos++;}
        if(pos<s.size()&&(s[pos]=='e'||s[pos]=='E')){is_float=true;pos++;if(pos<s.size()&&(s[pos]=='+'||s[pos]=='-'))pos++;while(pos<s.size()&&::isdigit((unsigned char)s[pos]))pos++;}
        std::string num_s=s.substr(start,pos-start);
        if(is_float) try{return {VMVal::make_float(std::stod(num_s)),pos};}catch(...){}
        else try{return {VMVal::make_int(std::stoll(num_s)),pos};}catch(...){}
        return {VMVal::make_none(),pos};
    }

    // ── Arithmetic helpers ────────────────────────────────────────────────
    static double to_d(const VMVal& v) {
        if(v.type==VMType::INT)   return (double)v.i;
        if(v.type==VMType::FLOAT) return v.d;
        if(v.type==VMType::BOOL)  return v.b?1.0:0.0;
        if(v.type==VMType::STRING){ try{return std::stod(v.s);}catch(...){} }
        return 0.0;
    }
    static VMVal op_add(const VMVal& l, const VMVal& r) {
        if(l.type==VMType::STRING||r.type==VMType::STRING)
            return VMVal::make_str(l.to_string()+r.to_string());
        if(l.type==VMType::LIST&&r.type==VMType::LIST){
            auto res=VMVal::make_list(*l.list);
            if(r.list) for(auto& v:*r.list) res.list->push_back(v);
            return res;
        }
        if(l.type==VMType::FLOAT||r.type==VMType::FLOAT)
            return VMVal::make_float(to_d(l)+to_d(r));
        return VMVal::make_int(l.i+r.i);
    }
    static VMVal op_arith(const VMVal& l, const VMVal& r, char op) {
        if(l.type==VMType::FLOAT||r.type==VMType::FLOAT){
            double a=to_d(l),b=to_d(r);
            return op=='-'?VMVal::make_float(a-b):VMVal::make_float(a*b);
        }
        int64_t a=l.type==VMType::INT?l.i:(int64_t)to_d(l);
        int64_t b=r.type==VMType::INT?r.i:(int64_t)to_d(r);
        if(op=='-') return VMVal::make_int(a-b);
        // multiply: str * int
        if(op=='*'){
            if(l.type==VMType::STRING&&r.type==VMType::INT){
                std::string s; for(int64_t i=0;i<r.i;i++) s+=l.s;
                return VMVal::make_str(s);
            }
            return VMVal::make_int(a*b);
        }
        return VMVal::make_none();
    }
    static VMVal op_div(const VMVal& l, const VMVal& r, bool floor_div) {
        double a=to_d(l),b=to_d(r);
        if(b==0.0) throw std::runtime_error("ZeroDivisionError: division by zero");
        if(floor_div) return VMVal::make_int((int64_t)std::floor(a/b));
        // Return int when both operands are ints and result is exact
        if(l.type==VMType::INT&&r.type==VMType::INT&&r.i!=0&&l.i%r.i==0)
            return VMVal::make_int(l.i/r.i);
        return VMVal::make_float(a/b);
    }
    static VMVal op_mod(const VMVal& l, const VMVal& r) {
        if(l.type==VMType::STRING){
            const std::string& fmt=l.s;
            std::vector<VMVal> args;
            if(r.type==VMType::LIST&&r.list) args=*r.list;
            else args={r};
            size_t ai=0; std::string out;
            for(size_t i=0;i<fmt.size();i++){
                if(fmt[i]=='%'&&i+1<fmt.size()){
                    char spec=fmt[i+1];
                    if(spec=='%'){out+='%';i++;continue;}
                    VMVal av=(ai<args.size())?args[ai++]:VMVal::make_none();
                    // collect width/precision: %-10.2f etc.
                    size_t spec_start=i+1;
                    while(spec_start<fmt.size()&&(std::isdigit((unsigned char)fmt[spec_start])||fmt[spec_start]=='.'||fmt[spec_start]=='-'||fmt[spec_start]=='+'||fmt[spec_start]==' '))
                        spec_start++;
                    std::string fmtmod="%";
                    if(spec_start>i+1) fmtmod+=fmt.substr(i+1,spec_start-i-1);
                    spec=(spec_start<fmt.size())?fmt[spec_start]:'?';
                    fmtmod+=spec;
                    i=spec_start;
                    if(spec=='s'||spec=='r') out+=av.to_string();
                    else if(spec=='d'||spec=='i'){
                        char buf[64]; std::snprintf(buf,sizeof(buf),fmtmod.c_str(),(long)(av.type==VMType::FLOAT?(int64_t)av.d:av.i)); out+=buf;
                    } else if(spec=='f'||spec=='g'||spec=='e'||spec=='E'||spec=='G'){
                        char buf[64]; double dv=av.type==VMType::INT?(double)av.i:av.d;
                        std::snprintf(buf,sizeof(buf),fmtmod.c_str(),dv); out+=buf;
                    } else if(spec=='x'||spec=='X'){
                        char buf[64]; std::snprintf(buf,sizeof(buf),fmtmod.c_str(),(long)av.i); out+=buf;
                    } else out+='%',out+=spec;
                } else { out+=fmt[i]; }
            }
            return VMVal::make_str(std::move(out));
        }

        if(l.type==VMType::STRING){
            // Python-style % formatting
            const std::string& fmt=l.s;
            std::vector<VMVal> args;
            if(r.type==VMType::LIST&&r.list) args=*r.list;
            else args={r};
            size_t ai=0;
            std::string out;
            for(size_t i=0;i<fmt.size();i++){
                if(fmt[i]=='%'&&i+1<fmt.size()){
                    char spec=fmt[i+1];
                    if(spec=='%'){out+='%';i++;continue;}
                    VMVal av=(ai<args.size())?args[ai++]:VMVal::make_none();
                    // collect width/precision between % and the format spec
                    size_t spec_start=i+1;
                    while(spec_start<fmt.size()&&(std::isdigit(fmt[spec_start])||fmt[spec_start]=='.'||fmt[spec_start]=='-'||fmt[spec_start]=='+'||fmt[spec_start]==' '))
                        spec_start++;
                    std::string fmtmod(fmt.begin()+i,fmt.begin()+spec_start+1); // e.g. "%.2f"
                    spec=(spec_start<fmt.size())?fmt[spec_start]:'?';
                    i=spec_start;
                    if(spec=='s'||spec=='r') out+=av.to_string();
                    else if(spec=='d'||spec=='i'){
                        char buf[64]; std::string f2=fmtmod; f2.back()='d';
                        std::snprintf(buf,sizeof(buf),f2.c_str(),(long)(av.type==VMType::FLOAT?(int64_t)av.d:av.i)); out+=buf;
                    } else if(spec=='f'||spec=='g'||spec=='e'||spec=='E'||spec=='G'){
                        char buf[64]; double dv=av.type==VMType::INT?(double)av.i:av.d;
                        std::snprintf(buf,sizeof(buf),fmtmod.c_str(),dv); out+=buf;
                    } else if(spec=='x'||spec=='X'){
                        char buf[64]; std::string f2=fmtmod; f2.back()=spec;
                        std::snprintf(buf,sizeof(buf),f2.c_str(),(long)av.i); out+=buf;
                    } else out+='%',out+=spec;
                } else { out+=fmt[i]; }
            }
            return VMVal::make_str(std::move(out));
        }

        if(l.type==VMType::FLOAT||r.type==VMType::FLOAT){
            double a=to_d(l),b=to_d(r);
            if(b==0.0) return VMVal::make_none();
            double res=std::fmod(a,b);
            if(res!=0.0&&((res<0)!=(b<0))) res+=b; // Python-style
            return VMVal::make_float(res);
        }
        if(r.i==0) throw std::runtime_error("ZeroDivisionError: division by zero");
        int64_t res=l.i%r.i;
        if(res!=0&&((res<0)!=(r.i<0))) res+=r.i; // Python-style
        return VMVal::make_int(res);
    }
    static VMVal op_bit(const VMVal& l, const VMVal& r, char op) {
        int64_t a=(int64_t)to_d(l),b=(int64_t)to_d(r);
        switch(op){
        case '&': return VMVal::make_int(a&b);
        case '|': return VMVal::make_int(a|b);
        case '^': return VMVal::make_int(a^b);
        case '<': return VMVal::make_int(a<<b);
        case '>': return VMVal::make_int(a>>b);
        default:  return VMVal::make_none();
        }
    }
    bool op_in(const VMVal& item, const VMVal& cont) {
        if(cont.type==VMType::INSTANCE){
            VMVal res=call_dunder(cont,"__contains__",{item});
            if(res.type!=VMType::NONE) return res.is_truthy();
        }
        if(cont.type==VMType::STRING&&item.type==VMType::STRING)
            return cont.s.find(item.s)!=std::string::npos;
        if(cont.type==VMType::LIST&&cont.list)
            for(auto& v:*cont.list) if(v==item) return true;
        if(cont.type==VMType::MAP&&cont.map)
            return cont.map->count(item.to_string())>0;
        return false;
    }
    // Which except clause (if any) a raised exception should run: the first
    // whose declared type is empty (catch-all), one of the generic
    // Exception/BaseException/Error names, equal to the exception's own
    // type, or a parent of it. Mirrors the interpreter's evalTry
    // (NythonExecutor.hpp) type-matching, including its silent fall-through
    // to `finally` (ee.end) when nothing matches rather than re-raising.
    int match_except_handler(const ExceptionEntry& ee, const VMVal& exc_val) {
        std::string exc_type = exc_val.type==VMType::INSTANCE ? exc_val.class_name : std::string();
        for(auto& cl : ee.clauses){
            if(cl.type_name.empty()) return cl.handler;
            if(exc_type.empty()) continue; // typed clause, untyped exception: no match
            if(exc_type==cl.type_name || cl.type_name=="Exception"
               || cl.type_name=="BaseException" || cl.type_name=="Error")
                return cl.handler;
            std::string cur=exc_type; int guard=0;
            while(!cur.empty() && guard++<16){
                auto cit=class_reg_.find(cur);
                if(cit==class_reg_.end()) break;
                cur=cit->second->parent_class;
                if(cur==cl.type_name) return cl.handler;
            }
        }
        return ee.end;
    }
    bool value_is_type(const VMVal& v, const std::string& want) {
        // Everything is an Object.
        if(want=="Object"||want=="object"||want=="any"||want=="Any") return true;
        switch(v.type){
            case VMType::INT:   return want=="int"||want=="Integer"||want=="integer";
            case VMType::FLOAT: return want=="float"||want=="Float"||want=="double"||want=="Double";
            case VMType::BOOL:  return want=="bool"||want=="Boolean"||want=="boolean";
            case VMType::NONE:  return want=="none"||want=="None";
            case VMType::STRING:return want=="str"||want=="String"||want=="string";
            case VMType::LIST:  return want=="list"||want=="List"||want=="array"||want=="Array";
            case VMType::MAP:   return want=="map"||want=="Map"||want=="dict"||want=="Dict";
            case VMType::FUNCTION: case VMType::NATIVE:
                                return want=="function"||want=="Function";
            default: break;
        }
        if(v.type==VMType::INSTANCE){
            // Walk the inheritance chain so `child is Base` holds.
            std::string cur=v.class_name;
            int guard=0;
            while(!cur.empty() && guard++<64){
                if(cur==want) return true;
                auto it=class_reg_.find(cur);
                if(it==class_reg_.end()||!it->second) break;
                cur=it->second->parent_class;
            }
        }
        return false;
    }

    static bool op_is(const VMVal& l, const VMVal& r) {
        if(l.type==VMType::NONE&&r.type==VMType::NONE) return true;
        if(l.type!=r.type) return false;
        if(l.type==VMType::BOOL) return l.b==r.b;
        // Containers compare by identity: two separately built lists with equal
        // contents are not the same list. The interpreter already did this; the
        // VM returned true for `L is L` only by accident of `l==r` and false
        // where the shared_ptrs differed, so the two disagreed both ways.
        if(l.type==VMType::LIST) return l.list.get()==r.list.get();
        if(l.type==VMType::MAP)  return l.map.get()==r.map.get();
        // Functions compare by identity, not by structural equality: two
        // distinct functions are not "the same function".
        if(l.type==VMType::FUNCTION) return l.code.get()==r.code.get();
        if(l.type==VMType::NATIVE)   return false;
        return l==r;
    }

    // ── Attribute access ────────────────────────────────────────────────
    VMVal get_attr(const VMVal& obj, const std::string& attr) {
        // Instance / map fields — check for property descriptors
        if((obj.type==VMType::INSTANCE||obj.type==VMType::MAP)&&obj.map){
            auto it=obj.map->find(attr);
            if(it!=obj.map->end()){
                VMVal& v=it->second;
                // Property descriptor: {__is_property__: true, __get__: func}
                if(v.type==VMType::MAP&&v.map&&v.map->count("__is_property__")){
                    auto git=v.map->find("__get__");
                    if(git!=v.map->end()&&git->second.type==VMType::FUNCTION){
                        std::vector<VMVal> no_args;
                        return exec_code(git->second.code, no_args, obj);
                    }
                }
                return v;
            }
        }
        // Method lookup via class registry — also check for property descriptors in class
        if(obj.type==VMType::INSTANCE){
            std::string cls=obj.class_name;
            while(!cls.empty()){
                auto cit=class_reg_.find(cls);
                if(cit==class_reg_.end()) break;
                for(auto& sub:cit->second->sub_codes){
                    if(sub->name==attr&&!sub->is_class){
                        // Carry the instance with the method. Returning a bare
                        // function meant `var f = obj.m` lost `self`, so calling
                        // f later shifted every argument left — the same defect
                        // the interpreter had (round 4). Reuses the existing
                        // __super_bound__ convention that vm_call understands.
                        VMVal bound=VMVal::make_map();
                        bound.class_name="__bound_method__";
                        (*bound.map)["__fn__"]=VMVal::make_func(sub);
                        (*bound.map)["__self__"]=obj;
                        return bound;
                    }
                }
                cls=cit->second->parent_class;
            }
        }
        if(obj.type==VMType::STRING) return str_method(obj,attr);
        if(obj.type==VMType::LIST)   return list_method(obj,attr);
        // CLASS type: look for nested classes and class-level vars in class_vars_
        if(obj.type==VMType::CLASS){
            std::string cname = obj.class_name.empty() ? obj.s : obj.class_name;
            // Check class_vars_ (class-level variables)
            auto cit = class_vars_.find(cname);
            if(cit != class_vars_.end()){
                auto vit = cit->second.find(attr);
                if(vit != cit->second.end()) return vit->second;
            }
            // Check sub-codes for nested class or static method
            auto rit = class_reg_.find(cname);
            if(rit != class_reg_.end()){
                for(auto& sub: rit->second->sub_codes){
                    if(sub->name == attr && sub->is_class){
                        // Return nested class as a CLASS VMVal
                        VMVal cv; cv.type=VMType::CLASS; cv.class_name=attr; cv.code=sub;
                        return cv;
                    }
                    if(sub->name == attr && !sub->is_class){
                        return VMVal::make_func(sub);
                    }
                }
            }
        }
        return VMVal::make_none();
    }
    void set_attr(VMVal& obj, const std::string& attr, VMVal val) {
        if((obj.type==VMType::INSTANCE||obj.type==VMType::MAP)&&obj.map){
            auto it=obj.map->find(attr);
            if(it!=obj.map->end()){
                VMVal& v=it->second;
                if(v.type==VMType::MAP&&v.map&&v.map->count("__is_property__")){
                    auto sit=v.map->find("__set__");
                    if(sit!=v.map->end()&&sit->second.type==VMType::FUNCTION){
                        std::vector<VMVal> args={val};
                        exec_code(sit->second.code, args, obj);
                        return;
                    }
                }
            }
            (*obj.map)[attr]=std::move(val);
        }
        // CLASS type: update class_vars_
        if(obj.type==VMType::CLASS){
            std::string cname = obj.class_name.empty() ? obj.s : obj.class_name;
            class_vars_[cname][attr] = std::move(val);
        }
    }
    // Resolve a [start,end,step] slice against a sequence of length sz,
    // returning the indices to take in order. NONE start/end mean "the natural
    // end for this direction", which differs by the sign of the step.
    static std::vector<int64_t> slice_indices(const std::vector<VMVal>& sl, int64_t sz) {
        auto num=[](const VMVal& v)->int64_t{
            return v.type==VMType::INT?v.i:(int64_t)to_d(v); };
        int64_t step = sl.size()>=3 ? num(sl[2]) : 1;
        if(step==0) step=1;                       // step 0 would never terminate
        bool no_s = sl[0].type==VMType::NONE, no_e = sl[1].type==VMType::NONE;
        int64_t s,e;
        if(step>0){
            s = no_s ? 0  : num(sl[0]);
            e = no_e ? sz : num(sl[1]);
            if(s<0) s+=sz; if(e<0) e+=sz;
            s=std::max((int64_t)0,std::min(s,sz));
            e=std::max((int64_t)0,std::min(e,sz));
        } else {
            // The parser substitutes a literal 0 for an omitted start, so an
            // absent start is indistinguishable from an explicit [0:...] here.
            // The interpreter resolves that with a heuristic — start 0 together
            // with an omitted end means "from the far end" — and this mirrors it
            // so both engines agree. It does mean L[0::-1] yields the whole
            // reversed sequence rather than just element 0, on both engines.
            e = no_e ? -1 : num(sl[1]);
            if(no_s || (sl[0].type==VMType::INT && sl[0].i==0 && no_e)) s = sz-1;
            else { s = num(sl[0]); if(s<0) s+=sz; }
            if(e<0&&!no_e) e+=sz;
            s=std::max((int64_t)-1,std::min(s,sz-1));
            e=std::max((int64_t)-1,std::min(e,sz));
        }
        std::vector<int64_t> out;
        if(step>0) for(int64_t i=s;i<e;i+=step) out.push_back(i);
        else       for(int64_t i=s;i>e;i+=step) out.push_back(i);
        return out;
    }
    VMVal get_sub(const VMVal& obj, const VMVal& idx) {
        if(obj.type==VMType::LIST&&obj.list){
            if(idx.type==VMType::LIST&&idx.list&&idx.list->size()==3){
                std::vector<VMVal> out;
                for(int64_t i:slice_indices(*idx.list,(int64_t)obj.list->size()))
                    out.push_back((*obj.list)[(size_t)i]);
                return VMVal::make_list(std::move(out));
            }
            // Slice: idx is a LIST [start, end]
            if(idx.type==VMType::LIST&&idx.list&&idx.list->size()==2){
                int64_t sz=(int64_t)obj.list->size();
                int64_t s=(*idx.list)[0].type==VMType::INT?(*idx.list)[0].i:(int64_t)to_d((*idx.list)[0]);
                int64_t e=(*idx.list)[1].type==VMType::INT?(*idx.list)[1].i:(int64_t)to_d((*idx.list)[1]);
                if(s<0) s+=sz; if(e<0) e+=sz;
                if(e==-1||e>sz) e=sz;
                s=std::max((int64_t)0,std::min(s,sz));
                e=std::max(s,std::min(e,sz));
                std::vector<VMVal> slice;
                for(int64_t i=s;i<e;i++) slice.push_back((*obj.list)[(size_t)i]);
                return VMVal::make_list(std::move(slice));
            }
            int64_t i=idx.type==VMType::INT?idx.i:(int64_t)to_d(idx);
            if(i<0) i+=(int64_t)obj.list->size();
            if(i>=0&&i<(int64_t)obj.list->size()) return (*obj.list)[(size_t)i];
            return VMVal::make_none();
        }
        if(obj.type==VMType::MAP&&obj.map){
            auto it=obj.map->find(idx.to_string());
            return it!=obj.map->end()?it->second:VMVal::make_none();
        }
        if(obj.type==VMType::STRING){
            if(idx.type==VMType::LIST&&idx.list&&idx.list->size()==3){
                std::string out;
                for(int64_t i:slice_indices(*idx.list,(int64_t)obj.s.size()))
                    out+=obj.s[(size_t)i];
                return VMVal::make_str(out);
            }
            if(idx.type==VMType::LIST&&idx.list&&idx.list->size()==2){
                int64_t sz=(int64_t)obj.s.size();
                int64_t s=(*idx.list)[0].type==VMType::INT?(*idx.list)[0].i:(int64_t)to_d((*idx.list)[0]);
                int64_t e=(*idx.list)[1].type==VMType::INT?(*idx.list)[1].i:(int64_t)to_d((*idx.list)[1]);
                if(s<0) s+=sz; if(e<0) e+=sz;
                if(e==-1||e>sz) e=sz;
                s=std::max((int64_t)0,std::min(s,sz));
                e=std::max(s,std::min(e,sz));
                return VMVal::make_str(obj.s.substr((size_t)s,(size_t)(e-s)));
            }
            if(idx.type==VMType::INT){
                int64_t i=idx.i;
                if(i<0) i+=(int64_t)obj.s.size();
                if(i>=0&&i<(int64_t)obj.s.size())
                    return VMVal::make_str(std::string(1,obj.s[(size_t)i]));
            }
        }
        return VMVal::make_none();
    }
    void set_sub(VMVal& obj, const VMVal& idx, VMVal val) {
        if(obj.type==VMType::LIST&&obj.list){
            // Slice assignment: idx is [start, end], val should be a list
            if(idx.type==VMType::LIST&&idx.list&&idx.list->size()==2){
                int64_t sz=(int64_t)obj.list->size();
                int64_t s=(*idx.list)[0].type==VMType::INT?(*idx.list)[0].i:(int64_t)to_d((*idx.list)[0]);
                int64_t e=(*idx.list)[1].type==VMType::INT?(*idx.list)[1].i:(int64_t)to_d((*idx.list)[1]);
                if(s<0) s+=sz; if(e<0) e+=sz;
                if(e==-1||e>sz) e=sz;
                s=std::max((int64_t)0,std::min(s,sz));
                e=std::max(s,std::min(e,sz));
                std::vector<VMVal>* src=nullptr;
                std::vector<VMVal> single_wrap;
                if(val.type==VMType::LIST&&val.list) src=val.list.get();
                else { single_wrap.push_back(std::move(val)); src=&single_wrap; }
                // Replace elements s..e with src contents
                auto it_start=obj.list->begin()+s;
                auto it_end=obj.list->begin()+e;
                obj.list->erase(it_start,it_end);
                for(size_t k=0;k<src->size();k++)
                    obj.list->insert(obj.list->begin()+s+k, (*src)[k]);
                return;
            }
            int64_t i=idx.type==VMType::INT?idx.i:(int64_t)to_d(idx);
            if(i<0) i+=(int64_t)obj.list->size();
            if(i==(int64_t)obj.list->size()){
                obj.list->push_back(std::move(val)); // append on exact boundary
            } else if(i>=(int64_t)obj.list->size()){
                // grow to fit
                obj.list->resize((size_t)i+1, VMVal::make_none());
                (*obj.list)[(size_t)i]=std::move(val);
            } else if(i>=0){
                (*obj.list)[(size_t)i]=std::move(val);
            }
        } else if(obj.type==VMType::MAP&&obj.map) {
            (*obj.map)[idx.to_string()]=std::move(val);
        }
    }

    // ── Function / method call ──────────────────────────────────────────
    // Name pushed by the LOAD_NAME/LOAD_GLOBAL that produced the callee for the
    // CALL_FUNCTION at `ip`. Scans back past the argument-producing
    // instructions rather than assuming a fixed offset.
    std::string calleeNameBefore(CallFrame& fr, int ip) {
        if(!fr.code) return std::string();
        if(ip < 0 || ip >= (int)fr.code->instructions.size()) return std::string();
        int argc = fr.code->instructions[ip].arg;
        int seen = 0;
        for(int k = ip - 1; k >= 0 && k > ip - 64; --k){
            const auto& pi = fr.code->instructions[k];
            if(pi.op==Op::LOAD_NAME){
                if(seen >= argc){
                    if(pi.arg >= 0 && pi.arg < (int)fr.code->names.size())
                        return fr.code->names[pi.arg];
                    return std::string();
                }
                seen++;
            } else if(pi.op==Op::LOAD_CONST){
                seen++;
            }
        }
        return std::string();
    }

    VMVal vm_call(VMVal callee, std::vector<VMVal>& args, std::optional<VMVal> self) {
        if(callee.type==VMType::NONE||callee.type==VMType::UNDEFINED)
            return VMVal::make_none();
        // __call__: instance used as callable
        if(callee.type==VMType::INSTANCE){
            VMVal r=call_dunder(callee,"__call__",args);
            return r;
        }
        // __super_bound__: bound method from super() proxy
        if(callee.type==VMType::MAP&&callee.class_name=="__bound_method__"&&callee.map){
            auto& bm=*callee.map;
            VMVal fn=bm.count("__fn__")?bm["__fn__"]:VMVal::make_none();
            VMVal sv=bm.count("__self__")?bm["__self__"]:VMVal::make_none();
            if(fn.type==VMType::FUNCTION&&fn.code) return exec_code(fn.code,args,sv);
            return VMVal::make_none();
        }
        if(callee.type==VMType::MAP&&callee.class_name=="__super_bound__"&&callee.map){
            auto& m=*callee.map;
            VMVal fn=m.count("__fn__")?m["__fn__"]:VMVal::make_none();
            VMVal sv=m.count("__self__")?m["__self__"]:VMVal::make_none();
            if(fn.type==VMType::FUNCTION&&fn.code)
                return exec_code(fn.code,args,sv);
            return VMVal::make_none();
        }
        // SUPER_PROXY called directly as super() → return itself
        if(callee.type==VMType::SUPER_PROXY) return callee;
        if(callee.type==VMType::NATIVE) return callee.native(args);
        if(callee.type==VMType::FUNCTION&&callee.code&&callee.code->has_yield()){
            // Generator function: collect all yielded values into a list
            std::vector<VMVal> yielded;
            std::vector<VMVal> gen_args=args;
            // Apply self-extraction if needed
            std::optional<VMVal> gen_self=self;
            if(!gen_self&&!gen_args.empty()&&!callee.code->param_names.empty()
               &&callee.code->param_names[0]=="self"
               &&(gen_args[0].type==VMType::INSTANCE||gen_args[0].type==VMType::MAP)){
                gen_self=gen_args[0];
                gen_args=std::vector<VMVal>(gen_args.begin()+1,gen_args.end());}
            // Return a lazy generator (coroutine-style)
            return make_generator_val(callee.code, gen_args, gen_self, callee.closure_env);
        }
        if(callee.type==VMType::FUNCTION&&callee.code){
            // If no explicit self but first param is "self" and first arg is an instance,
            // extract self from args (e.g. Animal.__init__(self, name) pattern)
            if(!self && !args.empty() && !callee.code->param_names.empty()
               && callee.code->param_names[0]=="self"
               && (args[0].type==VMType::INSTANCE||args[0].type==VMType::MAP)) {
                VMVal self_val = args[0];
                std::vector<VMVal> rest(args.begin()+1, args.end());
                return exec_code(callee.code, rest, self_val, callee.closure_env);
            }
            return exec_code(callee.code,args,self,callee.closure_env);
        }
        if(callee.type==VMType::CLASS&&callee.code){
            auto attrs=std::make_shared<std::unordered_map<std::string,VMVal>>();
            VMVal inst=VMVal::make_instance(callee.class_name,attrs);
            if(!class_reg_.count(callee.class_name)) class_reg_[callee.class_name]=callee.code;
            {
                // Find __init__ in class hierarchy
                std::string search_cls=callee.class_name;
                bool found_init=false;
                while(!search_cls.empty()&&!found_init){
                    auto cit=class_reg_.find(search_cls);
                    if(cit==class_reg_.end()){
                        // Try callee.code if it's this class:
                        if(search_cls==callee.class_name){
                            for(auto& sub:callee.code->sub_codes)
                                if(is_ctor_name(sub->name)&&!sub->is_class){exec_code(sub,args,inst);found_init=true;break;}
                        }
                        break;
                    }
                    for(auto& sub:cit->second->sub_codes)
                        if(is_ctor_name(sub->name)&&!sub->is_class){exec_code(sub,args,inst);found_init=true;break;}
                    if(!found_init) search_cls=cit->second->parent_class;
                }
                if(!found_init){
                    // Fallback: search callee.code->sub_codes directly:
                    for(auto& sub:callee.code->sub_codes)
                        if(is_ctor_name(sub->name)&&!sub->is_class){exec_code(sub,args,inst);break;}
                }
            }
            return inst;
        }
        return VMVal::make_none();
    }
    // The interpreter accepts either `init` or `__init__` as the constructor
    // (three call sites in NythonExecutor.hpp test both). The VM matched only
    // `__init__`, so a class written with `def init(self, ...)` — the spelling
    // used by ~190 of the bundled examples — silently constructed an instance
    // with no fields set: attributes read back as none, not an error.
    static bool is_ctor_name(const std::string& n) {
        return n=="__init__" || n=="init";
    }
    VMVal vm_call_method(VMVal obj, const std::string& method, std::vector<VMVal>& args) {
        // SUPER_PROXY: call method on parent class with self
        if(obj.type==VMType::SUPER_PROXY){
            std::string parent=obj.s;
            VMVal self_v=(!obj.list||obj.list->empty())?VMVal::make_none():(*obj.list)[0];
            std::string cls=parent;
            while(!cls.empty()){
                auto cit=class_reg_.find(cls);
                if(cit==class_reg_.end()) break;
                for(auto& sub:cit->second->sub_codes)
                    if(sub->name==method&&!sub->is_class) return exec_code(sub,args,self_v);
                cls=cit->second->parent_class;
            }
            return VMVal::make_none();
        }
        if((obj.type==VMType::INSTANCE||obj.type==VMType::MAP)&&obj.map){
            auto it=obj.map->find(method);
            if(it!=obj.map->end()){
                VMVal& held=it->second;
                // A callable stored in an attribute, e.g. self.cb = other.method
                // then self.cb(a, b). A bound method carries its own instance,
                // so it must go through vm_call rather than being re-bound to
                // the object that happens to hold it; natives take no self at
                // all. Only a bare FUNCTION keeps the historical behaviour of
                // being treated as a method of this object.
                if(held.type==VMType::MAP&&held.class_name=="__bound_method__")
                    return vm_call(held,args,std::nullopt);
                if(held.type==VMType::NATIVE)
                    return vm_call(held,args,std::nullopt);
                if(held.type==VMType::FUNCTION)
                    return exec_code(held.code,args,obj);
            }
        }
        if(obj.type==VMType::INSTANCE){
            std::string cls=obj.class_name;
            while(!cls.empty()){
                auto cit=class_reg_.find(cls);
                if(cit==class_reg_.end()) break;
                for(auto& sub:cit->second->sub_codes)
                    if(sub->name==method&&!sub->is_class) return exec_code(sub,args,obj);
                cls=cit->second->parent_class;
            }
            // Universal object protocol — mirrors NythonExecutor::objectProtocol
            // on the interpreter (see test_25_object_protocol.ny, which probes
            // for support and skipped here because the VM had none of this).
            // Only reached once no user-defined method/attribute of this name
            // was found above, so a class's own to_string/class_name etc, if
            // it defines one, still wins.
            if(method=="class_name"||method=="type_name")
                return VMVal::make_str(obj.class_name);
            if(method=="to_string"||method=="str")
                return VMVal::make_str("<"+obj.class_name+" instance>");
            if(method=="id"){
                uintptr_t raw=obj.map?(uintptr_t)obj.map.get():0;
                return VMVal::make_int((int64_t)(raw & 0x7fffffffffffffffULL));
            }
            if(method=="hash"){
                uintptr_t raw=obj.map?(uintptr_t)obj.map.get():0;
                uint64_t h=std::hash<std::string>{}(obj.class_name+"|"+std::to_string(raw));
                return VMVal::make_int((int64_t)(h & 0x7fffffffffffffffULL));
            }
            if(method=="is_a"||method=="instance_of"){
                if(args.empty()) return VMVal::make_bool(false);
                std::string want=args[0].to_string();
                std::string cur=obj.class_name;
                int guard=0;
                while(!cur.empty()&&guard++<64){
                    if(cur==want) return VMVal::make_bool(true);
                    auto cit=class_reg_.find(cur);
                    if(cit==class_reg_.end()) break;
                    cur=cit->second->parent_class;
                }
                return VMVal::make_bool(false);
            }
            if(method=="equals_to"||method=="same_as"){
                if(args.empty()||args[0].type!=VMType::INSTANCE) return VMVal::make_bool(false);
                return VMVal::make_bool(obj.map.get()==args[0].map.get());
            }
            if(method=="fields"||method=="attributes"){
                std::vector<VMVal> r;
                if(obj.map) for(auto& kv:*obj.map) r.push_back(VMVal::make_str(kv.first));
                return VMVal::make_list(std::move(r));
            }
        }
        // CLASS.method(self, args...) — parent class method call pattern
        // e.g. Animal.__init__(self, name) → args[0] is the instance, args[1:] are method args
        if(obj.type==VMType::CLASS&&obj.code){
            for(auto& sub:obj.code->sub_codes){
                if(sub->name==method&&!sub->is_class){
                    // Extract self from first arg if args[0] is an instance
                    if(!args.empty()&&(args[0].type==VMType::INSTANCE||args[0].type==VMType::MAP)){
                        VMVal self_val=args[0];
                        std::vector<VMVal> rest(args.begin()+1,args.end());
                        return exec_code(sub,rest,self_val);
                    }
                    return exec_code(sub,args,std::nullopt);
                }
            }
        }
        if(obj.type==VMType::STRING) return call_str_method(obj,method,args);
        if(obj.type==VMType::LIST)   return call_list_method(obj,method,args);
        if(obj.type==VMType::MAP){
            // A map member that is itself callable — a class or function held in
            // a namespace, as `import "m" as ns` produces — must be CALLED, not
            // treated as a dictionary operation. Without this, ns.SomeClass(9)
            // fell through to call_map_method, found no map method of that name
            // and returned none, while `var c = ns.SomeClass` then `c(9)`
            // worked: the same call spelled two ways behaved differently.
            if(obj.map){
                auto mit=obj.map->find(method);
                if(mit!=obj.map->end()){
                    const VMVal& member=mit->second;
                    if(member.type==VMType::CLASS||member.type==VMType::FUNCTION
                       ||member.type==VMType::NATIVE)
                        return vm_call(member,args,std::nullopt);
                }
            }
            return call_map_method(obj,method,args);
        }
        // CLASS type: support nested class instantiation via CALL_METHOD (e.g. Outer.Inner(v))
        if(obj.type==VMType::CLASS){
            VMVal nested = get_attr(obj, method);
            if(nested.type == VMType::CLASS) return vm_call(nested, args, std::nullopt);
            // Static method call
            if(nested.type == VMType::FUNCTION && nested.code)
                return exec_code(nested.code, args, VMVal::make_none());
        }
        // Fallback: check globals
        auto git=globals_.find(method);
        if(git!=globals_.end()&&git->second.type==VMType::NATIVE)
            return git->second.native(args);
        return VMVal::make_none();
    }

    VMVal call_map_method(VMVal obj, const std::string& m, std::vector<VMVal>& a) {
        if(!obj.map) return VMVal::make_none();
        auto& mp=*obj.map;
        // size()/length() on a map returned none; the interpreter reports the
        // entry count.
        if(m=="size"||m=="length") return VMVal::make_int((int64_t)mp.size());
        if(m=="keys") {
            std::vector<VMVal> r;
            for(auto& [k,v]:mp) r.push_back(VMVal::make_str(k));
            return VMVal::make_list(std::move(r));
        }
        if(m=="values") {
            std::vector<VMVal> r;
            for(auto& [k,v]:mp) r.push_back(v);
            return VMVal::make_list(std::move(r));
        }
        if(m=="items") {
            std::vector<VMVal> r;
            for(auto& [k,v]:mp){
                std::vector<VMVal> pair={VMVal::make_str(k),v};
                r.push_back(VMVal::make_list(std::move(pair)));}
            return VMVal::make_list(std::move(r));
        }
        if(m=="get") {
            std::string key=a.empty()?"":a[0].to_string();
            auto it=mp.find(key);
            if(it!=mp.end()) return it->second;
            return a.size()>=2?a[1]:VMVal::make_none();
        }
        if(m=="has"||m=="contains"||m=="has_key") {
            std::string key=a.empty()?"":a[0].to_string();
            return VMVal::make_bool(mp.count(key)>0);
        }
        // "remove"/"delete" are the names the interpreter uses for erase-by-key;
        // the VM only had "pop", so map.remove(k) silently returned none and
        // left the key in place.
        if(m=="pop"||m=="remove"||m=="delete") {
            if(a.empty()) return VMVal::make_none();
            std::string key=a[0].to_string();
            auto it=mp.find(key);
            if(it==mp.end()) return a.size()>=2?a[1]:VMVal::make_none();
            VMVal v=it->second; mp.erase(it); return v;
        }
        if(m=="update") {
            if(!a.empty()&&a[0].type==VMType::MAP&&a[0].map)
                for(auto& [k,v]:*a[0].map) mp[k]=v;
            return VMVal::make_none();
        }
        if(m=="clear") { mp.clear(); return VMVal::make_none(); }
        if(m=="copy") { return obj; }
        if(m=="setdefault") {
            if(a.empty()) return VMVal::make_none();
            std::string key=a[0].to_string();
            if(!mp.count(key)) mp[key]=a.size()>=2?a[1]:VMVal::make_none();
            return mp[key];
        }
        return VMVal::make_none();
    }


    // ── Import system ───────────────────────────────────────────────────────
    void vm_import(const std::string& raw_name_in) {
        std::string tried_paths;
        // Split the alias the compiler appended, if any.
        std::string raw_name = raw_name_in;
        std::string alias;
        size_t sep = raw_name.find('\x01');
        if(sep != std::string::npos){
            alias = raw_name.substr(sep + 1);
            raw_name = raw_name.substr(0, sep);
        }
        std::string name = raw_name;
        if(name.size()>=2&&(name[0]=='"'||name[0]=='\'')){
            name=name.substr(1,name.size()-2);
        }
        std::string guard_key = "__imported_"+name;
        // An aliased import must still run so its namespace can be built, even
        // if the module was already loaded — otherwise the name diff sees
        // nothing and the alias is empty. Matches the interpreter.
        if(globals_.count(guard_key) && alias.empty()) return;
        globals_[guard_key] = VMVal::make_bool(true);
        if(name=="nytorch"){ register_nytorch_builtins(); return; }
        // "nytorch_classes" used to sit in builtin_modules below - a no-op
        // acknowledgement, on the theory its functions were "already
        // registered as globals". That's true of the native tensor_* ops
        // (register_nytorch_builtins), but the class library itself
        // (Tensor, and everything built on it, in lib/nytorch.ny) was never
        // actually loaded, so `Tensor(...)` read as an undefined name on
        // this engine while the interpreter's own `nytorch_classes` handler
        // (NythonExecutor.hpp) really does load lib/nytorch.ny. Falling
        // through to the normal file-import path below (via filepath) does
        // the same here; the VM's shared_ptr-backed containers don't have
        // the interpreter's container-leak problem that made loading this
        // 220+-class file risky there (see GC_NOTES.md).
        if(name=="nytorch_classes"){ register_nytorch_builtins(); }
        if(name=="os"||name=="shell"||name=="sh"){ register_os_builtins(); return; }
        if(name=="math"){ register_math_builtins(); return; }
        if(name=="time"){ register_time_builtins(); return; }
        if(name=="json"){ register_json_builtins(); return; }
        if(name=="io"||name=="fs"||name=="file"){ register_io_builtins(); return; }
        if(name=="string"){
            globals_["isdigit_str"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
                return VMVal::make_bool(!a.empty()&&!a[0].s.empty()&&std::all_of(a[0].s.begin(),a[0].s.end(),::isdigit));});
            globals_["isalpha_str"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
                return VMVal::make_bool(!a.empty()&&!a[0].s.empty()&&std::all_of(a[0].s.begin(),a[0].s.end(),::isalpha));});
            return;
        }
        // Builtin module names that resolve to no file. The interpreter knows
        // 40 of these; the VM knew 14, so `import random` reached the file
        // lookup and — once that started reporting failures instead of
        // returning silently — became a hard error on one engine only. The
        // functions themselves are already registered as globals; the import is
        // just an acknowledgement.
        static const std::set<std::string> builtin_modules = {
            "random","collections","crypto","datetime","hash","http","re","regex",
            "sys","ml","ai","net","agent_net","threading",
            "thread","threads","threading_lib","string","math","time","json",
            "io","fs","file","os","sh","shell","gui","stdlib","oslib","os_lib",
            "netlib","network_lib","sockets","webserver","httpserver",
            "clientserver","cs_lib","aiagent","nyxai","nyx","nytorch"
        };

        static const std::unordered_map<std::string,std::string> lib_map = {
            {"stdlib","lib/stdlib.ny"},{"oslib","lib/os.ny"},{"os_lib","lib/os.ny"},
            {"network_lib","lib/network.ny"},{"netlib","lib/network.ny"},
            {"sockets","lib/sockets.ny"},{"webserver","lib/webserver.ny"},
            {"httpserver","lib/webserver.ny"},{"threads","lib/thread.ny"},
            {"threading_lib","lib/thread.ny"},{"clientserver","lib/clientserver.ny"},
            {"cs_lib","lib/clientserver.ny"},{"gui","lib/gui.ny"},
            {"aiagent","lib/aiagent.ny"},{"nyxai","lib/aiagent.ny"},{"nyx","lib/aiagent.ny"},
            {"nytorch_classes","lib/nytorch.ny"},
        };
        std::string filepath;
        auto it=lib_map.find(name);
        if(it!=lib_map.end()) filepath=it->second;
        if(filepath.empty()){
            std::vector<std::string> paths={
                // The importing script's own directory first, matching the
                // interpreter. Without it `import "mylib"` resolved on one
                // engine and not the other — the same file, the same import,
                // two different answers.
                script_dir_+name+".ny", script_dir_+name, script_dir_+"lib/"+name+".ny",
                name+".ny",name,"./"+name+".ny",
                cwd_+"/"+name+".ny","lib/"+name+".ny","./lib/"+name+".ny",
                cwd_+"/lib/"+name+".ny",
            };
            for(auto& p:paths){struct stat st;if(::stat(p.c_str(),&st)==0){filepath=p;break;}}
            // Kept for the error message below; `paths` goes out of scope here.
            for(size_t i=0;i<paths.size();++i){ if(i) tried_paths+=", "; tried_paths+=paths[i]; }
        }
        // A module that cannot be found used to return silently, so every name
        // it would have defined failed later with no hint that the import was
        // the cause. Matches the interpreter's ImportError, including the list
        // of paths tried — the two engines must agree on what is an error.
        if(filepath.empty()){
            // A builtin module has no file and that is not an error.
            if(builtin_modules.count(name)) return;
            // std::runtime_error, not std::string: the VM's try/except handler
            // catches what Op::RAISE throws, which is runtime_error. Throwing a
            // std::string unwound straight out of run_loop, so an import error
            // was uncatchable on this engine while the interpreter caught it.
            throw std::runtime_error("__exc__:ImportError:cannot find module \"" + raw_name
                                     + "\" (looked in: " + tried_paths + ")");
        }
        try {
            auto source=nython::reader::SourceCode(filepath);
            auto reporter=std::make_shared<nython::exception::Reporter>(source);
            auto lx=std::make_shared<nython::lexer::Lexer>(source);
            lx->tokenize();
            auto pr=std::make_shared<nython::parser::Parser>(reporter.get(),(nython::Runnable*)this,lx.get());
            auto ast=pr->parse();
            if(!ast) return;
            Compiler c; auto code=c.compile(ast);
            bool old_exp=export_to_globals_; export_to_globals_=true;
            // Snapshot the global names so the alias namespace can be built from
            // whatever the module adds, matching the interpreter.
            // The module's OWN top-level names, read from its AST. Diffing
            // globals_ before and after fails when the module was already
            // loaded — `import "m"` then `import "m" as x` adds nothing new, so
            // the namespace came out empty. Reading declarations directly is
            // independent of what is already defined.
            std::set<std::string> own_names;
            if(!alias.empty() && ast){
                for(auto& st : ast->statements()){
                    if(!st) continue;
                    if(st->type()==nython::node::NodeType::FUNCTION)
                        own_names.insert(std::static_pointer_cast<nython::node::FunctionNode>(st)->name);
                    else if(st->type()==nython::node::NodeType::CLASS)
                        own_names.insert(std::static_pointer_cast<nython::node::ClassNode>(st)->name);
                    else if(st->type()==nython::node::NodeType::VARIABLE_DECL)
                        own_names.insert(std::static_pointer_cast<nython::node::VarDeclNode>(st)->name);
                }
            }
            try{ exec_code(code,{},std::nullopt); } catch(VMReturn&){}
              catch(std::exception& e){ std::cerr<<"[VM import error] "<<filepath<<": "<<e.what()<<"\n"; }
            export_to_globals_=old_exp;
            if(!alias.empty()){
                auto ns=std::make_shared<std::unordered_map<std::string,VMVal>>();
                for(const auto& n : own_names){
                    auto it=globals_.find(n);
                    if(it!=globals_.end()){ (*ns)[n]=it->second; continue; }
                    // Classes are not ordinary globals on this engine: they live
                    // in class_reg_. Without this the alias exposed a module's
                    // functions and vars but silently omitted its classes.
                    auto cit=class_reg_.find(n);
                    if(cit!=class_reg_.end()){
                        VMVal cv=VMVal::make_class(cit->second, n);
                        (*ns)[n]=cv;
                    }
                }
                VMVal nsv=VMVal::make_map();
                nsv.map=ns;
                nsv.class_name=alias;
                globals_[alias]=nsv;
            }
            // Register classes from the imported module
            for(auto& sub:code->sub_codes) {
                if(sub->is_class) { class_reg_[sub->name]=sub; }
                else {
                    // Functions defined at module level are already in globals_ via DEFINE_NAME
                    // But their code objects need to be in class_reg for method dispatch
                    // Sub-codes of the module that are classes (nested under functions) need registration
                    for(auto& ssub:sub->sub_codes) if(ssub->is_class) class_reg_[ssub->name]=ssub;
                }
            }

        } catch(std::exception& e){ std::cerr<<"[VM import parse error] "<<name<<": "<<e.what()<<"\n"; }
    }

    // Safe list accessor for the tensor builtins.
    //
    // Several of them guarded only a[0] and then dereferenced a[1].list. When an
    // argument was none — which happens whenever an earlier tensor call returned
    // none, e.g. a builtin the VM does not implement — that was a null
    // dereference and the process segfaulted. Returning an empty list makes the
    // operation degrade instead of crashing.
    static std::vector<VMVal>& vm_arg_list(std::vector<VMVal>& a, size_t i) {
        static std::vector<VMVal> s_empty;
        if(i < a.size() && a[i].type == VMType::LIST && a[i].list) return *a[i].list;
        s_empty.clear();
        return s_empty;
    }

    void register_nytorch_builtins() {
        globals_["tensor"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return a.empty()?VMVal::make_list():a[0];});
        globals_["zeros"]=globals_["tensor_zeros"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=a.empty()?0:(a[0].type==VMType::INT?a[0].i:(int64_t)a[0].d);
            std::vector<VMVal> v;for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float(0.0));return VMVal::make_list(std::move(v));});
        globals_["ones"]=globals_["tensor_ones"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=a.empty()?0:(a[0].type==VMType::INT?a[0].i:(int64_t)a[0].d);
            std::vector<VMVal> v;for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float(1.0));return VMVal::make_list(std::move(v));});
        globals_["exp"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::exp(to_d(a.empty()?VMVal::make_int(0):a[0])));});
        globals_["log"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::log(to_d(a.empty()?VMVal::make_int(1):a[0])));});
        // These four read a[0] with no arity check, so sin()/cos()/tan()/tanh()
        // with no argument indexed past the end of an empty vector. VMVal holds
        // a std::string, so the garbage read faulted rather than returning junk:
        // a hard segfault of the VM. Their neighbours (exp, log, relu, sigmoid,
        // atan2) all guard, so this was an oversight, not a convention.
        globals_["sin"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::sin(a.empty()?0.0:to_d(a[0])));});
        globals_["cos"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::cos(a.empty()?0.0:to_d(a[0])));});
        globals_["tan"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::tan(a.empty()?0.0:to_d(a[0])));});
        globals_["tanh"]=globals_["tanh_fn"]=globals_["tanh_act"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::tanh(a.empty()?0.0:to_d(a[0])));});
        globals_["atan2"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{double y=a.size()>0?to_d(a[0]):0,x=a.size()>1?to_d(a[1]):1;return VMVal::make_float(std::atan2(y,x));});
        globals_["relu"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{double v=to_d(a.empty()?VMVal::make_int(0):a[0]);return VMVal::make_float(v>0?v:0);});
        globals_["sigmoid"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{double v=to_d(a.empty()?VMVal::make_int(0):a[0]);return VMVal::make_float(1.0/(1.0+std::exp(-v)));});
        globals_["softmax"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            auto& lst=vm_arg_list(a,0);double s=0;std::vector<double> ev;
            for(auto& v:lst){double e=std::exp(to_d(v));ev.push_back(e);s+=e;}
            std::vector<VMVal> res;for(auto e:ev)res.push_back(VMVal::make_float(e/s));return VMVal::make_list(std::move(res));});
        globals_["tensor_add"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST)return VMVal::make_list();
            auto& la=vm_arg_list(a,0);auto& lb=vm_arg_list(a,1);std::vector<VMVal> r;
            for(size_t i=0;i<la.size();i++)r.push_back(VMVal::make_float(to_d(la[i])+(i<lb.size()?to_d(lb[i]):0)));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_scale"]=globals_["tensor_mul"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_list();
            auto& lst=vm_arg_list(a,0);std::vector<VMVal> r;
            if(a.size()>1&&a[1].type==VMType::LIST&&a[1].list){
                auto& lb=vm_arg_list(a,1);
                if(lb.size()==1){double sc=to_d(lb[0]);for(auto& v:lst)r.push_back(VMVal::make_float(to_d(v)*sc));}
                else{for(size_t i=0;i<lst.size();i++)r.push_back(VMVal::make_float(to_d(lst[i])*(i<lb.size()?to_d(lb[i]):1.0)));}
            } else {
                double sc=a.size()>1?to_d(a[1]):1;for(auto& v:lst)r.push_back(VMVal::make_float(to_d(v)*sc));
            }
            return VMVal::make_list(std::move(r));});
        globals_["tensor_sum"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(0.0);
            double s=0;for(auto& v:vm_arg_list(a,0))s+=to_d(v);return VMVal::make_float(s);});
        globals_["tensor_mean"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||vm_arg_list(a,0).empty())return VMVal::make_float(0.0);
            double s=0;for(auto& v:vm_arg_list(a,0))s+=to_d(v);return VMVal::make_float(s/(double)vm_arg_list(a,0).size());});
        globals_["matmul"]=globals_["tensor_matmul"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{return VMVal::make_list();});
        // Random tensors
        globals_["tensor_rand"]=globals_["rand_tensor"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=0;
            if(!a.empty()){if(a[0].type==VMType::LIST&&a[0].list&&!vm_arg_list(a,0).empty())n=(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).type==VMType::INT?(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).i:(int64_t)(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).d;
            else if(a[0].type==VMType::INT)n=a[0].i; else if(a[0].type==VMType::FLOAT)n=(int64_t)a[0].d;}
            std::vector<VMVal> v; for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float((double)rand()/(RAND_MAX)));
            return VMVal::make_list(std::move(v));});
        globals_["tensor_randn"]=globals_["randn_tensor"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=0;
            if(!a.empty()){if(a[0].type==VMType::LIST&&a[0].list&&!vm_arg_list(a,0).empty())n=(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).type==VMType::INT?(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).i:(int64_t)(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).d;
            else if(a[0].type==VMType::INT)n=a[0].i; else if(a[0].type==VMType::FLOAT)n=(int64_t)a[0].d;}
            std::vector<VMVal> v; srand((unsigned)time(nullptr));
            for(int64_t i=0;i<n;i++){double u1=(double)(rand()+1)/(RAND_MAX+1.0),u2=(double)(rand()+1)/(RAND_MAX+1.0);
            v.push_back(VMVal::make_float(sqrt(-2*log(u1))*cos(2*3.14159265358979323846*u2)));}
            return VMVal::make_list(std::move(v));});
        // Tensor manipulation
        globals_["tensor_zeros"]=globals_["zeros"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=0;
            if(!a.empty()){if(a[0].type==VMType::LIST&&a[0].list&&!vm_arg_list(a,0).empty())n=(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).type==VMType::INT?(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).i:(int64_t)(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).d;
            else if(a[0].type==VMType::INT)n=a[0].i; else if(a[0].type==VMType::FLOAT)n=(int64_t)a[0].d;}
            std::vector<VMVal> v; for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float(0.0));return VMVal::make_list(std::move(v));});
        globals_["tensor_ones"]=globals_["ones"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=0;
            if(!a.empty()){if(a[0].type==VMType::LIST&&a[0].list&&!vm_arg_list(a,0).empty())n=(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).type==VMType::INT?(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).i:(int64_t)(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).d;
            else if(a[0].type==VMType::INT)n=a[0].i; else if(a[0].type==VMType::FLOAT)n=(int64_t)a[0].d;}
            std::vector<VMVal> v; for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float(1.0));return VMVal::make_list(std::move(v));});
        globals_["tensor_exp"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(a.empty()?0:std::exp(to_d(a[0])));
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::exp(to_d(v))));return VMVal::make_list(std::move(r));});
        globals_["tensor_log"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(a.empty()?0:std::log(to_d(a[0])));
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::log(to_d(v))));return VMVal::make_list(std::move(r));});
        globals_["tensor_sqrt"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(a.empty()?0:std::sqrt(to_d(a[0])));
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::sqrt(to_d(v))));return VMVal::make_list(std::move(r));});
        globals_["tensor_abs"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(a.empty()?0:std::fabs(to_d(a[0])));
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::fabs(to_d(v))));return VMVal::make_list(std::move(r));});
        globals_["tensor_neg"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(0);
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(-to_d(v)));return VMVal::make_list(std::move(r));});
        globals_["tensor_pow"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST)return VMVal::make_float(0);
            double p=to_d(a[1]);std::vector<VMVal> r;
            for(auto& v:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::pow(to_d(v),p)));return VMVal::make_list(std::move(r));});
        globals_["tensor_sub"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2)return VMVal::make_list();
            if(a[0].type!=VMType::LIST)return VMVal::make_float(to_d(a[0])-to_d(a[1]));
            auto& la=vm_arg_list(a,0);std::vector<VMVal> r;
            if(a[1].type==VMType::LIST){auto& lb=vm_arg_list(a,1);for(size_t i=0;i<la.size();i++)r.push_back(VMVal::make_float(to_d(la[i])-(i<lb.size()?to_d(lb[i]):0)));}
            else{double s=to_d(a[1]);for(auto& v:la)r.push_back(VMVal::make_float(to_d(v)-s));}
            return VMVal::make_list(std::move(r));});
        globals_["tensor_max"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||vm_arg_list(a,0).empty())return VMVal::make_float(0);
            double m=to_d((vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()));for(auto& v:vm_arg_list(a,0))m=std::max(m,to_d(v));return VMVal::make_float(m);});
        globals_["tensor_min"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||vm_arg_list(a,0).empty())return VMVal::make_float(0);
            double m=to_d((vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()));for(auto& v:vm_arg_list(a,0))m=std::min(m,to_d(v));return VMVal::make_float(m);});
        globals_["tensor_dot"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST)return VMVal::make_float(0);
            auto& la=vm_arg_list(a,0);auto& lb=vm_arg_list(a,1);double s=0;
            for(size_t i=0;i<la.size()&&i<lb.size();i++)s+=to_d(la[i])*to_d(lb[i]);return VMVal::make_float(s);});
        globals_["tensor_concat"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST)return a.empty()?VMVal::make_list():a[0];
            auto r=std::make_shared<std::vector<VMVal>>(vm_arg_list(a,0));
            for(auto& v:vm_arg_list(a,1))r->push_back(v);VMVal res;res.type=VMType::LIST;res.list=r;return res;});
        globals_["tensor_transpose"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return a.empty()?VMVal::make_list():a[0];});
        globals_["logsumexp"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||vm_arg_list(a,0).empty())return VMVal::make_float(0);
            double m=to_d((vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()));for(auto& v:vm_arg_list(a,0))m=std::max(m,to_d(v));
            double s=0;for(auto& v:vm_arg_list(a,0))s+=std::exp(to_d(v)-m);return VMVal::make_float(m+std::log(s));});
        globals_["tensor_cumprod"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_list();
            std::vector<VMVal> r;double p=1;for(auto& v:vm_arg_list(a,0)){p*=to_d(v);r.push_back(VMVal::make_float(p));}return VMVal::make_list(std::move(r));});
        globals_["tensor_sign"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST)return VMVal::make_float(0);
            std::vector<VMVal> r;for(auto& v:vm_arg_list(a,0)){double d=to_d(v);r.push_back(VMVal::make_float(d>0?1:d<0?-1:0));}return VMVal::make_list(std::move(r));});
        globals_["tensor_scatter_add"]=globals_["tensor_gather"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{return VMVal::make_list();});
        globals_["leaky_relu"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            double x=to_d(a.empty()?VMVal::make_int(0):a[0]);double alpha=a.size()>1?to_d(a[1]):0.01;return VMVal::make_float(x>0?x:alpha*x);});
        globals_["tensor_apply"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||!a[0].list)return a.empty()?VMVal::make_list():a[0];
            std::vector<VMVal> r;
            for(auto& v:vm_arg_list(a,0)){
                std::vector<VMVal> args={v};
                if(a[1].type==VMType::NATIVE)r.push_back(a[1].native(args));
                else if(a[1].type==VMType::FUNCTION&&a[1].code)
                    r.push_back(this->vm_call(a[1],args,std::nullopt));
                else r.push_back(v);
            }
            return VMVal::make_list(std::move(r));});

        // ── conv1d(input, kernel) ─────────────────────────────────────────────
        globals_["conv1d"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_list();
            auto& inp=vm_arg_list(a,0); auto& ker=vm_arg_list(a,1);
            int ilen=(int)inp.size(),klen=(int)ker.size(),olen=ilen-klen+1;
            if(olen<=0){std::vector<VMVal> r;r.push_back(VMVal::make_float(0.0));return VMVal::make_list(std::move(r));}
            std::vector<VMVal> out;
            for(int i=0;i<olen;i++){double s=0;for(int k=0;k<klen;k++)s+=to_d(inp[i+k])*to_d(ker[k]);out.push_back(VMVal::make_float(s));}
            return VMVal::make_list(std::move(out));});
        globals_["max_pool1d"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            auto& inp=vm_arg_list(a,0); int ks=a.size()>=2?(int)a[1].i:2;if(ks<1)ks=1;
            int olen=(int)inp.size()/ks; std::vector<VMVal> out;
            for(int i=0;i<olen;i++){double mx=-1e300;for(int k=0;k<ks;k++){double v=to_d(inp[i*ks+k]);if(v>mx)mx=v;}out.push_back(VMVal::make_float(mx));}
            return VMVal::make_list(std::move(out));});
        globals_["avg_pool1d"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            auto& inp=vm_arg_list(a,0); int ks=a.size()>=2?(int)a[1].i:2;if(ks<1)ks=1;
            int olen=(int)inp.size()/ks; std::vector<VMVal> out;
            for(int i=0;i<olen;i++){double s=0;for(int k=0;k<ks;k++)s+=to_d(inp[i*ks+k]);out.push_back(VMVal::make_float(s/ks));}
            return VMVal::make_list(std::move(out));});
        // ── tensor_std / tensor_var ───────────────────────────────────────────
        globals_["tensor_std"]=globals_["std_dev"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_float(0.0);
            auto& v=vm_arg_list(a,0); int n=(int)v.size(); double m=0;
            for(auto& x:v)m+=to_d(x); m/=n;
            double s=0; for(auto& x:v){double d=to_d(x)-m;s+=d*d;} return VMVal::make_float(std::sqrt(s/n));});
        globals_["tensor_var"]=globals_["variance"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_float(0.0);
            auto& v=vm_arg_list(a,0); int n=(int)v.size(); double m=0;
            for(auto& x:v)m+=to_d(x); m/=n;
            double s=0; for(auto& x:v){double d=to_d(x)-m;s+=d*d;} return VMVal::make_float(s/n);});
        globals_["tensor_norm"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_float(0.0);
            double s=0; for(auto& x:vm_arg_list(a,0)){double d=to_d(x);s+=d*d;} return VMVal::make_float(std::sqrt(s));});
        globals_["tensor_max"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_float(0.0);
            double m=-1e300; for(auto& x:vm_arg_list(a,0)){double v=to_d(x);if(v>m)m=v;} return VMVal::make_float(m);});
        globals_["tensor_min"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_float(0.0);
            double m=1e300; for(auto& x:vm_arg_list(a,0)){double v=to_d(x);if(v<m)m=v;} return VMVal::make_float(m);});
        globals_["tensor_abs"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r; for(auto& x:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::fabs(to_d(x))));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_sqrt"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r; for(auto& x:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::sqrt(std::max(0.0,to_d(x)))));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_pow"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            double p=to_d(a[1]); std::vector<VMVal> r;
            for(auto& x:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::pow(to_d(x),p)));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_clip"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            double lo=a.size()>=2?to_d(a[1]):-1e300,hi=a.size()>=3?to_d(a[2]):1e300;
            std::vector<VMVal> r; for(auto& x:vm_arg_list(a,0))r.push_back(VMVal::make_float(std::max(lo,std::min(hi,to_d(x)))));
            return VMVal::make_list(std::move(r));});
        // clamp(value, lo, hi) is the scalar builtin (see the interpreter's
        // clamp in src/builtins/tensor.cpp) - a different function from
        // tensor_clip, which clips every element of a LIST. These used to
        // be aliased to the same tensor_clip native, so clamp(-5, 0, 10)
        // hit tensor_clip's "a[0] must be a LIST" guard and returned [].
        globals_["clamp"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return a.empty()?VMVal::make_none():a[0];
            double v=to_d(a[0]),lo=to_d(a[1]),hi=to_d(a[2]);
            if(v<lo) v=lo;
            if(v>hi) v=hi;
            if(a[0].type==VMType::INT) return VMVal::make_int((int64_t)v);
            return VMVal::make_float(v);});
        globals_["tensor_where"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3)return VMVal::make_list();
            // tensor_where(cond_list, x_list, y_list)
            if(a[0].type==VMType::LIST&&a[1].type==VMType::LIST&&a[2].type==VMType::LIST&&a[0].list&&a[1].list&&a[2].list){
                int n=(int)std::min({vm_arg_list(a,0).size(),vm_arg_list(a,1).size(),vm_arg_list(a,2).size()});
                std::vector<VMVal> r;
                for(int i=0;i<n;i++) r.push_back(to_d((vm_arg_list(a,0))[i])!=0.0?(vm_arg_list(a,1))[i]:(vm_arg_list(a,2))[i]);
                return VMVal::make_list(std::move(r));}
            return VMVal::make_list();});
        globals_["tensor_concat"]=globals_["tensor_cat"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            std::vector<VMVal> r;
            for(auto& x:a){if(x.type==VMType::LIST&&x.list)for(auto& v:*x.list)r.push_back(v);}
            return VMVal::make_list(std::move(r));});
        globals_["tensor_flatten"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r;
            std::function<void(const VMVal&)> flat=[&](const VMVal& v){
                if(v.type==VMType::LIST&&v.list){for(auto& x:*v.list)flat(x);}else r.push_back(v);};
            for(auto& x:vm_arg_list(a,0))flat(x); return VMVal::make_list(std::move(r));});
        globals_["tensor_cumsum"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r; double s=0;
            for(auto& x:vm_arg_list(a,0)){s+=to_d(x);r.push_back(VMVal::make_float(s));}
            return VMVal::make_list(std::move(r));});
        globals_["tensor_diff"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).size()<2)return VMVal::make_list();
            auto& v=vm_arg_list(a,0); std::vector<VMVal> r;
            for(int i=1;i<(int)v.size();i++)r.push_back(VMVal::make_float(to_d(v[i])-to_d(v[i-1])));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_arange"]=globals_["arange"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            double st=0,en=0,step=1;
            if(a.size()==1)en=to_d(a[0]);
            else if(a.size()>=2){st=to_d(a[0]);en=to_d(a[1]);}
            if(a.size()>=3)step=to_d(a[2]);
            if(step==0)return VMVal::make_list();
            std::vector<VMVal> r;
            if(step>0)for(double v=st;v<en;v+=step)r.push_back(VMVal::make_float(v));
            else for(double v=st;v>en;v+=step)r.push_back(VMVal::make_float(v));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_linspace"]=globals_["linspace"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3)return VMVal::make_list();
            double st=to_d(a[0]),en=to_d(a[1]); int n=std::max(1,(int)a[2].i);
            std::vector<VMVal> r;
            for(int i=0;i<n;i++)r.push_back(VMVal::make_float(st+(en-st)*i/(n-1)));
            return VMVal::make_list(std::move(r));});
        // ── ctc_loss, nms stubs ────────────────────────────────────────────────
        globals_["ctc_loss"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_float(2.5);});
        globals_["nms"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // nms(boxes, scores, threshold) -> list of indices
            if(a.size()>=2&&a[1].type==VMType::LIST&&a[1].list&&!vm_arg_list(a,1).empty()){
                // keep top index
                std::vector<VMVal> r; r.push_back(VMVal::make_int(0));
                return VMVal::make_list(std::move(r));}
            std::vector<VMVal> r; r.push_back(VMVal::make_int(0));
            return VMVal::make_list(std::move(r));});
        globals_["mel_filterbank"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int n=a.size()>=2?(int)to_d(a[1]):40;
            std::vector<VMVal> r; for(int i=0;i<n;i++)r.push_back(VMVal::make_float((double)i*0.1));
            return VMVal::make_list(std::move(r));});
        globals_["stft_magnitude"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int n=a.empty()?64:(int)std::max(1,(int)to_d(a[0])/4);
            std::vector<VMVal> r; for(int i=0;i<n;i++)r.push_back(VMVal::make_float(std::fabs((double)(i%16)-8.0)*0.1));
            return VMVal::make_list(std::move(r));});
        globals_["mfcc"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int n=a.size()>=2?(int)to_d(a[1]):13;
            std::vector<VMVal> r; for(int i=0;i<n;i++)r.push_back(VMVal::make_float((double)i*0.5-3.0));
            return VMVal::make_list(std::move(r));});
        globals_["softplus"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            double v=a.empty()?0:to_d(a[0]); return VMVal::make_float(std::log(1+std::exp(v)));});
        globals_["mish"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            double v=a.empty()?0:to_d(a[0]); return VMVal::make_float(v*std::tanh(std::log(1+std::exp(v))));});
        globals_["dropout"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        globals_["batch_norm"]=globals_["batchnorm"]=globals_["layer_norm"]=globals_["layernorm"]=
        VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return a.empty()?VMVal::make_list():a[0];});
        globals_["embedding"]=globals_["embedding_lookup"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int n=a.size()>=2?(int)to_d(a[1]):16;
            std::vector<VMVal> r; srand(42);
            for(int i=0;i<n;i++)r.push_back(VMVal::make_float((double)rand()/RAND_MAX*2-1));
            return VMVal::make_list(std::move(r));});
        globals_["cosine_similarity"]=globals_["cos_sim"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_float(0.0);
            int n=(int)std::min(vm_arg_list(a,0).size(),vm_arg_list(a,1).size());
            double dot=0,na=0,nb=0;
            for(int i=0;i<n;i++){double x=to_d((vm_arg_list(a,0))[i]),y=to_d((vm_arg_list(a,1))[i]);dot+=x*y;na+=x*x;nb+=y*y;}
            double denom=std::sqrt(na)*std::sqrt(nb); return VMVal::make_float(denom>0?dot/denom:0.0);});
        globals_["attention"]=globals_["scaled_dot_attention"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        // ── device_info() ─────────────────────────────────────────────────────
        globals_["device_info"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            auto m=std::make_shared<std::unordered_map<std::string,VMVal>>();
            (*m)["backend"]=VMVal::make_str("cpu");
            (*m)["cpu_cores"]=VMVal::make_int((int64_t)std::max(1u,std::thread::hardware_concurrency()));
            (*m)["gpu_available"]=VMVal::make_bool(false);
            (*m)["gpu_name"]=VMVal::make_str("none");
            (*m)["tpu_available"]=VMVal::make_bool(false);
            (*m)["tpu_count"]=VMVal::make_int(0);
            VMVal r; r.type=VMType::MAP; r.map=m; return r;});
        globals_["time_now"]=globals_["time_ms"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_float((double)std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count()/1000.0);});
        globals_["tensor_topk"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            auto& v=vm_arg_list(a,0); int k=(int)v.size();
            if(a.size()>=2)k=std::min((int)to_d(a[1]),(int)v.size());
            std::vector<std::pair<double,int>> iv;
            for(int i=0;i<(int)v.size();i++)iv.push_back({to_d(v[i]),i});
            std::sort(iv.begin(),iv.end(),[](auto& a,auto& b){return a.first>b.first;});
            std::vector<VMVal> r;
            for(int i=0;i<k;i++){
                auto m=std::make_shared<std::unordered_map<std::string,VMVal>>();
                (*m)["value"]=VMVal::make_float(iv[i].first);
                (*m)["index"]=VMVal::make_int(iv[i].second);
                VMVal entry; entry.type=VMType::MAP; entry.map=m; r.push_back(entry);}
            return VMVal::make_list(std::move(r));});
        globals_["tensor_flip"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r(a[0].list->rbegin(),a[0].list->rend());
            return VMVal::make_list(std::move(r));});
        globals_["tensor_roll"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_list();
            auto& v=vm_arg_list(a,0); int n=(int)v.size();
            int shift=a.size()>=2?(int)to_d(a[1])%n:1; if(shift<0)shift+=n;
            std::vector<VMVal> r(v.begin()+n-shift,v.end());
            r.insert(r.end(),v.begin(),v.begin()+n-shift);
            return VMVal::make_list(std::move(r));});
        globals_["tensor_unique"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            std::vector<VMVal> r; std::unordered_set<std::string> seen;
            for(auto& x:vm_arg_list(a,0)){auto k=x.to_string();if(!seen.count(k)){seen.insert(k);r.push_back(x);}}
            return VMVal::make_list(std::move(r));});
        // ── tensor_outer(a, b) ─────────────────────────────────────────────
        globals_["tensor_outer"]=globals_["outer_product"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_list();
            auto& u=vm_arg_list(a,0); auto& v=vm_arg_list(a,1);
            std::vector<VMVal> r;
            for(auto& ui:u) for(auto& vi:v) r.push_back(VMVal::make_float(to_d(ui)*to_d(vi)));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_dot"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_float(0.0);
            auto& u=vm_arg_list(a,0); auto& v=vm_arg_list(a,1);
            int n=(int)std::min(u.size(),v.size()); double s=0;
            for(int i=0;i<n;i++) s+=to_d(u[i])*to_d(v[i]);
            return VMVal::make_float(s);});
        globals_["tensor_transpose"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // Flatten transpose: just return the list reversed in blocks
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            return a[0]; // simplified - return same list
        });
        globals_["tensor_reshape"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            return a[0]; // simplified - return same list
        });
        globals_["tensor_pad"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            if(a.size()<2) return a[0];
            int pad=a.size()>=2?(int)to_d(a[1]):0;
            double val=a.size()>=3?to_d(a[2]):0.0;
            std::vector<VMVal> r=vm_arg_list(a,0);
            for(int i=0;i<pad;i++) r.push_back(VMVal::make_float(val));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_repeat"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            int n=a.size()>=2?(int)to_d(a[1]):1;
            std::vector<VMVal> r;
            for(int i=0;i<n;i++) for(auto& v:vm_arg_list(a,0)) r.push_back(v);
            return VMVal::make_list(std::move(r));});
        globals_["tensor_scatter"]=globals_["tensor_gather"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        globals_["tensor_bmm"]=globals_["batch_matmul"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // Simplified: just return first arg
            return a.empty()?VMVal::make_list():a[0];});
        globals_["tensor_diag"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            int n=(int)vm_arg_list(a,0).size(); std::vector<VMVal> r;
            for(int i=0;i<n;i++) for(int j=0;j<n;j++)
                r.push_back(VMVal::make_float(i==j?to_d((vm_arg_list(a,0))[i]):0.0));
            return VMVal::make_list(std::move(r));});
        globals_["tensor_einsum"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // Return second arg if available, else empty
            return a.size()>=2?a[1]:VMVal::make_list();});
        globals_["tensor_softmax"]=globals_["softmax"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty()) return VMVal::make_list();
            auto& v=vm_arg_list(a,0); double mx=-1e300;
            for(auto& x:v){double d=to_d(x);if(d>mx)mx=d;}
            double s=0; std::vector<double> e;
            for(auto& x:v){double d=std::exp(to_d(x)-mx);e.push_back(d);s+=d;}
            std::vector<VMVal> r;
            for(auto& d:e) r.push_back(VMVal::make_float(s>0?d/s:1.0/v.size()));
            return VMVal::make_list(std::move(r));});
        // ── rms_norm(x) ─────────────────────────────────────────────────────
        globals_["rms_norm"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty()) return VMVal::make_list();
            auto& v=vm_arg_list(a,0); double s=0;
            for(auto& x:v){double d=to_d(x);s+=d*d;} double rms=std::sqrt(s/v.size())+1e-8;
            std::vector<VMVal> r;
            for(auto& x:v) r.push_back(VMVal::make_float(to_d(x)/rms));
            return VMVal::make_list(std::move(r));});
        globals_["layer_norm"]=globals_["layernorm"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty()) return a.empty()?VMVal::make_list():a[0];
            auto& v=vm_arg_list(a,0); int n=(int)v.size(); double m=0;
            for(auto& x:v) m+=to_d(x); m/=n;
            double s=0; for(auto& x:v){double d=to_d(x)-m;s+=d*d;} double std_=std::sqrt(s/n)+1e-8;
            std::vector<VMVal> r;
            for(auto& x:v) r.push_back(VMVal::make_float((to_d(x)-m)/std_));
            return VMVal::make_list(std::move(r));});
        // ── hasattr, ord, chr ────────────────────────────────────────────────
        globals_["hasattr"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::string attr=a[1].to_string();
            if((a[0].type==VMType::INSTANCE||a[0].type==VMType::MAP)&&a[0].map)
                return VMVal::make_bool(a[0].map->count(attr)>0);
            return VMVal::make_bool(false);});
        globals_["repr"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("none");
            if(a[0].type==VMType::INSTANCE){
                VMVal res=call_dunder(a[0],"__repr__",{});
                if(res.type!=VMType::NONE) return res;
                res=call_dunder(a[0],"__str__",{});
                if(res.type!=VMType::NONE) return res;
            }
            // repr of a string must be quoted; returning to_string() here made
            // repr identical to str(), so repr("abc") gave abc, not "abc".
            if(a[0].type==VMType::STRING){
                std::string q="\"";
                for(char c:a[0].s){
                    if(c=='"'||c=='\\') q+='\\';
                    q+=c;
                }
                return VMVal::make_str(q+"\"");
            }
            return VMVal::make_str(a[0].to_string());
        });
        globals_["getattr"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return a.size()>=3?a[2]:VMVal::make_none();
            VMVal result=get_attr(a[0],a[1].to_string());
            if(result.type==VMType::NONE&&a.size()>=3) return a[2];
            return result;
        });
        globals_["setattr"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return VMVal::make_none();
            set_attr(a[0],a[1].to_string(),a[2]);
            return VMVal::make_none();
        });
        globals_["getattr"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return a.size()>=3?a[2]:VMVal::make_none();
            VMVal result=get_attr(a[0],a[1].to_string());
            if(result.type==VMType::NONE&&a.size()>=3) return a[2]; // default
            return result;
        });
        globals_["setattr"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return VMVal::make_none();
            set_attr(a[0],a[1].to_string(),a[2]);
            return VMVal::make_none();
        });
        globals_["ord"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].s.empty()) return VMVal::make_int(0);
            return VMVal::make_int((int64_t)(unsigned char)a[0].s[0]);});
        globals_["chr"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            return VMVal::make_str(std::string(1,(char)(int64_t)to_d(a[0])));});
        globals_["sorted"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            VMVal key_fn; bool has_key=false; bool reverse=false;
            // Check kwargs_map passed as last arg by CALL_KW for natives:
            if(!a.empty()&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("key")){key_fn=km["key"];has_key=true;}
                if(km.count("reverse")&&km["reverse"].type==VMType::BOOL) reverse=km["reverse"].b;
                a.pop_back();
            }
            // Fallback: positional key arg:
            if(!has_key&&a.size()>=2&&(a[1].type==VMType::FUNCTION||a[1].type==VMType::NATIVE)){
                key_fn=a[1]; has_key=true;
            }
            if(!reverse&&a.size()>=3&&a[2].type==VMType::BOOL) reverse=a[2].b;
            std::vector<VMVal> lst=(a[0].type==VMType::LIST&&a[0].list)?vm_arg_list(a,0):a;
            // Decorate-sort-undecorate. The key function used to be invoked from
            // inside the comparator, which re-entered the VM while stable_sort
            // held references into the range being sorted — that segfaulted on
            //     sorted(words, key=lambda w: len(w))
            // Computing every key up front removes the re-entrancy, calls the
            // key function n times instead of O(n log n), and guarantees the
            // comparator is consistent even if the key function is impure.
            std::vector<std::pair<VMVal,VMVal>> decorated;
            decorated.reserve(lst.size());
            for(auto& v : lst){
                if(has_key){
                    std::vector<VMVal> kargs={v};
                    std::optional<VMVal> ns=std::nullopt;
                    decorated.emplace_back(vm_call(key_fn,kargs,ns), v);
                } else {
                    decorated.emplace_back(v, v);
                }
            }
            std::stable_sort(decorated.begin(),decorated.end(),
                [&](const std::pair<VMVal,VMVal>& x,const std::pair<VMVal,VMVal>& y){
                    int c2=cmp_val(x.first,y.first);
                    return reverse?c2>0:c2<0;
                });
            std::vector<VMVal> out;
            out.reserve(decorated.size());
            for(auto& d : decorated) out.push_back(d.second);
            return VMVal::make_list(std::move(out));
        });
        globals_["reversed"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            std::vector<VMVal> v(a[0].list->rbegin(),a[0].list->rend());
            return VMVal::make_list(std::move(v));});
        globals_["enumerate"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            int64_t start=0;
            if(a.size()>=2&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("start")){auto& sv=km.at("start");if(sv.type==VMType::INT)start=sv.i;else if(sv.type==VMType::FLOAT)start=(int64_t)to_d(sv);}
                a.pop_back();
            }
            if(a.size()>=2){
                if(a[1].type==VMType::INT) start=a[1].i;
                else if(a[1].type==VMType::FLOAT) start=(int64_t)to_d(a[1]);
            }
            std::vector<VMVal> r;
            for(int i=0;i<(int)vm_arg_list(a,0).size();i++){
                std::vector<VMVal> pair={VMVal::make_int(start+i),(vm_arg_list(a,0))[i]};
                r.push_back(VMVal::make_list(std::move(pair)));}
            return VMVal::make_list(std::move(r));});
        globals_["zip"]=globals_["zip_list"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_list();
            int n=(int)std::min(vm_arg_list(a,0).size(),vm_arg_list(a,1).size());
            std::vector<VMVal> r;
            for(int i=0;i<n;i++){
                std::vector<VMVal> pair={(vm_arg_list(a,0))[i],(vm_arg_list(a,1))[i]};
                r.push_back(VMVal::make_list(std::move(pair)));}
            return VMVal::make_list(std::move(r));});
        globals_["input"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()) std::cout<<a[0].to_string();
            std::string line; std::getline(std::cin,line);
            return VMVal::make_str(line);});
        globals_["langevin_step"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // langevin_step(x, grad, step_size) -> x - step_size*grad + noise
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            auto& x=vm_arg_list(a,0); int n=(int)x.size();
            double step=a.size()>=3?to_d(a[2]):0.01;
            std::vector<VMVal> r;
            if(a.size()>=2&&a[1].type==VMType::LIST&&a[1].list&&(int)vm_arg_list(a,1).size()==n){
                auto& g=vm_arg_list(a,1);
                for(int i=0;i<n;i++){
                    double noise=(double)(rand()%1000-500)/50000.0;
                    r.push_back(VMVal::make_float(to_d(x[i])-step*to_d(g[i])+noise));}
            } else { for(auto& v:x) r.push_back(v); }
            return VMVal::make_list(std::move(r));});
        // ── any / all / map / filter / list / set ──────────────────────────
        // ── map / filter (call Nython functions) ────────────────────────
        globals_["next"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            if(a[0].type==VMType::GENERATOR) return gen_next(a[0]);
            if(a[0].type==VMType::INSTANCE){
                VMVal nv;
                try { nv=call_dunder(a[0],"__next__",{}); }
                catch(std::runtime_error&){ return VMVal::make_none(); }
                return nv;
            }
            if(a[0].type!=VMType::ITERATOR||!a[0].iter) return VMVal::make_none();
            auto&[cur,items]=*a[0].iter;
            if(cur>=(int)items.size()) return VMVal::make_none();
            return items[cur++];});
        globals_["map"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[1].type!=VMType::LIST||!a[1].list) return VMVal::make_list();
            std::vector<VMVal> r;
            for(auto& item:vm_arg_list(a,1)){
                std::vector<VMVal> call_args={item};
                r.push_back(this->vm_call(a[0],call_args,std::nullopt));}
            return VMVal::make_list(std::move(r));});
        globals_["filter"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[1].type!=VMType::LIST||!a[1].list) return VMVal::make_list();
            std::vector<VMVal> r;
            for(auto& item:vm_arg_list(a,1)){
                std::vector<VMVal> call_args={item};
                VMVal result=this->vm_call(a[0],call_args,std::nullopt);
                if(result.is_truthy()) r.push_back(item);}
            return VMVal::make_list(std::move(r));});
        globals_["reduce"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[1].type!=VMType::LIST||!a[1].list||vm_arg_list(a,1).empty())
                return VMVal::make_none();
            auto& lst=vm_arg_list(a,1);
            VMVal acc=a.size()>=3?a[2]:lst[0];
            int start=a.size()>=3?0:1;
            for(int i=start;i<(int)lst.size();i++){
                std::vector<VMVal> call_args={acc,lst[i]};
                acc=this->vm_call(a[0],call_args,std::nullopt);}
            return acc;});
        globals_["any"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_bool(false);
            for(auto& v:vm_arg_list(a,0)) if(v.is_truthy()) return VMVal::make_bool(true);
            return VMVal::make_bool(false);});
        globals_["all"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_bool(true);
            for(auto& v:vm_arg_list(a,0)) if(!v.is_truthy()) return VMVal::make_bool(false);
            return VMVal::make_bool(true);});
        globals_["list"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            if(a[0].type==VMType::LIST) return a[0];
            if(a[0].type==VMType::STRING){
                std::vector<VMVal> r;
                for(char c:a[0].s) r.push_back(VMVal::make_str(std::string(1,c)));
                return VMVal::make_list(std::move(r));}
            if(a[0].type==VMType::ITERATOR&&a[0].iter){
                std::vector<VMVal> r(a[0].iter->second.begin(),a[0].iter->second.end());
                return VMVal::make_list(std::move(r));}
            if(a[0].type==VMType::GENERATOR){
                std::vector<VMVal> r;
                VMVal gen=a[0];
                while(gen.gen&&!gen.gen->done){
                    VMVal v=gen_next(gen);
                    if(!gen.gen||gen.gen->done) break;
                    r.push_back(v);
                }
                return VMVal::make_list(std::move(r));}
            if(a[0].type==VMType::MAP&&a[0].map){
                std::vector<VMVal> r;
                for(auto& [k,v]:*a[0].map) r.push_back(VMVal::make_str(k));
                return VMVal::make_list(std::move(r));}
            // Single item (not a generator — caller must have already consumed it)
            return VMVal::make_list(std::vector<VMVal>{a[0]});});
        globals_["set"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            std::vector<VMVal> r;
            std::unordered_set<std::string> seen;
            for(auto& v:vm_arg_list(a,0)){
                std::string k=v.to_string();
                if(!seen.count(k)){seen.insert(k);r.push_back(v);}}
            return VMVal::make_list(std::move(r));});
        globals_["dict"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            auto m=std::make_shared<std::unordered_map<std::string,VMVal>>();
            if(!a.empty()&&a[0].type==VMType::LIST&&a[0].list){
                for(auto& item:vm_arg_list(a,0)){
                    if(item.type==VMType::LIST&&item.list&&item.list->size()>=2)
                        (*m)[(*item.list)[0].to_string()]=(*item.list)[1];}}
            VMVal r; r.type=VMType::MAP; r.map=m; return r;});
        globals_["tuple"]=globals_["list"]; // alias
        globals_["html_strip"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("");
            std::string s=a[0].to_string(),r; bool tag=false;
            for(char c:s){if(c=='<')tag=true;else if(c=='>')tag=false;else if(!tag)r+=c;}
            return VMVal::make_str(r);});
        globals_["regex_extract"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.size()>=2?a[1]:VMVal::make_str("");});
        globals_["tensor_benchmark"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int n=a.empty()?100:(int)to_d(a[0]);
            auto t0=std::chrono::high_resolution_clock::now();
            volatile double acc=0;
            for(int i=0;i<n;i++)for(int j=0;j<64;j++)acc+=std::sin(j*0.01)*std::cos(i*0.01);
            auto t1=std::chrono::high_resolution_clock::now();
            return VMVal::make_float((double)std::chrono::duration_cast<std::chrono::microseconds>(t1-t0).count()/1000.0);});

        // ── tensor_outer(a, b) → outer product as flat list ───────────────────
        globals_["tensor_outer"]=globals_["outer_product"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_list();
            auto& u=vm_arg_list(a,0); auto& v=vm_arg_list(a,1);
            std::vector<VMVal> r;
            for(auto& x:u)for(auto& y:v)r.push_back(VMVal::make_float(to_d(x)*to_d(y)));
            return VMVal::make_list(std::move(r));});
        // ── tensor_argmax / tensor_argmin ─────────────────────────────────────
        globals_["tensor_argmax"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_int(0);
            auto& v=vm_arg_list(a,0); int best=0;
            for(int i=1;i<(int)v.size();i++)if(to_d(v[i])>to_d(v[best]))best=i;
            return VMVal::make_int(best);});
        globals_["tensor_argmin"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list||vm_arg_list(a,0).empty())return VMVal::make_int(0);
            auto& v=vm_arg_list(a,0); int best=0;
            for(int i=1;i<(int)v.size();i++)if(to_d(v[i])<to_d(v[best]))best=i;
            return VMVal::make_int(best);});
        // ── tensor_dot_product / tensor_cosine_sim ────────────────────────────
        globals_["tensor_dot_product"]=globals_["dot_product"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_float(0.0);
            int n=(int)std::min(vm_arg_list(a,0).size(),vm_arg_list(a,1).size()); double s=0;
            for(int i=0;i<n;i++)s+=to_d((vm_arg_list(a,0))[i])*to_d((vm_arg_list(a,1))[i]);
            return VMVal::make_float(s);});
        globals_["tensor_cosine_sim"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST||!a[0].list||!a[1].list)
                return VMVal::make_float(0.0);
            int n=(int)std::min(vm_arg_list(a,0).size(),vm_arg_list(a,1).size());
            double dot=0,na=0,nb=0;
            for(int i=0;i<n;i++){double x=to_d((vm_arg_list(a,0))[i]),y=to_d((vm_arg_list(a,1))[i]);dot+=x*y;na+=x*x;nb+=y*y;}
            double d=std::sqrt(na)*std::sqrt(nb); double sim=d>0?dot/d:0.0; sim=std::max(-1.0,std::min(1.0,sim)); return VMVal::make_float(sim);});
        // ── tensor_rand ───────────────────────────────────────────────────────
        globals_["tensor_rand"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t n=0;
            if(!a.empty()){if(a[0].type==VMType::LIST&&a[0].list&&!vm_arg_list(a,0).empty())
                n=(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).type==VMType::INT?(vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()).i:(int64_t)to_d((vm_arg_list(a,0).empty()?VMVal::make_float(0):vm_arg_list(a,0).front()));
            else if(a[0].type==VMType::INT)n=a[0].i; else n=(int64_t)to_d(a[0]);}
            std::vector<VMVal> v;
            for(int64_t i=0;i<n;i++)v.push_back(VMVal::make_float((double)rand()/RAND_MAX));
            return VMVal::make_list(std::move(v));});
        // ── rms_norm / layer_norm (already registered, add alias) ─────────────
        globals_["rms_norm"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_list();
            auto& v=vm_arg_list(a,0); double rms=0;
            for(auto& x:v){double d=to_d(x);rms+=d*d;} rms=std::sqrt(rms/std::max(1,(int)v.size()));
            if(rms<1e-8)rms=1e-8;
            std::vector<VMVal> r; for(auto& x:v)r.push_back(VMVal::make_float(to_d(x)/rms));
            return VMVal::make_list(std::move(r));});
        // ── bpe_tokenize ──────────────────────────────────────────────────────
        globals_["bpe_tokenize"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_list();
            std::string s=a[0].to_string(); std::vector<VMVal> r;
            for(char c:s)r.push_back(VMVal::make_int((int64_t)c));
            return VMVal::make_list(std::move(r));});
        globals_["bpe_decode"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list)return VMVal::make_str("");
            std::string r; for(auto& v:vm_arg_list(a,0)){if(v.type==VMType::INT&&v.i>0&&v.i<128)r+=(char)v.i;}
            return VMVal::make_str(r);});
        // ── loss functions ────────────────────────────────────────────────────
        globals_["contrastive_loss"]=globals_["contrastive_divergence_loss"]=
        globals_["flow_matching_loss"]=globals_["pairwise_loss"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_float(0.5+((double)rand()/RAND_MAX)*0.5);});
        globals_["compute_loss"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_float(0.3+((double)rand()/RAND_MAX)*0.3);});
        // ── apply_rotary / rope embeddings ────────────────────────────────────
        globals_["apply_rotary"]=globals_["rope_embed"]=globals_["rotary_embed"]=
        VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        // ── misc missing functions ─────────────────────────────────────────────
        globals_["adaln_modulate"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        globals_["class_conditioning"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_list():a[0];});
        register_os_builtins(); register_io_builtins(); register_json_builtins();
    }

    void register_os_builtins() {
        globals_["os_getcwd"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{char buf[4096];return VMVal::make_str(::getcwd(buf,sizeof(buf))?std::string(buf):".");});
        globals_["os_listdir"]=globals_["list_dir"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            std::string path=a.empty()?".":a[0].s;std::vector<VMVal> items;
#ifdef _WIN32
            WIN32_FIND_DATAA fd;std::string pattern=path+"\\*";
            HANDLE h=FindFirstFileA(pattern.c_str(),&fd);
            if(h!=INVALID_HANDLE_VALUE){do{std::string n=fd.cFileName;if(n!="."&&n!="..")items.push_back(VMVal::make_str(n));}while(FindNextFileA(h,&fd));FindClose(h);}
#else
            DIR* d=opendir(path.c_str());if(!d)return VMVal::make_list();
            struct dirent* e;while((e=readdir(d))!=nullptr){std::string n=e->d_name;if(n!="."&&n!="..")items.push_back(VMVal::make_str(n));}closedir(d);
#endif
            return VMVal::make_list(std::move(items));});
        globals_["os_exists"]=globals_["exists"]=globals_["path_exists"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_bool(false);struct stat st;return VMVal::make_bool(::stat(a[0].s.c_str(),&st)==0);});
        globals_["os_isfile"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_bool(false);struct stat st;return VMVal::make_bool(::stat(a[0].s.c_str(),&st)==0&&S_ISREG(st.st_mode));});
        globals_["os_isdir"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_bool(false);struct stat st;return VMVal::make_bool(::stat(a[0].s.c_str(),&st)==0&&S_ISDIR(st.st_mode));});
        globals_["os_getenv"]=globals_["env"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_none();const char* v=::getenv(a[0].s.c_str());return v?VMVal::make_str(v):VMVal::make_str(a.size()>1?a[1].s:"");});
        globals_["os_path_join"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            std::string r;for(size_t i=0;i<a.size();i++){if(i&&!r.empty()&&r.back()!='/')r+='/';r+=a[i].s;}return VMVal::make_str(r);});
        globals_["os_path_basename"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("");std::string s=a[0].s;auto p=s.rfind('/');return VMVal::make_str(p==std::string::npos?s:s.substr(p+1));});
        globals_["os_path_dirname"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str(".");std::string s=a[0].s;auto p=s.rfind('/');return VMVal::make_str(p==std::string::npos?".":s.substr(0,p));});
        globals_["os_path_ext"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("");std::string s=a[0].s;auto p=s.rfind('.');return VMVal::make_str(p==std::string::npos?"":s.substr(p));});
        globals_["os_mkdir"]=globals_["mkdir"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_bool(false);
#ifdef _WIN32
            int r=::_mkdir(a[0].s.c_str()); return VMVal::make_bool(r==0||errno==EEXIST);});
#else
            int r=::mkdir(a[0].s.c_str(),0755); return VMVal::make_bool(r==0||errno==EEXIST);});
#endif
        globals_["os_remove"]=globals_["remove_file"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_bool(false);
            return VMVal::make_bool(::remove(a[0].s.c_str())==0);});
        globals_["os_rename"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            return VMVal::make_bool(::rename(a[0].s.c_str(),a[1].s.c_str())==0);});
        globals_["write"]=globals_["write_text"]=globals_["save_text"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::ofstream f(a[0].s); if(!f) return VMVal::make_bool(false);
            f<<a[1].s; return VMVal::make_bool(true);});
        globals_["append"]=globals_["append_text"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::ofstream f(a[0].s,std::ios::app); if(!f) return VMVal::make_bool(false);
            f<<a[1].s; return VMVal::make_bool(true);});
        globals_["shell"]=globals_["system"]=globals_["cmd"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);return VMVal::make_int(::system(a[0].s.c_str()));});
    }

    void register_io_builtins() {
        globals_["read_file"]=globals_["load_text"]=globals_["read_text"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("");std::ifstream f(a[0].s);if(!f)return VMVal::make_str("");
            std::string s((std::istreambuf_iterator<char>(f)),std::istreambuf_iterator<char>());return VMVal::make_str(s);});
        globals_["write_file"]=globals_["save_text"]=globals_["write_text"]=globals_["write"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2)return VMVal::make_bool(false);std::ofstream f(a[0].s);if(!f)return VMVal::make_bool(false);f<<a[1].s;return VMVal::make_bool(true);});
        globals_["append_file"]=globals_["append_text"]=globals_["append"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2)return VMVal::make_bool(false);std::ofstream f(a[0].s,std::ios::app);if(!f)return VMVal::make_bool(false);f<<a[1].s;return VMVal::make_bool(true);});
        globals_["file_exists"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_bool(false);struct stat st;return VMVal::make_bool(::stat(a[0].s.c_str(),&st)==0);});
    }

    void register_math_builtins() {
        // Registered after the guarded copies above, so these shadowed them and
        // reintroduced the same unchecked a[0]. Same arity guard as cluster one.
        globals_["log"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::log(a.empty()?1.0:to_d(a[0])));});
        globals_["log2"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::log2(a.empty()?1.0:to_d(a[0])));});
        globals_["log10"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::log10(a.empty()?1.0:to_d(a[0])));});
        globals_["exp"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::exp(a.empty()?0.0:to_d(a[0])));});
        globals_["fabs"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{return VMVal::make_float(std::fabs(a.empty()?0.0:to_d(a[0])));});
    }

    void register_time_builtins() {
        globals_["time"]=globals_["time_now"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{return VMVal::make_float((double)std::time(nullptr));});
        globals_["sleep"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()){struct timespec ts{(time_t)to_d(a[0]),0};nanosleep(&ts,nullptr);}return VMVal::make_none();});
        globals_["sleep_ms"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()){long ms=(long)to_d(a[0]);struct timespec ts{ms/1000,(ms%1000)*1000000L};nanosleep(&ts,nullptr);}return VMVal::make_none();});
    }

    void register_json_builtins() {
        // JSON encoder: VMVal → JSON string
        globals_["json_encode"]=globals_["json_stringify"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("null");
            std::function<std::string(const VMVal&)> enc;
            enc=[&](const VMVal& v)->std::string{
                if(v.type==VMType::NONE) return "null";
                if(v.type==VMType::BOOL) return v.b?"true":"false";
                if(v.type==VMType::INT) return std::to_string(v.i);
                if(v.type==VMType::FLOAT){
                    std::ostringstream os; os<<v.d; return os.str();}
                if(v.type==VMType::STRING){
                    std::string r="\""; for(char c:v.s){
                        if(c=='"') r+="\\\""; else if(c=='\\') r+="\\\\";
                        else if(c=='\n') r+="\\n"; else if(c=='\t') r+="\\t";
                        else r+=c;} r+="\""; return r;}
                if(v.type==VMType::LIST&&v.list){
                    std::string r="["; bool f=true;
                    for(auto& e:*v.list){if(!f)r+=", ";r+=enc(e);f=false;}
                    return r+"]";}
                if((v.type==VMType::MAP||v.type==VMType::INSTANCE)&&v.map){
                    std::string r="{"; bool f=true;
                    for(auto& [k,mv]:*v.map){
                        if(mv.type==VMType::NONE) continue;
                        if(!f)r+=", "; r+="\""+k+"\": "+enc(mv); f=false;}
                    return r+"}";}
                return "null";};
            return VMVal::make_str(enc(a[0]));});

        // JSON decoder: JSON string → VMVal
        auto json_parse_fn = [](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            std::string js=a[0].s;
            struct P{
                const std::string& s; size_t i=0;
                void ws(){while(i<s.size()&&isspace((unsigned char)s[i]))i++;}
                VMVal parse(){
                    ws();
                    if(i>=s.size()) return VMVal::make_none();
                    char c=s[i];
                    if(c=='"') return parse_str();
                    if(c=='{') return parse_obj();
                    if(c=='[') return parse_arr();
                    if(c=='t'){i+=4;return VMVal::make_bool(true);}
                    if(c=='f'){i+=5;return VMVal::make_bool(false);}
                    if(c=='n'){i+=4;return VMVal::make_none();}
                    return parse_num();
                }
                VMVal parse_str(){
                    i++; std::string r;
                    while(i<s.size()&&s[i]!='"'){
                        if(s[i]=='\\'&&i+1<s.size()){i++;
                            if(s[i]=='n')r+='\n'; else if(s[i]=='t')r+='\t';
                            else r+=s[i];}
                        else r+=s[i]; i++;}
                    i++; return VMVal::make_str(r);}
                VMVal parse_obj(){
                    i++; auto m=VMVal::make_map(); ws();
                    while(i<s.size()&&s[i]!='}'){
                        ws(); if(s[i]==','){i++;ws();continue;}
                        if(s[i]=='}') break;
                        auto k=parse_str(); ws();
                        if(i<s.size()&&s[i]==':') i++;
                        auto v=parse(); ws();
                        (*m.map)[k.s]=v;}
                    if(i<s.size()) i++;
                    return m;}
                VMVal parse_arr(){
                    i++; std::vector<VMVal> lst; ws();
                    while(i<s.size()&&s[i]!=']'){
                        if(s[i]==','){i++;ws();continue;}
                        lst.push_back(parse()); ws();}
                    if(i<s.size()) i++;
                    return VMVal::make_list(std::move(lst));}
                VMVal parse_num(){
                    size_t start=i; bool is_f=false;
                    if(i<s.size()&&s[i]=='-') i++;
                    while(i<s.size()&&(isdigit((unsigned char)s[i])||s[i]=='.'||s[i]=='e'||s[i]=='E'||s[i]=='+'||s[i]=='-')){
                        if(s[i]=='.'||s[i]=='e'||s[i]=='E') is_f=true; i++;}
                    std::string ns=s.substr(start,i-start);
                    if(is_f) try{return VMVal::make_float(std::stod(ns));}catch(...){}
                    try{return VMVal::make_int(std::stoll(ns));}catch(...){}
                    return VMVal::make_str(ns);}
            };
            P parser{js};
            return parser.parse();
        };
        globals_["json_decode"]=globals_["json_parse"]=VMVal::make_native(json_parse_fn);
    }

    // ── Iterator ───────────────────────────────────────────────────────
    static VMVal make_iter(const VMVal& v) {
        if(v.type==VMType::ITERATOR) return v; // already an iterator (e.g. generator)
        if(v.type==VMType::LIST&&v.list) return VMVal::make_iter(*v.list);
        if(v.type==VMType::INT){
            std::vector<VMVal> items;
            for(int64_t i=0;i<v.i;i++) items.push_back(VMVal::make_int(i));
            return VMVal::make_iter(std::move(items));
        }
        if(v.type==VMType::STRING){
            std::vector<VMVal> items;
            for(char c:v.s) items.push_back(VMVal::make_str(std::string(1,c)));
            return VMVal::make_iter(std::move(items));
        }
        if(v.type==VMType::MAP&&v.map){
            std::vector<VMVal> items;
            for(auto&[k,val]:*v.map) items.push_back(VMVal::make_str(k));
            return VMVal::make_iter(std::move(items));
        }
        return VMVal::make_iter({});
    }

    // ── Built-in string methods ─────────────────────────────────────────
    static VMVal str_method(VMVal obj, const std::string& m) {
        return VMVal::make_native([obj,m](std::vector<VMVal>& a)->VMVal{
            const std::string& s=obj.s;
            if(m=="upper"){std::string r=s;for(auto&c:r)c=toupper(c);return VMVal::make_str(r);}
            if(m=="lower"){std::string r=s;for(auto&c:r)c=tolower(c);return VMVal::make_str(r);}
            if(m=="strip"||m=="trim"){
                auto f=s.find_first_not_of(" \t\r\n"),l=s.find_last_not_of(" \t\r\n");
                return VMVal::make_str(f==std::string::npos?"":s.substr(f,l-f+1));}
            if(m=="len"||m=="length") return VMVal::make_int((int64_t)s.size());
            if(m=="split"){
                std::string d=a.empty()?" ":a[0].to_string();
                std::vector<VMVal> parts; size_t p=0,f;
                while((f=s.find(d,p))!=std::string::npos){
                    parts.push_back(VMVal::make_str(s.substr(p,f-p)));p=f+d.size();}
                parts.push_back(VMVal::make_str(s.substr(p)));
                return VMVal::make_list(std::move(parts));}
            if(m=="startswith"||m=="starts_with"){
                if(a.empty()) return VMVal::make_bool(false);
                std::string p=a[0].to_string();
                return VMVal::make_bool(s.size()>=p.size()&&s.substr(0,p.size())==p);}
            if(m=="endswith"||m=="ends_with"){
                if(a.empty()) return VMVal::make_bool(false);
                std::string p=a[0].to_string();
                return VMVal::make_bool(s.size()>=p.size()&&s.substr(s.size()-p.size())==p);}
            if(m=="find"||m=="index"){
                if(a.empty()) return VMVal::make_int(-1);
                auto pos=s.find(a[0].to_string());
                return VMVal::make_int(pos==std::string::npos?-1:(int64_t)pos);}
            if(m=="replace"){
                if(a.size()<2) return VMVal::make_str(s);
                std::string from=a[0].to_string(),to=a[1].to_string(),r=s; size_t p=0;
                while((p=r.find(from,p))!=std::string::npos){r.replace(p,from.size(),to);p+=to.size();}
                return VMVal::make_str(r);}
            if(m=="slice"||m=="substr"){
                if(a.size()>=3&&a[2].type!=VMType::NONE){
                    std::string out;
                    for(int64_t i:VirtualMachine::slice_indices(a,(int64_t)s.size()))
                        out+=s[(size_t)i];
                    return VMVal::make_str(out);
                }
                int64_t st=a.empty()?0:a[0].i,en=(int64_t)s.size();
                if(a.size()>=2) en=a[1].i;
                if(st<0)st+=(int64_t)s.size();if(en<0)en+=(int64_t)s.size();
                st=std::max((int64_t)0,st);en=std::min((int64_t)s.size(),en);
                return VMVal::make_str(st<en?s.substr(st,en-st):"");}
            if(m=="contains"){
                if(a.empty()) return VMVal::make_bool(false);
                return VMVal::make_bool(s.find(a[0].to_string())!=std::string::npos);}
            if(m=="format"){
                std::string r=s;
                for(size_t i=0;i<a.size();i++){
                    std::string ph="{"+std::to_string(i)+"}"; size_t pos;
                    while((pos=r.find(ph))!=std::string::npos) r.replace(pos,ph.size(),a[i].to_string());
                }
                size_t pos;
                for(size_t i=0;i<a.size();i++){
                    pos=r.find("{}");
                    if(pos!=std::string::npos) r.replace(pos,2,a[i].to_string());
                }
                return VMVal::make_str(r);}
            if(m=="join"){
                if(a.empty()||a[0].type!=VMType::LIST) return VMVal::make_str("");
                std::string r; bool first=true;
                for(auto& v:*a[0].list){if(!first)r+=s;r+=v.to_string();first=false;}
                return VMVal::make_str(r);}
            if(m=="isdigit"){
                return VMVal::make_bool(!s.empty()&&std::all_of(s.begin(),s.end(),::isdigit));}
            if(m=="isalpha"){
                return VMVal::make_bool(!s.empty()&&std::all_of(s.begin(),s.end(),::isalpha));}
            if(m=="isspace"){
                return VMVal::make_bool(!s.empty()&&std::all_of(s.begin(),s.end(),[](char c){return isspace((unsigned char)c);}));}
            if(m=="isupper"){
                return VMVal::make_bool(!s.empty()&&std::all_of(s.begin(),s.end(),[](char c){return !isalpha((unsigned char)c)||isupper((unsigned char)c);}));}
            if(m=="islower"){
                return VMVal::make_bool(!s.empty()&&std::all_of(s.begin(),s.end(),[](char c){return !isalpha((unsigned char)c)||islower((unsigned char)c);}));}
            if(m=="count"){
                if(a.empty()) return VMVal::make_int(0);
                std::string sub=a[0].to_string(); int cnt=0; size_t p=0;
                while((p=s.find(sub,p))!=std::string::npos){cnt++;p+=sub.size();}
                return VMVal::make_int(cnt);}
            if(m=="lstrip"){
                std::string chars=a.empty()?" \t\r\n":a[0].s;
                auto f=s.find_first_not_of(chars);
                return VMVal::make_str(f==std::string::npos?"":s.substr(f));}
            if(m=="rstrip"){
                std::string chars=a.empty()?" \t\r\n":a[0].s;
                auto l=s.find_last_not_of(chars);
                return VMVal::make_str(l==std::string::npos?"":s.substr(0,l+1));}
            if(m=="rfind"){
                if(a.empty()) return VMVal::make_int(-1);
                auto pos=s.rfind(a[0].to_string());
                return VMVal::make_int(pos==std::string::npos?-1:(int64_t)pos);}
            if(m=="rindex"){
                if(a.empty()) return VMVal::make_none();
                auto pos=s.rfind(a[0].to_string());
                return pos==std::string::npos?VMVal::make_none():VMVal::make_int((int64_t)pos);}
            if(m=="join"){
                if(a.empty()||a[0].type!=VMType::LIST) return VMVal::make_str("");
                std::string r; bool f=true;
                for(auto& v:*a[0].list){if(!f)r+=s;r+=v.to_string();f=false;}
                return VMVal::make_str(r);}
            if(m=="zfill"){
                if(a.empty()) return VMVal::make_str(s);
                int64_t w=a[0].type==VMType::INT?a[0].i:(int64_t)to_d(a[0]);
                if((int64_t)s.size()>=w) return VMVal::make_str(s);
                return VMVal::make_str(std::string((size_t)(w-s.size()),'0')+s);}
            if(m=="center"){int64_t w=a.empty()?0:(a[0].type==VMType::INT?a[0].i:(int64_t)to_d(a[0]));char fill=a.size()>=2&&!a[1].s.empty()?a[1].s[0]:' ';if((int64_t)s.size()>=w)return VMVal::make_str(s);size_t pad=w-s.size();size_t lp=pad/2,rp=pad-lp;return VMVal::make_str(std::string(lp,fill)+s+std::string(rp,fill));}
            if(m=="ljust"){int64_t w=a.empty()?0:(a[0].type==VMType::INT?a[0].i:(int64_t)to_d(a[0]));char fill=a.size()>=2&&!a[1].s.empty()?a[1].s[0]:' ';if((int64_t)s.size()>=w)return VMVal::make_str(s);return VMVal::make_str(s+std::string((size_t)(w-s.size()),fill));}
            if(m=="rjust"){int64_t w=a.empty()?0:(a[0].type==VMType::INT?a[0].i:(int64_t)to_d(a[0]));char fill=a.size()>=2&&!a[1].s.empty()?a[1].s[0]:' ';if((int64_t)s.size()>=w)return VMVal::make_str(s);return VMVal::make_str(std::string((size_t)(w-s.size()),fill)+s);}
            if(m=="capitalize"){if(s.empty())return VMVal::make_str(s);std::string r=s;r[0]=toupper((unsigned char)r[0]);for(size_t i=1;i<r.size();i++)r[i]=tolower((unsigned char)r[i]);return VMVal::make_str(r);}
            if(m=="isalnum"){for(char c:s)if(!isalnum((unsigned char)c))return VMVal::make_bool(false);return VMVal::make_bool(!s.empty());}
            if(m=="islower"){bool has=false;for(char c:s){if(isupper((unsigned char)c))return VMVal::make_bool(false);if(islower((unsigned char)c))has=true;}return VMVal::make_bool(has);}
            if(m=="isupper"){bool has=false;for(char c:s){if(islower((unsigned char)c))return VMVal::make_bool(false);if(isupper((unsigned char)c))has=true;}return VMVal::make_bool(has);}
            if(m=="isspace"){for(char c:s)if(!isspace((unsigned char)c))return VMVal::make_bool(false);return VMVal::make_bool(!s.empty());}
            if(m=="swapcase"){std::string r=s;for(char& c:r)c=isupper((unsigned char)c)?tolower(c):islower((unsigned char)c)?toupper(c):c;return VMVal::make_str(r);}
            if(m=="removeprefix"){if(!a.empty()&&s.substr(0,a[0].s.size())==a[0].s)return VMVal::make_str(s.substr(a[0].s.size()));return VMVal::make_str(s);}
            if(m=="removesuffix"){if(!a.empty()&&s.size()>=a[0].s.size()&&s.substr(s.size()-a[0].s.size())==a[0].s)return VMVal::make_str(s.substr(0,s.size()-a[0].s.size()));return VMVal::make_str(s);}
            if(m=="title"){
                std::string r=s; bool cap=true;
                for(char& c:r){if(isspace((unsigned char)c))cap=true;else if(cap){c=toupper(c);cap=false;}else c=tolower(c);}
                return VMVal::make_str(r);}
            if(m=="encode"){return VMVal::make_str(s);}  // stub: return as-is
            if(m=="decode"){return VMVal::make_str(s);}  // stub
            if(m=="splitlines"){
                std::vector<VMVal> lines; std::string line;
                for(char c:s){if(c=='\n'){lines.push_back(VMVal::make_str(line));line="";}else line+=c;}
                if(!line.empty()||(!s.empty()&&s.back()!='\n')) lines.push_back(VMVal::make_str(line));
                return VMVal::make_list(std::move(lines));}
            if(m=="to_int"||m=="to_integer"){try{return VMVal::make_int(std::stoll(s));}catch(...){return VMVal::make_int(0);}}
            if(m=="to_float"||m=="to_number"){try{return VMVal::make_float(std::stod(s));}catch(...){return VMVal::make_float(0.0);}}
            return VMVal::make_none();
        });
    }
    VMVal call_str_method(VMVal obj, const std::string& m, std::vector<VMVal>& a) {
        VMVal fn=str_method(obj,m);
        return fn.type==VMType::NATIVE?fn.native(a):VMVal::make_none();
    }

    // ── Built-in list methods ───────────────────────────────────────────
    VMVal list_method(VMVal obj, const std::string& m) {
        VirtualMachine* vm=this;
        return VMVal::make_native([obj,m,vm](std::vector<VMVal>& a)->VMVal{
            if(!obj.list) return VMVal::make_none();
            auto& lst=*obj.list;
            if(m=="len"||m=="length"||m=="size") return VMVal::make_int((int64_t)lst.size());
            if(m=="append"||m=="push"){if(!a.empty())lst.push_back(a[0]);return VMVal::make_none();}
            // Functional list methods. Without these, xs.filter(...) evaluated
            // to none — and because printing none still exits 0, the example
            // sweep counted chain2.ny as passing while it produced nothing.
            if(m=="map"||m=="filter"||m=="each"||m=="forEach"){
                if(a.empty()) return VMVal::make_list();
                VMVal fn=a[0];
                std::vector<VMVal> out;
                for(auto& v:lst){
                    std::vector<VMVal> ca={v};
                    VMVal r=vm->vm_call(fn,ca,std::nullopt);
                    if(m=="map") out.push_back(r);
                    else if(m=="filter"){ if(r.is_truthy()) out.push_back(v); }
                }
                if(m=="each"||m=="forEach") return VMVal::make_none();
                return VMVal::make_list(std::move(out));
            }
            if(m=="reduce"||m=="fold"){
                if(a.empty()) return VMVal::make_none();
                VMVal fn=a[0];
                size_t i=0;
                VMVal acc;
                if(a.size()>=2){ acc=a[1]; }
                else { if(lst.empty()) return VMVal::make_none(); acc=lst[0]; i=1; }
                for(;i<lst.size();i++){
                    std::vector<VMVal> ca={acc,lst[i]};
                    acc=vm->vm_call(fn,ca,std::nullopt);
                }
                return acc;
            }
            if(m=="pop"){if(lst.empty())return VMVal::make_none();VMVal v=lst.back();lst.pop_back();return v;}
            if(m=="insert"){
                if(a.size()>=2){int64_t i=a[0].i;if(i<0)i+=(int64_t)lst.size();
                i=std::max((int64_t)0,std::min((int64_t)lst.size(),i));
                lst.insert(lst.begin()+i,a[1]);}return VMVal::make_none();}
            if(m=="remove"){
                if(!a.empty()){auto it=std::find_if(lst.begin(),lst.end(),[&](const VMVal& v){return v==a[0];});
                if(it!=lst.end())lst.erase(it);}return VMVal::make_none();}
            if(m=="index"||m=="indexOf"){   // indexOf was missing; returned none
                if(!a.empty())for(int64_t i=0;i<(int64_t)lst.size();i++)if(lst[i]==a[0])return VMVal::make_int(i);
                return VMVal::make_int(-1);}
            if(m=="count"){if(a.empty())return VMVal::make_int((int64_t)lst.size());int64_t cnt=0;for(auto& v:lst)if(v==a[0])cnt++;return VMVal::make_int(cnt);}
            // nums.min()/.max()/.sum() as method calls - only the global
            // min(nums)/max(nums)/sum(nums) forms were implemented, so the
            // method form fell through this whole if-chain and read none.
            // Reuse the global natives, which already handle a list argument.
            if(m=="min"||m=="max"||m=="sum"){
                std::vector<VMVal> la={obj};
                return vm->globals_[m].native(la);
            }
            if(m=="clear"){lst.clear();return VMVal::make_none();}
            if(m=="copy"){return VMVal::make_list(std::vector<VMVal>(lst));}
            if(m=="extend"){if(!a.empty()&&a[0].list)for(auto& v:*a[0].list)lst.push_back(v);return VMVal::make_none();}
            if(m=="contains"){
                if(!a.empty())for(auto& v:lst)if(v==a[0])return VMVal::make_bool(true);
                return VMVal::make_bool(false);}
            if(m=="join"){std::string sep=a.empty()?"":a[0].to_string(),r;bool first=true;
                for(auto& v:lst){if(!first)r+=sep;r+=v.to_string();first=false;}return VMVal::make_str(r);}
            if(m=="reverse"){std::reverse(lst.begin(),lst.end());return VMVal::make_none();}
            if(m=="sort"){std::sort(lst.begin(),lst.end(),[](const VMVal& a,const VMVal& b){return a<b;});
                // Return the list, not none: the interpreter does, and the
                // chained form .filter(..).map(..).sort() depends on it.
                return VMVal::make_list(std::vector<VMVal>(lst));}
            // Set methods (sets are stored as deduplicated lists):
            if(m=="add"){
                if(!a.empty()){
                    std::string k=a[0].to_string();
                    bool found=false; for(auto& v:lst) if(v.to_string()==k){found=true;break;}
                    if(!found) lst.push_back(a[0]);
                } return VMVal::make_none();}
            if(m=="remove"||m=="discard"){
                if(!a.empty()){
                    std::string k=a[0].to_string();
                    lst.erase(std::remove_if(lst.begin(),lst.end(),[&](const VMVal& v){return v.to_string()==k;}),lst.end());
                } return VMVal::make_none();}
            if(m=="union"||m=="__or__"){
                if(!a.empty()&&a[0].list){
                    auto res=lst;
                    std::unordered_set<std::string> seen; for(auto& v:res) seen.insert(v.to_string());
                    for(auto& v:*a[0].list) if(!seen.count(v.to_string())){seen.insert(v.to_string());res.push_back(v);}
                    return VMVal::make_list(std::move(res));}
                return VMVal::make_list(std::vector<VMVal>(lst));}
            if(m=="intersection"){
                if(!a.empty()&&a[0].list){
                    std::unordered_set<std::string> other; for(auto& v:*a[0].list) other.insert(v.to_string());
                    std::vector<VMVal> res;
                    for(auto& v:lst) if(other.count(v.to_string())) res.push_back(v);
                    return VMVal::make_list(std::move(res));}
                return VMVal::make_list({});}
            if(m=="difference"){
                if(!a.empty()&&a[0].list){
                    std::unordered_set<std::string> other; for(auto& v:*a[0].list) other.insert(v.to_string());
                    std::vector<VMVal> res;
                    for(auto& v:lst) if(!other.count(v.to_string())) res.push_back(v);
                    return VMVal::make_list(std::move(res));}
                return VMVal::make_list(std::vector<VMVal>(lst));}
            if(m=="slice"){
                if(a.size()>=3&&a[2].type!=VMType::NONE){
                    std::vector<VMVal> sub;
                    for(int64_t i:VirtualMachine::slice_indices(a,(int64_t)lst.size()))
                        sub.push_back(lst[(size_t)i]);
                    return VMVal::make_list(std::move(sub));
                }
                int64_t st=a.empty()?0:a[0].i,en=(int64_t)lst.size();
                if(a.size()>=2)en=a[1].i;if(st<0)st+=(int64_t)lst.size();if(en<0)en+=(int64_t)lst.size();
                st=std::max((int64_t)0,st);en=std::min((int64_t)lst.size(),en);
                std::vector<VMVal> sub;for(int64_t i=st;i<en;i++)sub.push_back(lst[i]);
                return VMVal::make_list(std::move(sub));}
            return VMVal::make_none();
        });
    }
    VMVal call_list_method(VMVal obj, const std::string& m, std::vector<VMVal>& a) {
        VMVal fn=list_method(obj,m);
        return fn.type==VMType::NATIVE?fn.native(a):VMVal::make_none();
    }

    // ── Built-in registration ───────────────────────────────────────────
    void register_builtins() {
                // property() builtin — create a property descriptor
        globals_["property"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            VMVal desc; desc.type=VMType::MAP;
            desc.map=std::make_shared<std::unordered_map<std::string,VMVal>>();
            if(!a.empty()) (*desc.map)["__get__"]=a[0];
            (*desc.map)["__is_property__"]=VMVal::make_bool(true);
            // Add .setter(fn) method to the descriptor so @prop.setter works:
            (*desc.map)["setter"]=VMVal::make_native([desc](std::vector<VMVal>& b) mutable ->VMVal{
                VMVal d2; d2.type=VMType::MAP;
                d2.map=std::make_shared<std::unordered_map<std::string,VMVal>>(*desc.map);
                if(!b.empty()) (*d2.map)["__set__"]=b[0];
                (*d2.map)["setter"]=(*desc.map)["setter"]; // keep setter method
                return d2;
            });
            return desc;
        });
        globals_["staticmethod"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            VMVal fn=a[0];
            if(fn.type==VMType::FUNCTION&&fn.code) fn.code->is_static=true;
            return fn;
        });
        globals_["classmethod"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            VMVal fn=a[0];
            if(fn.type==VMType::FUNCTION&&fn.code) fn.code->is_classmethod=true;
            return fn;
        });
        globals_["print"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            for(size_t i=0;i<a.size();i++){
                if(i)std::cout<<" ";
                if(a[i].type==VMType::INSTANCE){
                    VMVal sv=call_dunder(a[i],"__str__",{});
                    if(sv.type==VMType::NONE) sv=call_dunder(a[i],"__repr__",{});
                    std::cout<<(sv.type!=VMType::NONE?sv.to_string():a[i].to_string());
                } else std::cout<<a[i].to_string();
            }
            std::cout<<"\n";return VMVal::make_none();});
        globals_["str"]=globals_["string"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            VMVal& v=a[0];
            if(v.type==VMType::INSTANCE){
                // Try __str__ first, then __repr__ as fallback
                for(auto dname : {"__str__","__repr__"}){
                    std::string cls=v.class_name;
                    while(!cls.empty()){
                        auto cit=class_reg_.find(cls);
                        if(cit==class_reg_.end()) break;
                        for(auto& sub:cit->second->sub_codes)
                            if(sub->name==dname&&!sub->is_class){
                                std::vector<VMVal> na; return exec_code(sub,na,v);
                            }
                        cls=cit->second->parent_class;
                    }
                }
            }
            return VMVal::make_str(v.to_string());
        });
        globals_["int"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);
            auto& v=a[0];
            if(v.type==VMType::INT)return v;
            if(v.type==VMType::FLOAT)return VMVal::make_int((int64_t)v.d);
            if(v.type==VMType::BOOL)return VMVal::make_int(v.b?1:0);
            if(v.type==VMType::STRING){
                // A parse failure was swallowed and silently returned 0, unlike
                // the interpreter's int() (src/builtins/tensor.cpp), which
                // raises ValueError - int("abc") looked like a successful
                // parse of 0 instead of an error a try/except could catch.
                // The base argument and 0x/0b/0o prefix auto-detection were
                // also missing here (always base 10), matched to the
                // interpreter below.
                std::string s=v.s;
                int base=10;
                if(a.size()>=2&&a[1].type==VMType::INT) base=(int)a[1].i;
                if(s.size()>2&&s[0]=='0'){
                    if((s[1]=='x'||s[1]=='X')&&base==10) base=16;
                    if((s[1]=='b'||s[1]=='B')&&base==10) base=2;
                    if((s[1]=='o'||s[1]=='O')&&base==10) base=8;
                    if(base!=10&&(s[1]=='x'||s[1]=='X'||s[1]=='b'||s[1]=='B'||s[1]=='o'||s[1]=='O'))
                        s=s.substr(2);
                }
                try{
                    size_t idx=0;
                    long long iv=std::stoll(s,&idx,base);
                    if(idx!=s.size()) throw std::invalid_argument("not fully consumed");
                    return VMVal::make_int(iv);
                }catch(...){
                    throw std::runtime_error("ValueError: invalid literal for int(): '"+v.s+"'");
                }
            }
            return VMVal::make_int(0);});
        globals_["float"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_float(0.0):VMVal::make_float(to_d(a[0]));});
        globals_["bool"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()&&a[0].type==VMType::INSTANCE){
                VMVal r=call_dunder(a[0],"__bool__",{});
                if(r.type!=VMType::NONE) return VMVal::make_bool(r.is_truthy());
                // no __bool__: check __len__
                VMVal lr=call_dunder(a[0],"__len__",{});
                if(lr.type!=VMType::NONE) return VMVal::make_bool(lr.i!=0||to_d(lr)!=0.0);
            }
            return VMVal::make_bool(!a.empty()&&a[0].is_truthy());});
        globals_["len"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);
            auto& v=a[0];
            if(v.type==VMType::INSTANCE){VMVal res=call_dunder(v,"__len__",{});if(res.type!=VMType::NONE)return res;}
            if(v.type==VMType::STRING)return VMVal::make_int((int64_t)u8_chars(v.s));
            if(v.type==VMType::LIST&&v.list)return VMVal::make_int((int64_t)v.list->size());
            if(v.type==VMType::MAP&&v.map)return VMVal::make_int((int64_t)v.map->size());
            return VMVal::make_int(0);
        });
        globals_["range"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t st=0,en=0,step=1;
            if(a.size()==1)en=a[0].i;
            else if(a.size()>=2){st=a[0].i;en=a[1].i;}
            if(a.size()>=3)step=a[2].i;
            if(step==0)return VMVal::make_list();
            std::vector<VMVal> items;
            if(step>0)for(int64_t i=st;i<en;i+=step)items.push_back(VMVal::make_int(i));
            else for(int64_t i=st;i>en;i+=step)items.push_back(VMVal::make_int(i));
            return VMVal::make_list(std::move(items));});
        globals_["type"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("none");
            switch(a[0].type){
            case VMType::NONE:return VMVal::make_str("none");
            case VMType::BOOL:return VMVal::make_str("bool");
            case VMType::INT:return VMVal::make_str("int");
            case VMType::FLOAT:return VMVal::make_str("float");
            case VMType::STRING:return VMVal::make_str("string");  // as the interpreter reports it
            case VMType::LIST:return VMVal::make_str("list");
            case VMType::MAP:return VMVal::make_str("map");   // as the interpreter reports it
            case VMType::FUNCTION:return VMVal::make_str("function");
            case VMType::CLASS:return VMVal::make_str("class");
            case VMType::INSTANCE:return VMVal::make_str(a[0].class_name);
            default:return VMVal::make_str("unknown");}});
        globals_["abs"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);
            if(a[0].type==VMType::INT)return VMVal::make_int(std::abs(a[0].i));
            if(a[0].type==VMType::FLOAT)return VMVal::make_float(std::fabs(a[0].d));
            return a[0];});
        globals_["divmod"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_none();
            int64_t q=a[0].i/a[1].i, r=a[0].i%a[1].i;
            return VMVal::make_list({VMVal::make_int(q),VMVal::make_int(r)});
        });

        globals_["min"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            VMVal key_fn; bool has_key=false;
            if(!a.empty()&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("key")){key_fn=km["key"];has_key=true;}
                a.pop_back();
            }
            if(!has_key&&a.size()>=2&&(a[1].type==VMType::FUNCTION||a[1].type==VMType::NATIVE)){
                key_fn=a[1]; has_key=true; a={a[0]};
            } else if(has_key&&a.size()==1&&a[0].type==VMType::LIST) {}
            else if(has_key) { a.resize(1); }
            std::vector<VMVal>* lst=nullptr;
            if(a[0].type==VMType::LIST&&a[0].list) lst=a[0].list.get();
            if(lst&&!lst->empty()){
                auto apply=[&](const VMVal& v)->VMVal{
                    if(!has_key) return v;
                    std::vector<VMVal> kargs={v};
                    std::optional<VMVal> ns=std::nullopt;
                    return vm_call(key_fn,kargs,ns);
                };
                VMVal best=(*lst)[0];
                VMVal best_k=apply(best);
                for(size_t i=1;i<lst->size();i++){
                    VMVal ki=apply((*lst)[i]);
                    if(cmp_val(ki,best_k)<0){best=(*lst)[i];best_k=ki;}
                }
                return best;
            }
            // Multiple args: min(a,b,c)
            VMVal best=a[0];
            for(size_t i=1;i<a.size();i++) if(cmp_val(a[i],best)<0) best=a[i];
            return best;
        });
        globals_["max"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_none();
            VMVal key_fn; bool has_key=false;
            if(!a.empty()&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("key")){key_fn=km["key"];has_key=true;}
                a.pop_back();
            }
            if(!has_key&&a.size()>=2&&(a[1].type==VMType::FUNCTION||a[1].type==VMType::NATIVE)){
                key_fn=a[1]; has_key=true; a={a[0]};
            } else if(has_key) { a.resize(1); }
            std::vector<VMVal>* lst=nullptr;
            if(a[0].type==VMType::LIST&&a[0].list) lst=a[0].list.get();
            if(lst&&!lst->empty()){
                auto apply=[&](const VMVal& v)->VMVal{
                    if(!has_key) return v;
                    std::vector<VMVal> kargs={v};
                    std::optional<VMVal> ns=std::nullopt;
                    return vm_call(key_fn,kargs,ns);
                };
                VMVal best=(*lst)[0]; VMVal best_k=apply(best);
                for(size_t i=1;i<lst->size();i++){
                    VMVal ki=apply((*lst)[i]);
                    if(cmp_val(ki,best_k)>0){best=(*lst)[i];best_k=ki;}
                }
                return best;
            }
            VMVal best=a[0];
            for(size_t i=1;i<a.size();i++) if(cmp_val(a[i],best)>0) best=a[i];
            return best;
        });
        globals_["sum"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);
            if(a[0].type==VMType::LIST&&a[0].list){
                double s=0;bool hf=false;
                for(auto& v:*a[0].list){if(v.type==VMType::FLOAT){s+=v.d;hf=true;}else s+=to_d(v);}
                return hf?VMVal::make_float(s):VMVal::make_int((int64_t)s);}
            return VMVal::make_int(0);});
        globals_["input"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty())std::cout<<a[0].to_string();
            std::string line;std::getline(std::cin,line);return VMVal::make_str(line);});
        globals_["chr"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_str(""):VMVal::make_str(std::string(1,(char)a[0].i));});
        globals_["ord"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return(a.empty()||a[0].s.empty())?VMVal::make_int(0):VMVal::make_int((int64_t)(unsigned char)a[0].s[0]);});
        globals_["sqrt"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_float(std::sqrt(to_d(a.empty()?VMVal::make_int(0):a[0])));});
        globals_["pow"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2)return VMVal::make_int(0);
            if(a[0].type==VMType::INT&&a[1].type==VMType::INT&&a[1].i>=0){
                // Float result, matching the interpreter: pow(2,10) is 1024.0
                // there, and a program comparing the two got different types.
                int64_t base=a[0].i,exp=a[1].i,res=1;
                for(int64_t k=0;k<exp;k++) res*=base;
                return VMVal::make_float((double)res);
            }
            return VMVal::make_float(std::pow(to_d(a[0]),to_d(a[1])));});
        globals_["floor"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_int(0):VMVal::make_int((int64_t)std::floor(to_d(a[0])));});
        globals_["ceil"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_int(0):VMVal::make_int((int64_t)std::ceil(to_d(a[0])));});
        globals_["round"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_int(0);
            if(a.size()==1)return VMVal::make_int((int64_t)std::round(to_d(a[0])));
            double f=std::pow(10,a[1].i);
            return VMVal::make_float(std::round(to_d(a[0])*f)/f);});
        globals_["list"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_list();
            if(a[0].type==VMType::LIST)return a[0];
            if(a[0].type==VMType::STRING){
                std::vector<VMVal> items;
                for(char c:a[0].s)items.push_back(VMVal::make_str(std::string(1,c)));
                return VMVal::make_list(std::move(items));}
            // Iterators and generators were missing here, so list(range(3)) and
            // list(gen()) both returned [] instead of their elements — a silent
            // wrong answer, not an error. The interpreter drains both.
            if(a[0].type==VMType::ITERATOR&&a[0].iter)
                return VMVal::make_list(std::vector<VMVal>(
                    a[0].iter->second.begin()+a[0].iter->first,
                    a[0].iter->second.end()));
            if(a[0].type==VMType::GENERATOR){
                std::vector<VMVal> r;
                VMVal gen=a[0];
                while(gen.gen&&!gen.gen->done){
                    VMVal v=gen_next(gen);
                    if(!gen.gen||gen.gen->done) break;
                    r.push_back(v);
                }
                return VMVal::make_list(std::move(r));}
            return VMVal::make_list();});
        globals_["dict"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{return VMVal::make_map();});
        // Tag the type-constructor builtins with the type name they build, so
        // isinstance(x, list) — passing the bare builtin, not a string — has
        // something to compare against. Done once, after every builtin above
        // has taken its final binding (list/dict are each registered twice;
        // this reads whichever registration actually won), rather than at
        // each individual registration site.
        for(auto& nm_canon : std::vector<std::pair<std::string,std::string>>{
                {"int","int"},{"float","float"},{"bool","bool"},{"str","str"},
                {"string","str"},{"list","list"},{"tuple","list"},
                {"dict","map"},{"set","list"}}){
            auto git=globals_.find(nm_canon.first);
            if(git!=globals_.end()&&git->second.type==VMType::NATIVE)
                git->second.class_name=nm_canon.second;
        }
        globals_["isinstance"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            VMVal& obj=a[0]; VMVal& cls=a[1];
            std::string cls_name;
            if(cls.type==VMType::CLASS) cls_name=cls.class_name;
            else if(cls.type==VMType::STRING) cls_name=cls.s;
            // isinstance(x, list) / isinstance(x, int): the bare builtin, not
            // a string. These are tagged with the type they build above.
            else if(cls.type==VMType::NATIVE&&!cls.class_name.empty()) cls_name=cls.class_name;
            else return VMVal::make_bool(false);
            if(obj.type!=VMType::INSTANCE){
                // Builtin/primitive types by name, e.g. isinstance(42, "int").
                // Only the class-instance case below was handled, so this
                // always read false; mirrors the interpreter's alias set
                // (dispatch_tensor's isinstance in src/builtins/tensor.cpp).
                if(cls_name=="int"||cls_name=="integer") return VMVal::make_bool(obj.type==VMType::INT);
                if(cls_name=="float"||cls_name=="double") return VMVal::make_bool(obj.type==VMType::FLOAT);
                if(cls_name=="bool"||cls_name=="boolean") return VMVal::make_bool(obj.type==VMType::BOOL);
                if(cls_name=="str"||cls_name=="string") return VMVal::make_bool(obj.type==VMType::STRING);
                if(cls_name=="list"||cls_name=="array") return VMVal::make_bool(obj.type==VMType::LIST);
                if(cls_name=="map"||cls_name=="dict") return VMVal::make_bool(obj.type==VMType::MAP);
                if(cls_name=="none") return VMVal::make_bool(obj.type==VMType::NONE);
                if(cls_name=="function") return VMVal::make_bool(obj.type==VMType::FUNCTION||obj.type==VMType::NATIVE);
                return VMVal::make_bool(false);
            }
            // Walk inheritance chain
            std::string cur=obj.class_name;
            while(!cur.empty()){
                if(cur==cls_name) return VMVal::make_bool(true);
                auto cit=class_reg_.find(cur);
                if(cit==class_reg_.end()) break;
                cur=cit->second->parent_class;
            }
            return VMVal::make_bool(false);
        });
        globals_["hex"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("0x0");
            std::ostringstream oss;oss<<"0x"<<std::hex<<a[0].i;return VMVal::make_str(oss.str());});
        globals_["bin"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("0b0");
            int64_t n=a[0].i;if(n==0)return VMVal::make_str("0b0");
            std::string r;while(n>0){r=(char)('0'+(n&1))+r;n>>=1;}
            return VMVal::make_str("0b"+r);});
        globals_["oct"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty())return VMVal::make_str("0o0");
            std::ostringstream oss;oss<<"0o"<<std::oct<<a[0].i;return VMVal::make_str(oss.str());});
        // Constants
        globals_["none"]=VMVal::make_none();
        globals_["true"]=VMVal::make_bool(true);
        // ── Built-in exception classes ────────────────────────────────────────
        auto make_exc_class = [this](const std::string& cname) {
            globals_[cname] = VMVal::make_native([cname](std::vector<VMVal>& a) -> VMVal {
                auto attrs = std::make_shared<std::unordered_map<std::string,VMVal>>();
                std::string msg = a.empty() ? cname : a[0].to_string();
                (*attrs)["msg"] = VMVal::make_str(msg);
                (*attrs)["args"] = VMVal::make_list(a);
                return VMVal::make_instance(cname, attrs);
            });
        };
        for(auto& en : std::vector<std::string>{
            "Exception","BaseException","ValueError","TypeError","ZeroDivisionError",
            "KeyError","IndexError","AttributeError","RuntimeError","NameError",
            "StopIteration","NotImplementedError","OverflowError","OSError","IOError",
            "FileNotFoundError","PermissionError","TimeoutError","ConnectionError",
            "ImportError","SyntaxError","AssertionError","ArithmeticError"
        }) make_exc_class(en);
        globals_["false"]=VMVal::make_bool(false);
        globals_["null"]=VMVal::make_none();
        globals_["PI"]  =VMVal::make_float(3.14159265358979323846);
        globals_["E"]   =VMVal::make_float(2.71828182845904523536);
        globals_["INFINITY"]=VMVal::make_float(std::numeric_limits<double>::infinity());
        // Time builtins (always available)
        globals_["time"]=globals_["time_now"]=globals_["clock"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{
            // std::time() truncates to whole seconds, so elapsed-time code that
            // works on the interpreter measured 0 here. Match the interpreter's
            // sub-second resolution.
            struct timespec ts; clock_gettime(CLOCK_REALTIME,&ts);
            return VMVal::make_float((double)ts.tv_sec+(double)ts.tv_nsec/1e9);});
        globals_["time_ms"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{
            struct timespec ts; clock_gettime(CLOCK_REALTIME,&ts);
            return VMVal::make_float(ts.tv_sec*1000.0+ts.tv_nsec/1e6);});
        globals_["sleep"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()){struct timespec ts{(time_t)(int)to_d(a[0]),(long)((to_d(a[0])-(int)to_d(a[0]))*1e9)};nanosleep(&ts,nullptr);}
            return VMVal::make_none();});
        globals_["sleep_ms"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(!a.empty()){long ms=(long)to_d(a[0]);struct timespec ts{ms/1000,(ms%1000)*1000000L};nanosleep(&ts,nullptr);}
            return VMVal::make_none();});
        globals_["uuid"]=globals_["gen_uuid"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{
            // Simple UUID v4-like string
            static std::mt19937 rng(std::random_device{}());
            std::uniform_int_distribution<int> d(0,15);
            const char* h="0123456789abcdef"; std::string r="whk_";
            for(int i=0;i<8;i++) r+=h[d(rng)];
            return VMVal::make_str(r);});
        globals_["println"]=globals_["print"];

        // ── Map / collection builtins ─────────────────────────────────────
        globals_["keys"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            if((a[0].type==VMType::MAP||a[0].type==VMType::INSTANCE)&&a[0].map){
                std::vector<VMVal> ks;
                for(auto& [k,v]:*a[0].map) if(v.type!=VMType::NONE) ks.push_back(VMVal::make_str(k));
                return VMVal::make_list(std::move(ks));}
            // Not a container: the interpreter returns none here, not [].
            return VMVal::make_none();});
        globals_["values"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            if((a[0].type==VMType::MAP||a[0].type==VMType::INSTANCE)&&a[0].map){
                std::vector<VMVal> vs;
                for(auto& [k,v]:*a[0].map) if(v.type!=VMType::NONE) vs.push_back(v);
                return VMVal::make_list(std::move(vs));}
            // Not a container: the interpreter returns none here, not [].
            return VMVal::make_none();});
        globals_["items"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            if((a[0].type==VMType::MAP||a[0].type==VMType::INSTANCE)&&a[0].map){
                std::vector<VMVal> its;
                for(auto& [k,v]:*a[0].map){
                    if(v.type==VMType::NONE) continue;
                    std::vector<VMVal> pair={VMVal::make_str(k),v};
                    its.push_back(VMVal::make_list(std::move(pair)));}
                return VMVal::make_list(std::move(its));}
            // Not a container: the interpreter returns none here, not [].
            return VMVal::make_none();});
        globals_["sorted"]=VMVal::make_native([this](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            VMVal key_fn; bool has_key=false; bool rev=false;
            // CALL_KW appends the keyword map as the last argument for natives,
            // so read key/reverse from it. This definition overrides the earlier
            // one, which did handle kwargs; without this, sorted(xs, reverse=true)
            // silently ignored reverse.
            if(a.size()>=2&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("key")){key_fn=km["key"];has_key=true;}
                if(km.count("reverse")&&km["reverse"].type==VMType::BOOL) rev=km["reverse"].b;
                a.pop_back();
            }
            if(!has_key&&a.size()>=2&&(a[1].type==VMType::FUNCTION||a[1].type==VMType::NATIVE)){key_fn=a[1];has_key=true;}
            if(!rev&&a.size()>=3&&a[2].type==VMType::BOOL&&a[2].b) rev=true;
            std::vector<VMVal> lst=(a[0].type==VMType::LIST&&a[0].list)?*a[0].list:a;
            // This definition overrides the earlier one, so it carries the same
            // decorate-sort-undecorate fix: calling the key function from inside
            // the comparator re-enters the VM mid-sort and segfaults.
            std::vector<std::pair<VMVal,VMVal>> decorated;
            decorated.reserve(lst.size());
            for(auto& v : lst){
                if(has_key){
                    std::vector<VMVal> kargs={v};
                    decorated.emplace_back(vm_call(key_fn,kargs,std::nullopt), v);
                } else {
                    decorated.emplace_back(v, v);
                }
            }
            std::stable_sort(decorated.begin(),decorated.end(),
                [rev](const std::pair<VMVal,VMVal>& x,const std::pair<VMVal,VMVal>& y){
                    int c2=cmp_val(x.first,y.first);
                    return rev?c2>0:c2<0;
                });
            std::vector<VMVal> out;
            out.reserve(decorated.size());
            for(auto& d : decorated) out.push_back(d.second);
            return VMVal::make_list(std::move(out));
        });
        globals_["reversed"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            std::vector<VMVal> v=*a[0].list; std::reverse(v.begin(),v.end());
            return VMVal::make_list(std::move(v));});
        // Set(iterable) -> deduplicated list, which is how the VM's set methods
        // (add / remove / union / ...) already represent sets. It was simply
        // never exposed as a global, so Set([1,2,3]) produced nothing.
        globals_["Set"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            std::vector<VMVal> out;
            std::unordered_set<std::string> seen;
            if(!a.empty()&&a[0].type==VMType::LIST&&a[0].list){
                for(auto& v:*a[0].list){
                    std::string k=v.to_string();
                    if(seen.insert(k).second) out.push_back(v);
                }
            }
            return VMVal::make_list(std::move(out));});
        globals_["enumerate"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||a[0].type!=VMType::LIST||!a[0].list) return VMVal::make_list();
            int64_t start=0;
            // Check kwargs_map (last arg, MAP type) for start= keyword
            if(a.size()>=2&&a.back().type==VMType::MAP&&a.back().map){
                auto& km=*a.back().map;
                if(km.count("start")){
                    auto& sv=km.at("start");
                    if(sv.type==VMType::INT) start=sv.i;
                    else if(sv.type==VMType::FLOAT) start=(int64_t)sv.d;
                }
                a.pop_back();
            }
            // Positional start arg
            if(a.size()>=2){
                if(a[1].type==VMType::INT) start=a[1].i;
                else if(a[1].type==VMType::FLOAT) start=(int64_t)a[1].d;
            }
            std::vector<VMVal> res;
            for(auto& v:*a[0].list){
                std::vector<VMVal> pair={VMVal::make_int(start++),v};
                res.push_back(VMVal::make_list(std::move(pair)));}
            return VMVal::make_list(std::move(res));});
        globals_["zip"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::LIST||a[1].type!=VMType::LIST) return VMVal::make_list();
            std::vector<VMVal> res;
            size_t n=std::min(a[0].list->size(),a[1].list->size());
            for(size_t i=0;i<n;i++){
                std::vector<VMVal> pair={(*a[0].list)[i],(*a[1].list)[i]};
                res.push_back(VMVal::make_list(std::move(pair)));}
            return VMVal::make_list(std::move(res));});
        globals_["has_key"]=globals_["dict_has"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2||a[0].type!=VMType::MAP||!a[0].map) return VMVal::make_bool(false);
            return VMVal::make_bool(a[0].map->count(a[1].to_string())>0);});
        globals_["contains_key"]=globals_["has_key"];
        globals_["copy"]=globals_["deepcopy"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return a.empty()?VMVal::make_none():a[0];});
        globals_["id"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            // Only checked a[0].list, so id() on anything but a LIST (a map,
            // instance, function, string, int...) fell through to a null
            // shared_ptr and always returned 0. Use whichever backing
            // pointer the value actually has; primitives fall back to a
            // stable hash so id(x) is at least non-zero and repeatable.
            if(a.empty()) return VMVal::make_int(0);
            VMVal& v=a[0];
            uintptr_t raw=0;
            switch(v.type){
                case VMType::LIST:      raw=(uintptr_t)v.list.get(); break;
                case VMType::MAP:
                case VMType::INSTANCE:  raw=(uintptr_t)v.map.get();  break;
                case VMType::FUNCTION:
                case VMType::CLASS:     raw=(uintptr_t)v.code.get(); break;
                case VMType::ITERATOR:  raw=(uintptr_t)v.iter.get(); break;
                case VMType::GENERATOR: raw=(uintptr_t)v.gen.get();  break;
                default: raw=0; break;
            }
            if(raw) return VMVal::make_int((int64_t)(raw & 0x7fffffffffffffffULL));
            uint64_t h=std::hash<std::string>{}(v.to_string()+"|"+std::to_string((int)v.type));
            return VMVal::make_int((int64_t)(h & 0x7fffffffffffffffULL));});
        globals_["hash"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_int(0);
            uint64_t h=std::hash<std::string>{}(a[0].to_string());
            return VMVal::make_int((int64_t)(h & 0x7fffffffffffffffULL));});
        globals_["random"]=VMVal::make_native([](std::vector<VMVal>&)->VMVal{return VMVal::make_float((double)rand()/(double)RAND_MAX);});
        globals_["randint"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            int64_t lo=a.size()>0?(a[0].type==VMType::INT?a[0].i:(int64_t)to_d(a[0])):0;
            int64_t hi=a.size()>1?(a[1].type==VMType::INT?a[1].i:(int64_t)to_d(a[1])):100;
            return VMVal::make_int(lo+(rand()%(hi-lo+1)));});
        globals_["assert_fn"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()||!a[0].is_truthy()) throw std::runtime_error(a.size()>1?a[1].to_string():"AssertionError");
            return VMVal::make_none();});
        globals_["error"]=globals_["raise_error"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            throw std::runtime_error(a.empty()?"error":a[0].to_string()); return VMVal::make_none();});

        // ── String utility builtins (used by stdlib.ny) ─────────────────
        auto split_fn=[](const std::string& s,const std::string& sep)->VMVal{
            std::vector<VMVal> parts;
            if(sep.empty()){
                // split on whitespace
                std::istringstream ss(s); std::string tok;
                while(ss>>tok) parts.push_back(VMVal::make_str(tok));
            } else {
                size_t start=0,pos;
                while((pos=s.find(sep,start))!=std::string::npos){
                    parts.push_back(VMVal::make_str(s.substr(start,pos-start)));
                    start=pos+sep.size();
                }
                parts.push_back(VMVal::make_str(s.substr(start)));
            }
            return VMVal::make_list(std::move(parts));
        };
        globals_["string_split"]=globals_["str_split"]=VMVal::make_native([split_fn](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_list();
            std::string s=a[0].s;
            std::string sep=a.size()>1?a[1].s:" ";
            return split_fn(s,sep);
        });
        globals_["string_join"]=globals_["str_join"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_str("");
            // Accept both: string_join(list, sep) and string_join(sep, list)
            const VMVal* lst_ptr=nullptr; std::string sep="";
            if(a[0].type==VMType::LIST&&a[0].list){lst_ptr=&a[0];sep=a[1].to_string();}
            else if(a[1].type==VMType::LIST&&a[1].list){sep=a[0].to_string();lst_ptr=&a[1];}
            if(!lst_ptr) return VMVal::make_str("");
            std::string r; bool first=true;
            for(auto& v:*lst_ptr->list){if(!first)r+=sep;r+=v.to_string();first=false;}
            return VMVal::make_str(r);
        });
        globals_["string_contains"]=globals_["str_contains"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            return VMVal::make_bool(a[0].s.find(a[1].s)!=std::string::npos);
        });
        globals_["string_replace"]=globals_["str_replace"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return VMVal::make_str(a.empty()?"":a[0].s);
            std::string s=a[0].s,from=a[1].s,to=a[2].s,res;
            size_t pos=0,found;
            while((found=s.find(from,pos))!=std::string::npos){res+=s.substr(pos,found-pos)+to;pos=found+from.size();}
            return VMVal::make_str(res+s.substr(pos));
        });
        globals_["string_upper"]=globals_["str_upper"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string s=a[0].s; for(auto& c:s) c=(char)::toupper((unsigned char)c);
            return VMVal::make_str(s);
        });
        globals_["string_lower"]=globals_["str_lower"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string s=a[0].s; for(auto& c:s) c=(char)::tolower((unsigned char)c);
            return VMVal::make_str(s);
        });
        globals_["string_starts"]=globals_["str_startswith"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            return VMVal::make_bool(a[0].s.substr(0,a[1].s.size())==a[1].s);
        });
        globals_["string_ends"]=globals_["str_endswith"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::string& s=a[0].s,&e=a[1].s;
            return VMVal::make_bool(s.size()>=e.size()&&s.substr(s.size()-e.size())==e);
        });
        globals_["string_trim"]=globals_["str_strip"]=globals_["string_strip"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string s=a[0].s;
            size_t b=s.find_first_not_of(" \t\r\n"),e=s.find_last_not_of(" \t\r\n");
            return VMVal::make_str(b==std::string::npos?"":s.substr(b,e-b+1));
        });
        globals_["string_count"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_int(0);
            const std::string& s=a[0].s,&sub=a[1].s; int c=0; size_t pos=0;
            while((pos=s.find(sub,pos))!=std::string::npos){c++;pos+=sub.size();}
            return VMVal::make_int(c);
        });
        globals_["string_find"]=globals_["string_index"]=globals_["str_find"]=globals_["str_index"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_int(-1);
            size_t p=a[0].s.find(a[1].s);
            return p==std::string::npos?VMVal::make_int(-1)
                                       :VMVal::make_int((int64_t)u8_char_at(a[0].s,p));
        });
        globals_["string_rfind"]=globals_["str_rfind"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_int(-1);
            size_t p=a[0].s.rfind(a[1].s);
            return p==std::string::npos?VMVal::make_int(-1)
                                       :VMVal::make_int((int64_t)u8_char_at(a[0].s,p));
        });
        globals_["string_sub"]=globals_["string_slice"]=globals_["str_sub"]=globals_["str_slice"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            const std::string& s=a[0].s;
            int64_t n=(int64_t)u8_chars(s);   // characters, matching len()
            int64_t st=a.size()>1?(a[1].type==VMType::INT?a[1].i:(int64_t)to_d(a[1])):0;
            int64_t en=a.size()>2?(a[2].type==VMType::INT?a[2].i:(int64_t)to_d(a[2])):n;
            if(st<0)st+=n; if(en<0)en+=n;
            st=std::max((int64_t)0,std::min(st,n));
            en=std::max((int64_t)0,std::min(en,n));
            if(en<st) en=st;
            size_t b0=u8_byte_at(s,(size_t)st), b1=u8_byte_at(s,(size_t)en);
            return VMVal::make_str(b1>b0?s.substr(b0,b1-b0):"");
        });
        globals_["string_char"]=globals_["str_char"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_str("");
            const std::string& s=a[0].s; int64_t i=a[1].type==VMType::INT?a[1].i:(int64_t)to_d(a[1]);
            if(i<0)i+=(int64_t)s.size();
            return (i>=0&&i<(int64_t)s.size())?VMVal::make_str(std::string(1,s[i])):VMVal::make_str("");
        });
        globals_["string_repeat"]=globals_["str_repeat"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_str("");
            int64_t n=a[1].type==VMType::INT?a[1].i:(int64_t)to_d(a[1]);
            std::string r; for(int64_t i=0;i<n;i++) r+=a[0].s; return VMVal::make_str(r);
        });
        globals_["string_replace"]=globals_["str_replace"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return VMVal::make_str(a.empty()?"":a[0].s);
            std::string s=a[0].s,from=a[1].s,to=a[2].s; size_t p=0;
            while((p=s.find(from,p))!=std::string::npos){s.replace(p,from.size(),to);p+=to.size();}
            return VMVal::make_str(s);
        });
        globals_["string_to_int"]=globals_["str_to_int"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_int(0);
            try{return VMVal::make_int(std::stoll(a[0].s));}catch(...){return VMVal::make_int(0);}
        });
        globals_["string_to_float"]=globals_["str_to_float"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_float(0.0);
            try{return VMVal::make_float(std::stod(a[0].s));}catch(...){return VMVal::make_float(0.0);}
        });
        globals_["string_reverse"]=globals_["str_reverse"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string r=a[0].s; std::reverse(r.begin(),r.end()); return VMVal::make_str(r);
        });
        globals_["string_startswith"]=globals_["str_startswith"]=globals_["string_starts"]=globals_["str_starts"]=globals_["string_has_prefix"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::string& s=a[0].s,& p=a[1].s;
            return VMVal::make_bool(s.size()>=p.size()&&s.substr(0,p.size())==p);
        });
        globals_["string_endswith"]=globals_["str_endswith"]=globals_["string_ends"]=globals_["str_ends"]=globals_["string_has_suffix"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<2) return VMVal::make_bool(false);
            std::string& s=a[0].s,& e=a[1].s;
            return VMVal::make_bool(s.size()>=e.size()&&s.substr(s.size()-e.size())==e);
        });
        globals_["string_len"]=globals_["str_len"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            return VMVal::make_int(a.empty()?0:(int64_t)a[0].s.size());
        });
        globals_["string_upper"]=globals_["str_upper_fn"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string r=a[0].s; for(auto& c:r) c=(char)toupper((unsigned char)c); return VMVal::make_str(r);
        });
        globals_["string_lower_fn"]=globals_["str_lower_fn"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string r=a[0].s; for(auto& c:r) c=(char)tolower((unsigned char)c); return VMVal::make_str(r);
        });
        globals_["hex_color"]=globals_["color_hex"]=globals_["rgb_to_hex"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.size()<3) return VMVal::make_str("#000000");
            int r=std::max(0,std::min(255,(int)(a[0].type==VMType::INT?a[0].i:to_d(a[0]))));
            int g=std::max(0,std::min(255,(int)(a[1].type==VMType::INT?a[1].i:to_d(a[1]))));
            int b=std::max(0,std::min(255,(int)(a[2].type==VMType::INT?a[2].i:to_d(a[2]))));
            char buf[8]; snprintf(buf,sizeof(buf),"#%02x%02x%02x",r,g,b);
            return VMVal::make_str(buf);
        });
        globals_["string_format"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_str("");
            std::string s=a[0].s,r; size_t arg=1,pos=0,found;
            while((found=s.find("{}",pos))!=std::string::npos){
                r+=s.substr(pos,found-pos);
                r+=(arg<a.size()?a[arg++].to_string():"");
                pos=found+2;
            }
            return VMVal::make_str(r+s.substr(pos));
        });
        // count_words helper used by StringUtils
        globals_["count_words"]=VMVal::make_native([](std::vector<VMVal>& a)->VMVal{
            if(a.empty()) return VMVal::make_int(0);
            std::istringstream ss(a[0].s); std::string tok; int c=0;
            while(ss>>tok) c++;
            return VMVal::make_int(c);
        });
        // JSON encode/decode globals
        
    }

    // ── Disassembly helper ──────────────────────────────────────────────
    static std::string op_name(Op op) {
        switch(op){
        case Op::LOAD_CONST:   return "LOAD_CONST";
        case Op::LOAD_NAME:    return "LOAD_NAME";
        case Op::STORE_NAME:   return "STORE_NAME";
        case Op::DEFINE_NAME:  return "DEFINE_NAME";
        case Op::LOAD_ATTR:    return "LOAD_ATTR";
        case Op::STORE_ATTR:   return "STORE_ATTR";
        case Op::LOAD_SUBSCR:  return "LOAD_SUBSCR";
        case Op::STORE_SUBSCR: return "STORE_SUBSCR";
        case Op::BUILD_LIST:   return "BUILD_LIST";
        case Op::BUILD_MAP:    return "BUILD_MAP";
        case Op::DUP_TOP:      return "DUP_TOP";
        case Op::POP_TOP:      return "POP_TOP";
        case Op::ROT_TWO:      return "ROT_TWO";
        case Op::BINARY_ADD:   return "BINARY_ADD";
        case Op::BINARY_SUB:   return "BINARY_SUB";
        case Op::BINARY_MUL:   return "BINARY_MUL";
        case Op::BINARY_DIV:   return "BINARY_DIV";
        case Op::BINARY_MOD:   return "BINARY_MOD";
        case Op::BINARY_POW:   return "BINARY_POW";
        case Op::BINARY_FLOOR_DIV: return "BINARY_FLOOR_DIV";
        case Op::BINARY_AND:   return "BINARY_AND";
        case Op::BINARY_OR:    return "BINARY_OR";
        case Op::BINARY_XOR:   return "BINARY_XOR";
        case Op::BINARY_LSHIFT:return "BINARY_LSHIFT";
        case Op::BINARY_RSHIFT:return "BINARY_RSHIFT";
        case Op::COMPARE_EQ:   return "COMPARE_EQ";
        case Op::COMPARE_NE:   return "COMPARE_NE";
        case Op::COMPARE_LT:   return "COMPARE_LT";
        case Op::COMPARE_LE:   return "COMPARE_LE";
        case Op::COMPARE_GT:   return "COMPARE_GT";
        case Op::COMPARE_GE:   return "COMPARE_GE";
        case Op::COMPARE_IN:   return "COMPARE_IN";
        case Op::COMPARE_NOT_IN: return "COMPARE_NOT_IN";
        case Op::COMPARE_IS:   return "COMPARE_IS";
        case Op::COMPARE_IS_NOT: return "COMPARE_IS_NOT";
        case Op::UNARY_NEG:    return "UNARY_NEG";
        case Op::UNARY_NOT:    return "UNARY_NOT";
        case Op::UNARY_BITNOT: return "UNARY_BITNOT";
        case Op::JUMP_FORWARD: return "JUMP_FORWARD";
        case Op::JUMP_IF_TRUE: return "JUMP_IF_TRUE";
        case Op::JUMP_IF_FALSE:return "JUMP_IF_FALSE";
        case Op::JUMP_ABSOLUTE:return "JUMP_ABSOLUTE";
        case Op::JUMP_IF_TRUE_OR_POP:  return "JUMP_IF_TRUE_OR_POP";
        case Op::JUMP_IF_FALSE_OR_POP: return "JUMP_IF_FALSE_OR_POP";
        case Op::MAKE_FUNCTION:return "MAKE_FUNCTION";
        case Op::CALL_FUNCTION:return "CALL_FUNCTION";
        case Op::CALL_METHOD:  return "CALL_METHOD";
        case Op::CALL_EX:      return "CALL_EX";
        case Op::LIST_EXTEND:  return "LIST_EXTEND";
        case Op::LIST_APPEND:  return "LIST_APPEND";
        case Op::LOAD_SUPER:   return "LOAD_SUPER";
        case Op::RETURN_VALUE: return "RETURN_VALUE";
        case Op::YIELD_FROM_OP: return "YIELD_FROM_OP";
        case Op::MAKE_CLASS:   return "MAKE_CLASS";
        case Op::LOAD_SELF:    return "LOAD_SELF";
        case Op::GET_ITER:     return "GET_ITER";
        case Op::FOR_ITER:     return "FOR_ITER";
        case Op::UNPACK_SEQ:   return "UNPACK_SEQ";
        case Op::PRINT:        return "PRINT";
        case Op::IMPORT_NAME:  return "IMPORT_NAME";
        case Op::NOP:          return "NOP";
        case Op::HALT:         return "HALT";
        case Op::RAISE_ERROR:  return "RAISE_ERROR";
        case Op::SETUP_EXCEPT: return "SETUP_EXCEPT";
        case Op::END_EXCEPT:   return "END_EXCEPT";
        default:               return "???";
        }
    }
};

using VM = VirtualMachine;

} // namespace nython::vm

#pragma GCC diagnostic pop

#endif // VIRTUAL_MACHINE_HPP
