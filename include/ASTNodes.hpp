#ifndef NYTHON_AST_NODES_HPP
#define NYTHON_AST_NODES_HPP
/*=============================================================================
 * Nython — ASTNodes.hpp — All concrete AST node types with FULL eval()
 *=============================================================================*/
#include "Node.hpp"
#include "Script.hpp"
#include "RuntimeHelper.hpp"

namespace nython::node {

using namespace nython::runtime;

template<typename T, typename... Args>
inline node_ptr make_node(Args&&... args) { return std::make_shared<T>(std::forward<Args>(args)...); }

// ═══════════════════════════════════════════════════════════════════════════
// SIGNAL TYPES for break/continue/return
// ═══════════════════════════════════════════════════════════════════════════
struct BreakSignal {};
struct ContinueSignal {};
struct ReturnSignal { Value value; ReturnSignal(Value v) : value(v) {} };
struct YieldSignal  { Value value; YieldSignal(Value v)  : value(v) {}  };

// ═══════════════════════════════════════════════════════════════════════════
// LITERALS
// ═══════════════════════════════════════════════════════════════════════════

struct IntegerNode : Node {
    IntegerNode(Token t) : Node(t, NodeType::INTEGER) {}
    Value eval(Context* ctx) override {
        auto& v = _token.value;
        try {
            if (v.size()>2 && v[0]=='0') {
                if(v[1]=='x'||v[1]=='X') return Value((int)std::stoll(v,nullptr,16));
                if(v[1]=='o'||v[1]=='O') return Value((int)std::stoll(v,nullptr,8));
                if(v[1]=='b'||v[1]=='B') return Value((int)std::stoll(v,nullptr,2));
            }
            long long val = std::stoll(v);
            if (val >= INT_MIN && val <= INT_MAX) return Value((int)val);
            return Value((long int)val);
        } catch(...) { return Value(0); }
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Integer value=\"%s\" line=\"%d\"/>\n", _token.value.c_str(), line()); }
};

struct FloatNode : Node {
    FloatNode(Token t) : Node(t, NodeType::FLOAT) {}
    Value eval(Context* ctx) override {
        try { return Value(std::stod(_token.value)); } catch(...) { return Value(0.0); }
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Float value=\"%s\" line=\"%d\"/>\n", _token.value.c_str(), line()); }
};

struct StringNode : Node {
    StringNode(Token t) : Node(t, NodeType::STRING) {}
    Value eval(Context* ctx) override {
        Runnable* r = ctx ? getRunner(ctx) : nullptr;
        return makeString(r, _token.value);
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<String value=\"%s\" line=\"%d\"/>\n", _token.value.c_str(), line()); }
};

struct ComplexNode : Node {
    std::vector<node_ptr> items;
    ComplexNode(Token t) : Node(t, NodeType::COMPLEX), items{} {}
    Value eval(Context* ctx) override {
        try { return Value(std::stod(_token.value)); } catch(...) { return Value(0.0); }
    }
};

struct BoolNode : Node {
    bool val;
    BoolNode(Token t, bool v) : Node(t, v ? NodeType::TRUE : NodeType::FALSE), val(v) {}
    Value eval(Context* ctx) override { return Value(val); }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Bool value=\"%s\" line=\"%d\"/>\n", val?"true":"false", line()); }
};

struct NoneNode : Node {
    NoneNode(Token t) : Node(t, NodeType::NONE) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct UndefinedNode : Node {
    UndefinedNode(Token t) : Node(t, NodeType::UNDEFINED) {}
    Value eval(Context* ctx) override { return UNDEFINED_VALUE; }
};

// ═══════════════════════════════════════════════════════════════════════════
// VARIABLE / IDENTIFIER
// ═══════════════════════════════════════════════════════════════════════════

struct VariableNode : Node {
    std::string name;
    VariableNode(Token t) : Node(t, NodeType::VARIABLE), name(t.value) {}
    std::string value() override { return name; }
    Value eval(Context* ctx) override {
        if (!ctx) return NONE_VALUE;
        return ctx->getByName(name);
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Variable name=\"%s\" line=\"%d\"/>\n", name.c_str(), line()); }
};

struct SelfNode : Node {
    SelfNode(Token t) : Node(t, NodeType::SELF) {}
    Value eval(Context* ctx) override { return ctx ? ctx->getByName("self") : NONE_VALUE; }
};

struct SuperNode : Node {
    SuperNode(Token t) : Node(t, NodeType::SUPER) {}
    Value eval(Context* ctx) override { return ctx ? ctx->getByName("super") : NONE_VALUE; }
};

// ═══════════════════════════════════════════════════════════════════════════
// COLLECTIONS
// ═══════════════════════════════════════════════════════════════════════════

struct ListNode : Node {
    std::vector<node_ptr> elements;
    ListNode(Token t) : Node(t, NodeType::LIST), elements{} {}
    Node* add(node_ptr n) override { elements.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return elements; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value list = makeList(r);
        for (auto& el : elements) appendToCollection(list, el->eval(ctx));
        return list;
    }
};

struct TupleNode : Node {
    std::vector<node_ptr> elements;
    TupleNode(Token t) : Node(t, NodeType::TUPLE), elements{} {}
    Node* add(node_ptr n) override { elements.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return elements; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value tuple = makeTuple(r);
        for (auto& el : elements) appendToCollection(tuple, el->eval(ctx));
        return tuple;
    }
};

struct ArrayNode : Node {
    std::vector<node_ptr> elements;
    ArrayNode(Token t) : Node(t, NodeType::ARRAY), elements{} {}
    Node* add(node_ptr n) override { elements.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return elements; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value arr = makeArray(r);
        for (auto& el : elements) appendToCollection(arr, el->eval(ctx));
        return arr;
    }
};

struct MapEntryNode : Node {
    node_ptr key, val;
    MapEntryNode(Token t, node_ptr k, node_ptr v) : Node(t, NodeType::MAP_ENTRY), key(k), val(v) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct MapNode : Node {
    std::vector<node_ptr> entries;
    MapNode(Token t) : Node(t, NodeType::MAP), entries{} {}
    Node* add(node_ptr n) override { entries.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return entries; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value map = makeMap(r);
        for (auto& e : entries) {
            auto entry = std::static_pointer_cast<MapEntryNode>(e);
            if (entry && map.isObject()) {
                auto* obj = dynamic_cast<Object*>(map.value.gc);
                if (obj) obj->set(entry->key->eval(ctx).toString(), entry->val->eval(ctx));
            }
        }
        return map;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// EXPRESSIONS
// ═══════════════════════════════════════════════════════════════════════════

struct UnaryNode : Node {
    node_ptr operand; std::string op;
    UnaryNode(Token t, node_ptr opnd) : Node(t, NodeType::UNARY), operand(opnd), op(t.value) {}
    Value eval(Context* ctx) override {
        Value v = operand->eval(ctx);
        if (op=="-") return Value(0) - v;
        if (op=="+" ) return v;
        if (op=="!" || op=="not") return Value(!v.isTrue());
        if (op=="~") return ~v;
        if (op=="++" && operand->type()==NodeType::VARIABLE) {
            Value r = v + Value(1); ctx->setByName(operand->value(), r); return r;
        }
        if (op=="--" && operand->type()==NodeType::VARIABLE) {
            Value r = v - Value(1); ctx->setByName(operand->value(), r); return r;
        }
        return v;
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Unary op=\"%s\">\n", op.c_str()); operand->writeToStdOut(p); p.println("</Unary>"); }
};

struct BinaryNode : Node {
    node_ptr left, right; std::string op;
    BinaryNode(Token t, node_ptr l, node_ptr r) : Node(t, NodeType::BINARY), left(l), right(r), op(t.value) {}
    Value eval(Context* ctx) override {
        // Short-circuit
        if (op=="and"||op=="&&") { Value lv=left->eval(ctx); if(lv.isFalse()) return lv; return right->eval(ctx); }
        if (op=="or"||op=="||") { Value lv=left->eval(ctx); if(lv.isTrue()) return lv; return right->eval(ctx); }
        Value lv = left->eval(ctx), rv = right->eval(ctx);
        if (op=="+") return lv+rv;
        if (op=="-") return lv-rv;
        if (op=="*") return lv*rv;
        if (op=="/") return lv/rv;
        if (op=="%") return lv%rv;
        if (op=="==") return Value(lv==rv);
        if (op=="!=") return Value(!(lv==rv));
        return NONE_VALUE;
    }
    void writeToStdOut(PrettyPrinter p) {
        p.printf("<Binary op=\"%s\">\n", op.c_str()); p.indentRight();
        left->writeToStdOut(p); right->writeToStdOut(p);
        p.indentLeft(); p.println("</Binary>");
    }
};

struct AttributeNode : Node {
    node_ptr object; std::string attr;
    AttributeNode(Token t, node_ptr o, const std::string& a) : Node(t, NodeType::ATTRIBUTE), object(o), attr(a) {}
    Value eval(Context* ctx) override {
        Value obj = object->eval(ctx);
        if (obj.isObject() && obj.value.gc) {
            auto* o = dynamic_cast<Object*>(obj.value.gc);
            if (o) return o->get(attr);
        }
        return NONE_VALUE;
    }
};

struct SubscriptNode : Node {
    node_ptr object, index;
    SubscriptNode(Token t, node_ptr o, node_ptr i) : Node(t, NodeType::SUBSCRIPT), object(o), index(i) {}
    Value eval(Context* ctx) override {
        Value obj = object->eval(ctx);
        Value idx = index->eval(ctx);
        if (obj.isObject() && obj.value.gc) {
            auto* o = dynamic_cast<Object*>(obj.value.gc);
            if (o) return o->get(idx);
        }
        return NONE_VALUE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// ASSIGNMENT
// ═══════════════════════════════════════════════════════════════════════════

struct AssignmentNode : Node {
    node_ptr target, value_node;
    AssignmentNode(Token t, node_ptr tgt, node_ptr val) : Node(t, NodeType::ASSIGNMENT), target(tgt), value_node(val) {}
    Value eval(Context* ctx) override {
        Value val = value_node->eval(ctx);
        if (target->type() == NodeType::VARIABLE) ctx->setByName(target->value(), val);
        else if (target->type() == NodeType::ATTRIBUTE) {
            auto attr = std::static_pointer_cast<AttributeNode>(target);
            Value obj = attr->object->eval(ctx);
            if (obj.isObject()) { auto* o = dynamic_cast<Object*>(obj.value.gc); if(o) o->set(attr->attr, val); }
        }
        else if (target->type() == NodeType::SUBSCRIPT) {
            auto sub = std::static_pointer_cast<SubscriptNode>(target);
            Value obj = sub->object->eval(ctx);
            Value idx = sub->index->eval(ctx);
            if (obj.isObject()) { auto* o = dynamic_cast<Object*>(obj.value.gc); if(o) o->set(idx, val); }
        }
        return val;
    }
};

struct AugAssignNode : Node {
    node_ptr target, value_node; std::string op;
    AugAssignNode(Token t, node_ptr tgt, node_ptr val) : Node(t, NodeType::ASSIGNMENT_AUG), target(tgt), value_node(val), op(t.value) {}
    Value eval(Context* ctx) override {
        Value old_val = target->eval(ctx);
        Value new_val = value_node->eval(ctx);
        Value result;
        if (op=="+=") result = old_val + new_val;
        else if (op=="-=") result = old_val - new_val;
        else if (op=="*=") result = old_val * new_val;
        else if (op=="/=") result = old_val / new_val;
        else if (op=="%=") result = old_val % new_val;
        else result = new_val;
        if (target->type() == NodeType::VARIABLE) ctx->setByName(target->value(), result);
        return result;
    }
};

struct VarDeclNode : Node {
    std::string name; node_ptr init; bool is_const, is_let;
    VarDeclNode(Token t, const std::string& n, node_ptr i, bool c=false, bool l=false) : Node(t, NodeType::VARIABLE_DECL), name(n), init(i), is_const(c), is_let(l) {}
    Value eval(Context* ctx) override {
        Value val = init ? init->eval(ctx) : NONE_VALUE;
        if (ctx) ctx->defineByName(name, val);
        return val;
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<VarDecl name=\"%s\" const=\"%s\"/>\n", name.c_str(), is_const?"true":"false"); }
};

// ═══════════════════════════════════════════════════════════════════════════
// ACCESS
// ═══════════════════════════════════════════════════════════════════════════





struct SliceNode : Node {
    node_ptr start, end_node, step;
    SliceNode(Token t, node_ptr s, node_ptr e, node_ptr st=nullptr) : Node(t, NodeType::SLICE), start(s), end_node(e), step(st) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct RangeNode : Node {
    node_ptr start, end_node, step;
    RangeNode(Token t, node_ptr s, node_ptr e, node_ptr st=nullptr) : Node(t, NodeType::RANGE), start(s), end_node(e), step(st) {}
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        int64_t s = (int64_t)(int)start->eval(ctx);
        int64_t e = (int64_t)(int)end_node->eval(ctx);
        int64_t st = step ? (int64_t)(int)step->eval(ctx) : 1;
        return makeRange(r, s, e, st);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// CALL
// ═══════════════════════════════════════════════════════════════════════════

struct CallNode : Node {
    node_ptr callee; std::vector<node_ptr> args;
    CallNode(Token t, node_ptr c) : Node(t, NodeType::CALL), callee(c), args{} {}
    Node* add(node_ptr n) override { args.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return args; }
    Value eval(Context* ctx) override {
        // Check for built-in functions first
        std::string fname = callee->value();
        if (fname == "range") {
            Runnable* r = getRunner(ctx);
            if (args.size() == 1) return makeRange(r, 0, (int64_t)(int)args[0]->eval(ctx));
            if (args.size() == 2) return makeRange(r, (int64_t)(int)args[0]->eval(ctx), (int64_t)(int)args[1]->eval(ctx));
            if (args.size() >= 3) return makeRange(r, (int64_t)(int)args[0]->eval(ctx), (int64_t)(int)args[1]->eval(ctx), (int64_t)(int)args[2]->eval(ctx));
            return makeList(r);
        }
        if (fname == "len" || fname == "length") {
            if (args.size() >= 1) return Value((int)getLength(args[0]->eval(ctx)));
            return Value(0);
        }
        if (fname == "type" || fname == "typeof") {
            if (args.size() >= 1) {
                Value v = args[0]->eval(ctx);
                Runnable* r = getRunner(ctx);
                if (v.isNone()) return makeString(r, "none");
                if (v.isBoolean()) return makeString(r, "bool");
                if (v.type == kernel::ValueType::INTEGER) return makeString(r, "int");
                if (v.type == kernel::ValueType::DOUBLE) return makeString(r, "float");
                if (v.isObject()) return makeString(r, "object");
                return makeString(r, "unknown");
            }
            return NONE_VALUE;
        }
        if (fname == "str") {
            Runnable* r = getRunner(ctx);
            if (args.size() >= 1) return makeString(r, args[0]->eval(ctx).toString());
            return makeString(r, "");
        }
        if (fname == "int") {
            if (args.size() >= 1) {
                Value v = args[0]->eval(ctx);
                if (v.type == kernel::ValueType::DOUBLE) return Value((int)v.value.d);
                if (v.type == kernel::ValueType::INTEGER) return v;
                try { return Value(std::stoi(v.toString())); } catch(...) { return Value(0); }
            }
            return Value(0);
        }
        if (fname == "float") {
            if (args.size() >= 1) {
                Value v = args[0]->eval(ctx);
                try { return Value(std::stod(v.toString())); } catch(...) { return Value(0.0); }
            }
            return Value(0.0);
        }
        if (fname == "abs") {
            if (args.size() >= 1) {
                Value v = args[0]->eval(ctx);
                if (v.type == kernel::ValueType::INTEGER) { auto i = v.value.i; return Value((int)(i < 0 ? -i : i)); }
                if (v.type == kernel::ValueType::DOUBLE) return Value(std::abs(v.value.d));
            }
            return Value(0);
        }
        if (fname == "min" && args.size() == 2) {
            Value a = args[0]->eval(ctx), b = args[1]->eval(ctx);
            return (a.toString() < b.toString()) ? a : b;
        }
        if (fname == "max" && args.size() == 2) {
            Value a = args[0]->eval(ctx), b = args[1]->eval(ctx);
            return (a.toString() > b.toString()) ? a : b;
        }
        if (fname == "input") {
            if (args.size() >= 1) std::cout << args[0]->eval(ctx).toString();
            std::string line; std::getline(std::cin, line);
            return makeString(getRunner(ctx), line);
        }

        // User-defined function call
        Value fn = callee->eval(ctx);
        if (fn.isObject() && fn.value.gc) {
            // Evaluate arguments
            std::vector<Value> evaluated_args;
            for (auto& a : args) evaluated_args.push_back(a->eval(ctx));
            auto* obj = dynamic_cast<Object*>(fn.value.gc);
            if (obj) return obj->call(evaluated_args);
        }
        return NONE_VALUE;
    }
};

struct KeywordArgNode : Node {
    std::string name; node_ptr val;
    KeywordArgNode(Token t, const std::string& n, node_ptr v) : Node(t, NodeType::KEYWORD_ARG), name(n), val(v) {}
    Value eval(Context* ctx) override { return val ? val->eval(ctx) : NONE_VALUE; }
};

// ═══════════════════════════════════════════════════════════════════════════
// CONTROL FLOW
// ═══════════════════════════════════════════════════════════════════════════

struct StatementsNode : Node {
    std::vector<node_ptr> stmts;
    StatementsNode(Token t) : Node(t, NodeType::STATEMENTS), stmts{} {}
    Node* add(node_ptr n) override { stmts.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return stmts; }
    Value eval(Context* ctx) override { Value r=NONE_VALUE; for(auto& s:stmts) r=s->eval(ctx); return r; }
};

struct BlockNode : Node {
    std::vector<node_ptr> stmts;
    BlockNode(Token t) : Node(t, NodeType::BLOCK), stmts{} {}
    Node* add(node_ptr n) override { stmts.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return stmts; }
    Value eval(Context* ctx) override { Value r=NONE_VALUE; for(auto& s:stmts) r=s->eval(ctx); return r; }
};

struct IfNode : Node {
    node_ptr condition, then_branch, else_branch;
    std::vector<node_ptr> elseif_branches;
    IfNode(Token t, node_ptr c, node_ptr tb) : Node(t, NodeType::IF), condition(c), then_branch(tb), else_branch{}, elseif_branches{} {}
    Value eval(Context* ctx) override {
        if(condition->eval(ctx).isTrue()) return then_branch->eval(ctx);
        for(auto& ei:elseif_branches){
            auto n=std::static_pointer_cast<IfNode>(ei);
            if(n->condition->eval(ctx).isTrue()) return n->then_branch->eval(ctx);
        }
        if(else_branch) return else_branch->eval(ctx);
        return NONE_VALUE;
    }
    void writeToStdOut(PrettyPrinter p) {
        p.println("<If>"); p.indentRight(); p.println("<Condition>"); condition->writeToStdOut(p); p.println("</Condition>");
        p.println("<Then>"); then_branch->writeToStdOut(p); p.println("</Then>");
        if(else_branch){p.println("<Else>"); else_branch->writeToStdOut(p); p.println("</Else>");}
        p.indentLeft(); p.println("</If>");
    }
};

struct WhileNode : Node {
    node_ptr condition, body, else_branch;
    WhileNode(Token t, node_ptr c, node_ptr b) : Node(t, NodeType::WHILE), condition(c), body(b) {}
    Value eval(Context* ctx) override {
        Value r=NONE_VALUE;
        while(condition->eval(ctx).isTrue()){
            try { r=body->eval(ctx); }
            catch(BreakSignal&) { break; }
            catch(ContinueSignal&) { continue; }
        }
        return r;
    }
};

struct ForNode : Node {
    node_ptr var, iterable, body;
    std::vector<node_ptr> unpack_vars;
    node_ptr else_branch; // for tuple unpacking: for k, v in ...
    ForNode(Token t, node_ptr v, node_ptr i, node_ptr b) : Node(t, NodeType::FOR), var(v), iterable(i), body(b), unpack_vars{}, else_branch{} {}
    Value eval(Context* ctx) override {
        Value iter_val = iterable->eval(ctx);
        Value r = NONE_VALUE;
        int64_t len = getLength(iter_val);
        std::string vname = var->value();
        for (int64_t i = 0; i < len; i++) {
            ctx->setByName(vname, getItem(iter_val, (int)i));
            try { r = body->eval(ctx); }
            catch(BreakSignal&) { break; }
            catch(ContinueSignal&) { continue; }
        }
        return r;
    }
};

struct RepeatNode : Node {
    node_ptr count, body;
    RepeatNode(Token t, node_ptr c, node_ptr b) : Node(t, NodeType::REPEAT), count(c), body(b) {}
    Value eval(Context* ctx) override {
        int64_t n = (int64_t)(int)count->eval(ctx);
        Value r=NONE_VALUE;
        for(int64_t i=0;i<n;i++){
            try{r=body->eval(ctx);}
            catch(BreakSignal&){break;} catch(ContinueSignal&){continue;}
        }
        return r;
    }
};

struct BreakNode : Node {
    BreakNode(Token t) : Node(t, NodeType::BREAK) {}
    Value eval(Context* ctx) override { throw BreakSignal{}; return NONE_VALUE; }
};

struct ContinueNode : Node {
    ContinueNode(Token t) : Node(t, NodeType::CONTINUE) {}
    Value eval(Context* ctx) override { throw ContinueSignal{}; return NONE_VALUE; }
};

struct ReturnNode : Node {
    node_ptr expr;
    ReturnNode(Token t, node_ptr e=nullptr) : Node(t, NodeType::RETURN), expr(e) {}
    Value eval(Context* ctx) override { throw ReturnSignal(expr ? expr->eval(ctx) : NONE_VALUE); return NONE_VALUE; }
};

struct YieldNode : Node {
    node_ptr expr;
    YieldNode(Token t, node_ptr e=nullptr) : Node(t, NodeType::YIELD), expr(e) {}
    Value eval(Context* ctx) override { return expr ? expr->eval(ctx) : NONE_VALUE; }
};

struct YieldFromNode : Node {
    node_ptr expr;
    YieldFromNode(Token t, node_ptr e) : Node(t, NodeType::YIELD_FROM), expr(e) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct WalrusNode : Node {
    std::string name;
    node_ptr init;
    WalrusNode(Token t, std::string n, node_ptr e) : Node(t, NodeType::WALRUS), name(std::move(n)), init(e) {}
    Value eval(Context* ctx) override { return init ? init->eval(ctx) : NONE_VALUE; }
};

struct PassNode : Node {
    PassNode(Token t) : Node(t, NodeType::PASS) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct CaseNode : Node {
    node_ptr value_node, body;
    CaseNode(Token t, node_ptr v, node_ptr b) : Node(t, NodeType::CASE), value_node(v), body(b) {}
    Value eval(Context* ctx) override { return body->eval(ctx); }
};

struct DefaultNode : Node {
    node_ptr body;
    DefaultNode(Token t, node_ptr b) : Node(t, NodeType::DEFAULT), body(b) {}
    Value eval(Context* ctx) override { return body->eval(ctx); }
};

struct SwitchNode : Node {
    node_ptr subject; std::vector<node_ptr> cases; node_ptr default_case;
    SwitchNode(Token t, node_ptr s) : Node(t, NodeType::SWITCH), subject(s), cases{}, default_case{} {}
    Node* add(node_ptr n) override { cases.push_back(n); return this; }
    Value eval(Context* ctx) override {
        Value val = subject->eval(ctx);
        for(auto& c:cases){
            auto cn=std::static_pointer_cast<CaseNode>(c);
            if(cn->value_node->eval(ctx)==val) return cn->body->eval(ctx);
        }
        if(default_case) return default_case->eval(ctx);
        return NONE_VALUE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// TRY / EXCEPT / RAISE / ASSERT
// ═══════════════════════════════════════════════════════════════════════════

struct ExceptNode : Node {
    std::string name, alias; node_ptr body;
    ExceptNode(Token t, const std::string& n, const std::string& a, node_ptr b) : Node(t, NodeType::EXCEPT), name(n), alias(a), body(b) {}
    Value eval(Context* ctx) override { return body->eval(ctx); }
};

struct TryNode : Node {
    node_ptr body; std::vector<node_ptr> except_clauses; node_ptr else_clause; node_ptr finally_clause;
    TryNode(Token t, node_ptr b) : Node(t, NodeType::TRY), body(b), except_clauses{}, else_clause{}, finally_clause{} {}
    Value eval(Context* ctx) override {
        Value r = NONE_VALUE;
        try { r = body->eval(ctx); }
        catch(std::exception& e) {
            for(auto& ec:except_clauses) {
                auto en = std::static_pointer_cast<ExceptNode>(ec);
                if(!en->alias.empty()) ctx->defineByName(en->alias, makeString(getRunner(ctx), e.what()));
                r = en->body->eval(ctx);
            }
        } catch(...) {
            for(auto& ec:except_clauses) r=ec->eval(ctx);
        }
        if(finally_clause) finally_clause->eval(ctx);
        return r;
    }
};

struct RaiseNode : Node {
    node_ptr expr;
    RaiseNode(Token t, node_ptr e=nullptr) : Node(t, NodeType::RAISE), expr(e) {}
    Value eval(Context* ctx) override {
        std::string msg = expr ? expr->eval(ctx).toString() : "Exception raised";
        throw std::runtime_error(msg);
    }
};

struct AssertNode : Node {
    node_ptr condition, message;
    AssertNode(Token t, node_ptr c, node_ptr m=nullptr) : Node(t, NodeType::ASSERT), condition(c), message(m) {}
    Value eval(Context* ctx) override {
        if(!condition->eval(ctx).isTrue()){
            std::string msg = message ? message->eval(ctx).toString() : "Assertion failed";
            throw std::runtime_error(msg);
        }
        return NONE_VALUE;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// FUNCTION / CLASS / LAMBDA / ENUM
// ═══════════════════════════════════════════════════════════════════════════

struct FunctionNode : Node {
    std::string name; std::vector<node_ptr> params; node_ptr body; bool is_method;
    std::vector<node_ptr> defaults; // default values for parameters
    FunctionNode(Token t, const std::string& n, node_ptr b, bool m=false) : Node(t, NodeType::FUNCTION), name(n), params{}, body(b), is_method(m), defaults{} {}
    Node* add(node_ptr n) override { params.push_back(n); return this; }
    Value eval(Context* ctx) override {
        // Create function object and register in context
        Runnable* r = getRunner(ctx);
        Value fn = makeFunction(r, name);
        ctx->defineByName(name, fn);
        return fn;
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Function name=\"%s\" params=\"%d\">\n", name.c_str(), (int)params.size()); if(body) body->writeToStdOut(p); p.println("</Function>"); }
};

struct LambdaNode : Node {
    std::vector<node_ptr> params; node_ptr body;
    std::vector<node_ptr> defaults; // default values for parameters
    LambdaNode(Token t, node_ptr b) : Node(t, NodeType::LAMBDA), params{}, body(b), defaults{} {}
    Node* add(node_ptr n) override { params.push_back(n); return this; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        return makeFunction(r, "<lambda>");
    }
};

struct ClassNode : Node {
    std::string name; std::vector<node_ptr> bases; node_ptr body;
    ClassNode(Token t, const std::string& n, node_ptr b) : Node(t, NodeType::CLASS), name(n), bases{}, body(b) {}
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value klass = makeClass(r, name);
        // Evaluate class body in child context
        Context* class_ctx = makeChildContext(ctx, name);
        if(class_ctx && body) body->eval(class_ctx);
        ctx->defineByName(name, klass);
        return klass;
    }
    void writeToStdOut(PrettyPrinter p) { p.printf("<Class name=\"%s\">\n", name.c_str()); if(body) body->writeToStdOut(p); p.println("</Class>"); }
};

struct InterfaceNode : Node {
    std::string name; node_ptr body;
    InterfaceNode(Token t, const std::string& n, node_ptr b) : Node(t, NodeType::INTERFACE), name(n), body(b) {}
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        ctx->defineByName(name, makeClass(r, name));
        return NONE_VALUE;
    }
};

struct EnumItemNode : Node {
    std::string name; node_ptr value_node;
    EnumItemNode(Token t, const std::string& n, node_ptr v=nullptr) : Node(t, NodeType::ENUM_ITEM), name(n), value_node(v) {}
    Value eval(Context* ctx) override { return value_node ? value_node->eval(ctx) : NONE_VALUE; }
};

struct EnumNode : Node {
    std::string name; std::vector<node_ptr> items;
    EnumNode(Token t, const std::string& n) : Node(t, NodeType::ENUM), name(n), items{} {}
    Node* add(node_ptr n) override { items.push_back(n); return this; }
    Value eval(Context* ctx) override {
        Runnable* r = getRunner(ctx);
        Value en = makeMap(r);
        int counter = 0;
        for(auto& item:items){
            auto ei = std::static_pointer_cast<EnumItemNode>(item);
            Value val = ei->value_node ? ei->value_node->eval(ctx) : Value(counter++);
            if(en.isObject()){ auto* o=dynamic_cast<Object*>(en.value.gc); if(o) o->set(ei->name, val); }
        }
        ctx->defineByName(name, en);
        return en;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// IMPORT / PACKAGE / NAMESPACE / MISC
// ═══════════════════════════════════════════════════════════════════════════

struct ImportNode : Node {
    std::string module_name, alias; std::vector<std::string> names;
    ImportNode(Token t, const std::string& m) : Node(t, NodeType::IMPORT), module_name(m), alias{}, names{} {}
    Value eval(Context* ctx) override { return NONE_VALUE; /* module loading not yet implemented */ }
};

struct NameSpaceNode : Node {
    std::string name; node_ptr body;
    NameSpaceNode(Token t, const std::string& n, node_ptr b) : Node(t, NodeType::NAMESPACE), name(n), body(b) {}
    Value eval(Context* ctx) override {
        Context* ns_ctx = makeChildContext(ctx, name);
        if(ns_ctx && body) body->eval(ns_ctx);
        return NONE_VALUE;
    }
};

struct PackageNode : Node {
    std::string name;
    PackageNode(Token t) : Node(t, NodeType::PACKAGE), name(t.value) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct PrintNode : Node {
    std::vector<node_ptr> args;
    PrintNode(Token t) : Node(t, NodeType::PRINT), args{} {}
    Node* add(node_ptr n) override { args.push_back(n); return this; }
    std::vector<node_ptr> statements() override { return args; }
    Value eval(Context* ctx) override {
        for(size_t i=0;i<args.size();i++){
            if(i>0) std::cout<<" ";
            std::cout<<args[i]->eval(ctx).toString();
        }
        std::cout<<std::endl;
        return NONE_VALUE;
    }
};

struct DeleteNode : Node {
    node_ptr target;
    DeleteNode(Token t, node_ptr tgt) : Node(t, NodeType::DELETE), target(tgt) {}
    Value eval(Context* ctx) override { if(ctx && target->type()==NodeType::VARIABLE) ctx->setByName(target->value(), UNDEFINED_VALUE); return NONE_VALUE; }
};

struct GlobalNode : Node {
    std::string name;
    GlobalNode(Token t, const std::string& n) : Node(t, NodeType::GLOBAL), name(n) {}
    Value eval(Context* ctx) override { return NONE_VALUE; }
};

struct WithNode : Node {
    node_ptr expr; std::string alias; node_ptr body;
    WithNode(Token t, node_ptr e, const std::string& a, node_ptr b) : Node(t, NodeType::WITH), expr(e), alias(a), body(b) {}
    Value eval(Context* ctx) override {
        Value val = expr->eval(ctx);
        if(!alias.empty()) ctx->defineByName(alias, val);
        return body ? body->eval(ctx) : NONE_VALUE;
    }
};


// ── MacroCallNode — dynamic macro invocation ─────────────────────────────
// Built by Parser when it sees a dynamic keyword token that has a registered
// MACRO rule. The executor looks up the handler by name and calls it.
struct MacroCallNode : Node {
    std::string macro_name;        // registered DynamicToken name (decoded)
    std::vector<std::string> argv; // raw token values collected to EOL
    MacroCallNode(Token t, const std::string& name, std::vector<std::string> args)
        : Node(t, NodeType::MACRO_CALL), macro_name(name), argv(std::move(args)) {}
    Value eval(Context* ctx) override { return NONE_VALUE; } // handled in executor
};

// ── DynBinopNode — dynamic infix operator ────────────────────────────────
// Built by Parser when it sees a registered dynamic infix operator between
// two expressions. The executor calls the registered handler(lhs, rhs).
struct DynBinopNode : Node {
    std::string op_symbol;   // the operator symbol / name
    node_ptr    lhs, rhs;
    DynBinopNode(Token t, const std::string& sym, node_ptr l, node_ptr r)
        : Node(t, NodeType::DYN_BINOP), op_symbol(sym), lhs(std::move(l)), rhs(std::move(r)) {}
    Value eval(Context* ctx) override { return NONE_VALUE; } // handled in executor
};

} // namespace nython::node
#endif
