#ifndef NYTHON_EVALUATOR_HPP
#define NYTHON_EVALUATOR_HPP
/*=============================================================================
 * Nython — Evaluator.hpp
 * Tree-walking interpreter that evaluates AST nodes against the runtime.
 * Uses Interpreter::create<T>() to allocate GC-managed objects.
 *=============================================================================*/
#include "ASTNodes.hpp"
#include "Interpreter.hpp"
#include "Class.hpp"
#include "VirtualMachine.hpp"

namespace nython::eval {

using namespace nython::node;
using namespace nython::kernel;
using namespace nython::interpreter;

// ─── Signal types for control flow ──────────────────────────────────────────
struct BreakSignal {};
struct ContinueSignal {};
struct ReturnSignal { Value value; };

class Evaluator {
public:
    Evaluator(const Evaluator&) = delete;
    Evaluator& operator=(const Evaluator&) = delete;

    nython::vm::VirtualMachine* runner_;
    Context* global_ctx_;

public:
    Evaluator(nython::vm::VirtualMachine* runner, Context* global_ctx)
        : runner_(runner), global_ctx_(global_ctx) , funcRegistry_{} {}

    // ─── Main entry: evaluate a script ──────────────────────────────────
    Value evalScript(node_ptr node) {
        return eval(node.get(), global_ctx_);
    }

    // ─── Core eval dispatch ─────────────────────────────────────────────
    Value eval(Node* node, Context* ctx) {
        if (!node) return NONE_VALUE;


        switch (node->type()) {
        // Literals
        case NodeType::INTEGER:   return evalInteger(node);
        case NodeType::FLOAT:     return evalFloat(node);
        case NodeType::STRING:    return evalString(node, ctx);
        case NodeType::TRUE:      return Value(true);
        case NodeType::FALSE:     return Value(false);
        case NodeType::NONE:      return NONE_VALUE;
        case NodeType::UNDEFINED: return UNDEFINED_VALUE;
        case NodeType::COMPLEX:   return evalFloat(node);

        // Variables
        case NodeType::VARIABLE:      return evalVariable(node, ctx);
        case NodeType::SELF:          return ctx->getByName("self");
        case NodeType::SUPER:         return ctx->getByName("super");

        // Expressions
        case NodeType::BINARY:        return evalBinary(node, ctx);
        case NodeType::UNARY:         return evalUnary(node, ctx);
        case NodeType::ASSIGNMENT:    return evalAssignment(node, ctx);
        case NodeType::ASSIGNMENT_AUG:return evalAugAssignment(node, ctx);
        case NodeType::VARIABLE_DECL: return evalVarDecl(node, ctx);

        // Access
        case NodeType::ATTRIBUTE:     return evalAttribute(node, ctx);
        case NodeType::SUBSCRIPT:     return evalSubscript(node, ctx);
        case NodeType::CALL:          return evalCall(node, ctx);

        // Collections
        case NodeType::LIST:          return evalList(node, ctx);
        case NodeType::TUPLE:         return evalTuple(node, ctx);
        case NodeType::MAP:           return evalMap(node, ctx);
        case NodeType::ARRAY:         return evalList(node, ctx); // treat as list

        // Control flow
        case NodeType::IF:            return evalIf(node, ctx);
        case NodeType::WHILE:         return evalWhile(node, ctx);
        case NodeType::FOR:           return evalFor(node, ctx);
        case NodeType::REPEAT:        return evalRepeat(node, ctx);
        case NodeType::SWITCH:        return evalSwitch(node, ctx);

        // Flow signals
        case NodeType::BREAK:         throw BreakSignal{};
        case NodeType::CONTINUE:      throw ContinueSignal{};
        case NodeType::RETURN:        return evalReturn(node, ctx);
        case NodeType::YIELD:         return evalYield(node, ctx);
        case NodeType::PASS:          return NONE_VALUE;

        // Definitions
        case NodeType::FUNCTION:      return evalFuncDecl(node, ctx);
        case NodeType::LAMBDA:        return evalLambda(node, ctx);
        case NodeType::CLASS:         return evalClassDecl(node, ctx);
        case NodeType::ENUM:          return evalEnum(node, ctx);
        case NodeType::INTERFACE:     return evalInterface(node, ctx);
        case NodeType::NAMESPACE:     return evalNamespace(node, ctx);

        // Exception handling
        case NodeType::TRY:           return evalTry(node, ctx);
        case NodeType::RAISE:         return evalRaise(node, ctx);
        case NodeType::ASSERT:        return evalAssert(node, ctx);

        // Statements
        case NodeType::PRINT:         return evalPrint(node, ctx);
        case NodeType::DELETE:        return evalDelete(node, ctx);
        case NodeType::IMPORT:        return evalImport(node, ctx);
        case NodeType::WITH:          return evalWith(node, ctx);
        case NodeType::GLOBAL:        return NONE_VALUE;

        // Compound
        case NodeType::SCRIPT:
        case NodeType::STATEMENTS:
        case NodeType::BLOCK:
            return evalBlock(node, ctx);

        default:
            return NONE_VALUE;
        }
    }

private:
    // ─── Literal evaluators ─────────────────────────────────────────────
    Value evalInteger(Node* n) {
        std::string v = n->token().value;
        try {
            if (v.size() > 2 && v[0] == '0') {
                if (v[1]=='x'||v[1]=='X') return Value((int)std::stoll(v, nullptr, 16));
                if (v[1]=='o'||v[1]=='O') return Value((int)std::stoll(v, nullptr, 8));
                if (v[1]=='b'||v[1]=='B') return Value((int)std::stoll(v, nullptr, 2));
            }
            long long ll = std::stoll(v);
            if (ll >= INT_MIN && ll <= INT_MAX) return Value((int)ll);
            return Value((long int)ll);
        } catch (...) {
            return Value(0);
        }
    }

    Value evalFloat(Node* n) {
        try { return Value(std::stod(n->token().value)); }
        catch (...) { return Value(0.0); }
    }

    Value evalString(Node* n, Context* ctx) {
        // Create a string Object via the GC
        const std::string& str = n->token().value;
        Object* obj = runner_->create<Object>(str, Type::STRING);
        obj->setName(str);
        return Value((Collectable*)obj);
    }

    // ─── Variable ───────────────────────────────────────────────────────
    Value evalVariable(Node* n, Context* ctx) {
        auto* var = static_cast<VariableNode*>(n);
        return ctx->getByName(var->name);
    }

    // ─── Binary / Unary ─────────────────────────────────────────────────
    Value evalBinary(Node* n, Context* ctx) {
        auto* bin = static_cast<BinaryNode*>(n);
        // Short-circuit
        if (bin->op == "and" || bin->op == "&&") {
            Value lv = eval(bin->left.get(), ctx);
            return lv.isFalse() ? lv : eval(bin->right.get(), ctx);
        }
        if (bin->op == "or" || bin->op == "||") {
            Value lv = eval(bin->left.get(), ctx);
            return lv.isTrue() ? lv : eval(bin->right.get(), ctx);
        }
        Value lv = eval(bin->left.get(), ctx);
        Value rv = eval(bin->right.get(), ctx);
        const auto& op = bin->op;
        if (op == "+")  return lv + rv;
        if (op == "-")  return lv - rv;
        if (op == "*")  return lv * rv;
        if (op == "/")  return lv / rv;
        if (op == "%")  return lv % rv;
        if (op == "==") return Value(lv == rv);
        if (op == "!=") return Value(!(lv == rv));
        if (op == "~")  return ~lv;
        // Comparisons for numeric values
        if (op == "<" || op == ">" || op == "<=" || op == ">=") {
            return evalComparison(lv, rv, op);
        }
        return NONE_VALUE;
    }

    Value evalComparison(Value lv, Value rv, const std::string& op) {
        // For numeric types, compare directly
        if (lv.type == ValueType::INTEGER && rv.type == ValueType::INTEGER) {
            bigint a = lv.value.i, b = rv.value.i;
            if (op == "<")  return Value(a < b);
            if (op == ">")  return Value(a > b);
            if (op == "<=") return Value(a <= b);
            if (op == ">=") return Value(a >= b);
        }
        if (lv.type == ValueType::DOUBLE || rv.type == ValueType::DOUBLE) {
            double a = (lv.type == ValueType::DOUBLE) ? lv.value.d : (double)lv.value.i;
            double b = (rv.type == ValueType::DOUBLE) ? rv.value.d : (double)rv.value.i;
            if (op == "<")  return Value(a < b);
            if (op == ">")  return Value(a > b);
            if (op == "<=") return Value(a <= b);
            if (op == ">=") return Value(a >= b);
        }
        return Value(false);
    }

    Value evalUnary(Node* n, Context* ctx) {
        auto* un = static_cast<UnaryNode*>(n);
        Value v = eval(un->operand.get(), ctx);
        if (un->op == "-")  return Value(0) - v;
        if (un->op == "!" || un->op == "not") return Value(!v.isTrue());
        if (un->op == "~")  return ~v;
        if (un->op == "+")  return v;
        if (un->op == "++") return v + Value(1);
        if (un->op == "--") return v - Value(1);
        return v;
    }

    // ─── Assignment ─────────────────────────────────────────────────────
    Value evalAssignment(Node* n, Context* ctx) {
        auto* asgn = static_cast<AssignmentNode*>(n);
        Value val = eval(asgn->value_node.get(), ctx);
        if (asgn->target->type() == NodeType::VARIABLE) {
            auto* var = static_cast<VariableNode*>(asgn->target.get());
            ctx->setByName(var->name, val);
        } else if (asgn->target->type() == NodeType::ATTRIBUTE) {
            auto* attr = static_cast<AttributeNode*>(asgn->target.get());
            Value obj = eval(attr->object.get(), ctx);
            if (obj.isObject()) {
                auto* cont = dynamic_cast<nython::kernel::Container*>(obj.value.gc);
                if (cont && cont->container) (*cont->container)[attr->attr] = val;
            }
        } else if (asgn->target->type() == NodeType::SUBSCRIPT) {
            auto* sub = static_cast<SubscriptNode*>(asgn->target.get());
            Value obj = eval(sub->object.get(), ctx);
            Value idx = eval(sub->index.get(), ctx);
            if (obj.isObject()) {
                auto* o = dynamic_cast<Object*>(obj.value.gc);
                if (o) o->set(idx, val);
            }
        }
        return val;
    }

    Value evalAugAssignment(Node* n, Context* ctx) {
        auto* aug = static_cast<AugAssignNode*>(n);
        Value old_val = eval(aug->target.get(), ctx);
        Value new_val = eval(aug->value_node.get(), ctx);
        Value result;
        const auto& op = aug->op;
        if (op == "+=") result = old_val + new_val;
        else if (op == "-=") result = old_val - new_val;
        else if (op == "*=") result = old_val * new_val;
        else if (op == "/=") result = old_val / new_val;
        else if (op == "%=") result = old_val % new_val;
        else result = new_val;
        if (aug->target->type() == NodeType::VARIABLE) {
            ctx->setByName(aug->target->value(), result);
        }
        return result;
    }

    Value evalVarDecl(Node* n, Context* ctx) {
        auto* vd = static_cast<VarDeclNode*>(n);
        Value val = vd->init ? eval(vd->init.get(), ctx) : NONE_VALUE;
        ctx->defineByName(vd->name, val);
        return val;
    }

    // ─── Access ─────────────────────────────────────────────────────────
    Value evalAttribute(Node* n, Context* ctx) {
        auto* attr = static_cast<AttributeNode*>(n);
        Value obj = eval(attr->object.get(), ctx);
        if (obj.isObject()) {
            auto* o = dynamic_cast<Object*>(obj.value.gc);
            if (o) return o->get(attr->attr);
        }
        return NONE_VALUE;
    }

    Value evalSubscript(Node* n, Context* ctx) {
        auto* sub = static_cast<SubscriptNode*>(n);
        Value obj = eval(sub->object.get(), ctx);
        Value idx = eval(sub->index.get(), ctx);
        if (obj.isObject()) {
            auto* o = dynamic_cast<Object*>(obj.value.gc);
            if (o) return o->get(idx);
        }
        return NONE_VALUE;
    }

    // ─── Call ───────────────────────────────────────────────────────────
    Value evalCall(Node* n, Context* ctx) {
        auto* call = static_cast<CallNode*>(n);
        Value callee = eval(call->callee.get(), ctx);

        // Built-in range()
        if (call->callee->type() == NodeType::VARIABLE) {
            auto* var = static_cast<VariableNode*>(call->callee.get());
            if (var->name == "range") return evalBuiltinRange(call, ctx);
            if (var->name == "len")   return evalBuiltinLen(call, ctx);
            if (var->name == "type")  return evalBuiltinType(call, ctx);
            if (var->name == "str")   return evalBuiltinStr(call, ctx);
            if (var->name == "int")   return evalBuiltinInt(call, ctx);
            if (var->name == "float") return evalBuiltinFloat(call, ctx);
            if (var->name == "input") return evalBuiltinInput(call, ctx);
            if (var->name == "abs")   return evalBuiltinAbs(call, ctx);
            if (var->name == "min")   return evalBuiltinMinMax(call, ctx, true);
            if (var->name == "max")   return evalBuiltinMinMax(call, ctx, false);
            if (var->name == "print") { evalPrintArgs(call->args, ctx); return NONE_VALUE; }
        }

        // User-defined function call via registry
        if (call->callee->type() == NodeType::VARIABLE) {
            auto* var = static_cast<VariableNode*>(call->callee.get());
            auto reg_it = funcRegistry_.find(var->name);
            if (reg_it != funcRegistry_.end()) {
                return callRegisteredFunc(var->name, call->args, ctx);
            }
        }
        // Also check if callee is an attribute (method call)
        if (call->callee->type() == NodeType::ATTRIBUTE) {
            auto* attr = static_cast<AttributeNode*>(call->callee.get());
            // Check registry for method
            auto reg_it = funcRegistry_.find(attr->attr);
            if (reg_it != funcRegistry_.end()) {
                return callRegisteredFunc(attr->attr, call->args, ctx);
            }
        }

        // Generic object call
        if (callee.isObject()) {
            auto* obj = dynamic_cast<Object*>(callee.value.gc);
            if (obj && obj->container) {
                // Check if it has __body__ (our function representation)
                auto it = obj->container->find("__body__");
                if (it != obj->container->end()) {
                    return callUserFunction(obj, call->args, ctx);
                }
                // Class instantiation — call __init__ if exists
                return callClassConstructor(obj, call->args, ctx);
            }
        }
        return NONE_VALUE;
    }

    Value callUserFunction(Object* fn, std::vector<node_ptr>& args, Context* ctx) {
        // Get function metadata from the object
        auto* fn_ctx = new Context((Runnable*)runner_, "fn_scope", nullptr, nullptr, global_ctx_);

        // Bind parameters
        auto param_it = fn->container->find("__params__");
        if (param_it != fn->container->end()) {
            auto* param_obj = dynamic_cast<Object*>(param_it->second.value.gc);
            if (param_obj && param_obj->container) {
                int i = 0;
                for (auto& [key, val] : *param_obj->container) {
                    if (i < (int)args.size()) {
                        fn_ctx->defineByName(key, eval(args[i].get(), ctx));
                    }
                    i++;
                }
            }
        }

        // Get and evaluate body
        auto body_it = fn->container->find("__body__");
        if (body_it != fn->container->end()) {
            auto* body_obj = dynamic_cast<Object*>(body_it->second.value.gc);
            if (body_obj) {
                // Body stores a pointer to the AST node
                (void)body_obj; // Reserved for future AST lookup
            }
        }
        return NONE_VALUE;
    }

    Value callClassConstructor(Object* klass, std::vector<node_ptr>& args, Context* ctx) {
        Object* instance = runner_->create<Object>("instance", Type::OBJECT);
        instance->setClass(dynamic_cast<Class*>(klass));
        return Value((Collectable*)instance);
    }

    // ─── Built-in functions ─────────────────────────────────────────────
    Value evalBuiltinRange(CallNode* call, Context* ctx) {
        std::vector<Value> args;
        for (auto& a : call->args) args.push_back(eval(a.get(), ctx));

        int64_t start = 0, stop = 0, step = 1;
        if (args.size() == 1) { stop = (int64_t)args[0].value.i; }
        else if (args.size() >= 2) { start = (int64_t)args[0].value.i; stop = (int64_t)args[1].value.i; }
        if (args.size() >= 3) step = (int64_t)args[2].value.i;
        if (step == 0) step = 1;

        // Create a list object
        Object* list = runner_->create<Object>("list", Type::LIST);
        int idx = 0;
        if (step > 0) {
            for (int64_t i = start; i < stop; i += step)
                list->set(std::to_string(idx++), Value((int)i));
        } else {
            for (int64_t i = start; i > stop; i += step)
                list->set(std::to_string(idx++), Value((int)i));
        }
        list->set("__len__", Value((int)idx));
        return Value((Collectable*)list);
    }

    Value evalBuiltinLen(CallNode* call, Context* ctx) {
        if (call->args.empty()) return Value(0);
        Value v = eval(call->args[0].get(), ctx);
        if (v.isObject()) {
            auto* o = dynamic_cast<Object*>(v.value.gc);
            if (o) {
                auto it = o->container->find("__len__");
                if (it != o->container->end()) return it->second;
                return Value((int)o->container->size());
            }
        }
        return Value(0);
    }

    Value evalBuiltinType(CallNode* call, Context* ctx) {
        if (call->args.empty()) return NONE_VALUE;
        Value v = eval(call->args[0].get(), ctx);
        std::string typeName;
        switch (v.type) {
            case ValueType::NONE: typeName = "none"; break;
            case ValueType::BOOLEAN: typeName = "bool"; break;
            case ValueType::INTEGER: typeName = "int"; break;
            case ValueType::DOUBLE: typeName = "float"; break;
            case ValueType::COLLECTABLE: typeName = "object"; break;
            default: typeName = "unknown";
        }
        Object* s = runner_->create<Object>(typeName, Type::STRING);
        return Value((Collectable*)s);
    }

    Value evalBuiltinStr(CallNode* call, Context* ctx) {
        if (call->args.empty()) return evalString_create("");
        Value v = eval(call->args[0].get(), ctx);
        return evalString_create(v.toString());
    }

    Value evalBuiltinInt(CallNode* call, Context* ctx) {
        if (call->args.empty()) return Value(0);
        Value v = eval(call->args[0].get(), ctx);
        if (v.type == ValueType::INTEGER) return v;
        if (v.type == ValueType::DOUBLE) return Value((int)v.value.d);
        if (v.type == ValueType::BOOLEAN) return Value(v.value.b ? 1 : 0);
        try { return Value((int)std::stoll(v.toString())); } catch (...) { return Value(0); }
    }

    Value evalBuiltinFloat(CallNode* call, Context* ctx) {
        if (call->args.empty()) return Value(0.0);
        Value v = eval(call->args[0].get(), ctx);
        if (v.type == ValueType::DOUBLE) return v;
        if (v.type == ValueType::INTEGER) return Value((double)v.value.i);
        try { return Value(std::stod(v.toString())); } catch (...) { return Value(0.0); }
    }

    Value evalBuiltinInput(CallNode* call, Context* ctx) {
        if (!call->args.empty()) {
            Value prompt = eval(call->args[0].get(), ctx);
            std::cout << prompt.toString();
        }
        std::string line;
        std::getline(std::cin, line);
        return evalString_create(line);
    }

    Value evalBuiltinAbs(CallNode* call, Context* ctx) {
        if (call->args.empty()) return Value(0);
        Value v = eval(call->args[0].get(), ctx);
        if (v.type == ValueType::INTEGER) {
            bigint i = v.value.i;
            return Value((int)(i < 0 ? -i : i));
        }
        if (v.type == ValueType::DOUBLE) return Value(std::abs(v.value.d));
        return v;
    }

    Value evalBuiltinMinMax(CallNode* call, Context* ctx, bool is_min) {
        if (call->args.size() < 2) return NONE_VALUE;
        Value a = eval(call->args[0].get(), ctx);
        Value b = eval(call->args[1].get(), ctx);
        if (a.type == ValueType::INTEGER && b.type == ValueType::INTEGER) {
            return is_min ? (a.value.i < b.value.i ? a : b) : (a.value.i > b.value.i ? a : b);
        }
        return a;
    }

    Value evalString_create(const std::string& str) {
        Object* obj = runner_->create<Object>(str, Type::STRING);
        return Value((Collectable*)obj);
    }

    // ─── Collections ────────────────────────────────────────────────────
    Value evalList(Node* n, Context* ctx) {
        Object* list = runner_->create<Object>("list", Type::LIST);
        int idx = 0;
        for (auto& el : n->statements()) {
            list->set(std::to_string(idx++), eval(el.get(), ctx));
        }
        list->set("__len__", Value((int)idx));
        return Value((Collectable*)list);
    }

    Value evalTuple(Node* n, Context* ctx) {
        return evalList(n, ctx); // Same representation for now
    }

    Value evalMap(Node* n, Context* ctx) {
        Object* map = runner_->create<Object>("map", Type::MAP);
        for (auto& entry : n->statements()) {
            auto* me = static_cast<MapEntryNode*>(entry.get());
            Value key = eval(me->key.get(), ctx);
            Value val = eval(me->val.get(), ctx);
            map->set(key.toString(), val);
        }
        return Value((Collectable*)map);
    }

    // ─── Control flow ───────────────────────────────────────────────────
    Value evalIf(Node* n, Context* ctx) {
        auto* ifn = static_cast<IfNode*>(n);
        if (eval(ifn->condition.get(), ctx).isTrue())
            return eval(ifn->then_branch.get(), ctx);
        for (auto& ei : ifn->elseif_branches) {
            auto* eif = static_cast<IfNode*>(ei.get());
            if (eval(eif->condition.get(), ctx).isTrue())
                return eval(eif->then_branch.get(), ctx);
        }
        if (ifn->else_branch)
            return eval(ifn->else_branch.get(), ctx);
        return NONE_VALUE;
    }

    Value evalWhile(Node* n, Context* ctx) {
        auto* wn = static_cast<WhileNode*>(n);
        Value result = NONE_VALUE;
        while (eval(wn->condition.get(), ctx).isTrue()) {
            try { result = eval(wn->body.get(), ctx); }
            catch (BreakSignal&) { break; }
            catch (ContinueSignal&) { continue; }
        }
        return result;
    }

    Value evalFor(Node* n, Context* ctx) {
        auto* fn = static_cast<ForNode*>(n);
        Value iter_val = eval(fn->iterable.get(), ctx);
        Value result = NONE_VALUE;
        std::string var_name = fn->var->value();

        if (iter_val.isObject()) {
            auto* obj = dynamic_cast<Object*>(iter_val.value.gc);
            if (obj && obj->container) {
                auto len_it = obj->container->find("__len__");
                int len = 0;
                if (len_it != obj->container->end()) len = (int)len_it->second.value.i;
                else len = (int)obj->container->size();

                for (int i = 0; i < len; i++) {
                    auto it = obj->container->find(std::to_string(i));
                    if (it != obj->container->end()) {
                        ctx->defineByName(var_name, it->second);
                        try { result = eval(fn->body.get(), ctx); }
                        catch (BreakSignal&) { break; }
                        catch (ContinueSignal&) { continue; }
                    }
                }
            }
        }
        return result;
    }

    Value evalRepeat(Node* n, Context* ctx) {
        auto* rn = static_cast<RepeatNode*>(n);
        Value count_val = eval(rn->count.get(), ctx);
        int64_t count = (int64_t)count_val.value.i;
        Value result = NONE_VALUE;
        for (int64_t i = 0; i < count; i++) {
            try { result = eval(rn->body.get(), ctx); }
            catch (BreakSignal&) { break; }
            catch (ContinueSignal&) { continue; }
        }
        return result;
    }

    Value evalSwitch(Node* n, Context* ctx) {
        auto* sw = static_cast<SwitchNode*>(n);
        Value subject = eval(sw->subject.get(), ctx);
        for (auto& c : sw->cases) {
            auto* cn = static_cast<CaseNode*>(c.get());
            if (eval(cn->value_node.get(), ctx) == subject)
                return eval(cn->body.get(), ctx);
        }
        if (sw->default_case) return eval(sw->default_case.get(), ctx);
        return NONE_VALUE;
    }

    // ─── Flow signals ───────────────────────────────────────────────────
    Value evalReturn(Node* n, Context* ctx) {
        auto* rn = static_cast<ReturnNode*>(n);
        Value val = rn->expr ? eval(rn->expr.get(), ctx) : NONE_VALUE;
        throw ReturnSignal{val};
    }

    Value evalYield(Node* n, Context* ctx) {
        auto* yn = static_cast<YieldNode*>(n);
        return yn->expr ? eval(yn->expr.get(), ctx) : NONE_VALUE;
    }

    // ─── Definitions ────────────────────────────────────────────────────
    Value evalFuncDecl(Node* n, Context* ctx) {
        auto* fn = static_cast<FunctionNode*>(n);

        // Create a function object
        Object* func = runner_->create<Object>(fn->name, Type::FUNCTION);

        // Store parameter names
        Object* params = runner_->create<Object>("params", Type::LIST);
        for (size_t i = 0; i < fn->params.size(); i++) {
            params->set(fn->params[i]->value(), Value((int)i));
        }
        func->set("__params__", Value((Collectable*)params));
        func->set("__name__", Value((Collectable*)runner_->create<Object>(fn->name, Type::STRING)));
        func->set("__arity__", Value((int)fn->params.size()));
        // Store body AST pointer — we'll retrieve it at call time
        func->set("__body_node__", NONE_VALUE); // placeholder

        // Store the function with a closure reference
        // We use a C++ lambda approach: store the Evaluator + body + params
        // and ctx in a wrapper
        Value func_val((Collectable*)func);

        // Register a native call handler using our FuncWrapper
        funcRegistry_[fn->name] = FuncEntry{fn, ctx};

        ctx->defineByName(fn->name, func_val);
        return func_val;
    }

    Value evalLambda(Node* n, Context* ctx) {
        auto* ln = static_cast<LambdaNode*>(n);
        std::string name = "<lambda_" + std::to_string(lambdaCounter_++) + ">";
        Object* func = runner_->create<Object>(name, Type::FUNCTION);
        funcRegistry_[name] = FuncEntry{nullptr, ctx, ln};
        return Value((Collectable*)func);
    }

    Value evalClassDecl(Node* n, Context* ctx) {
        auto* cn = static_cast<ClassNode*>(n);
        Class* klass = runner_->create<Class>(cn->name);

        // Evaluate class body in a new context
        Context* class_ctx = new Context((Runnable*)runner_, cn->name + "_scope", (Collectable*)klass, nullptr, ctx);
        class_ctx->inClass = true;
        if (cn->body) eval(cn->body.get(), class_ctx);

        // Copy class body definitions into the class object
        if (class_ctx->container) {
            for (auto& [key, val] : *class_ctx->container) {
                klass->set(key, val);
            }
        }
        ctx->defineByName(cn->name, Value((Collectable*)klass));
        return Value((Collectable*)klass);
    }

    Value evalEnum(Node* n, Context* ctx) {
        auto* en = static_cast<EnumNode*>(n);
        Object* enum_obj = runner_->create<Object>(en->name, Type::OBJECT);
        int64_t counter = 0;
        for (auto& item : en->items) {
            auto* ei = static_cast<EnumItemNode*>(item.get());
            Value val = ei->value_node ? eval(ei->value_node.get(), ctx) : Value((int)counter++);
            enum_obj->set(ei->name, val);
        }
        ctx->defineByName(en->name, Value((Collectable*)enum_obj));
        return Value((Collectable*)enum_obj);
    }

    Value evalInterface(Node* n, Context* ctx) {
        auto* in_node = static_cast<InterfaceNode*>(n);
        Object* iface = runner_->create<Object>(in_node->name, Type::OBJECT);
        ctx->defineByName(in_node->name, Value((Collectable*)iface));
        return Value((Collectable*)iface);
    }

    Value evalNamespace(Node* n, Context* ctx) {
        auto* ns = static_cast<NameSpaceNode*>(n);
        Context* ns_ctx = new Context((Runnable*)runner_, ns->name, nullptr, nullptr, ctx);
        ns_ctx->inNameSpace = true;
        if (ns->body) eval(ns->body.get(), ns_ctx);
        return NONE_VALUE;
    }

    // ─── Exception handling ─────────────────────────────────────────────
    Value evalTry(Node* n, Context* ctx) {
        auto* tn = static_cast<TryNode*>(n);
        Value result = NONE_VALUE;
        try {
            result = eval(tn->body.get(), ctx);
        } catch (std::runtime_error& e) {
            for (auto& ec : tn->except_clauses) {
                auto* en = static_cast<ExceptNode*>(ec.get());
                if (!en->alias.empty()) {
                    Object* err = runner_->create<Object>(e.what(), Type::STRING);
                    ctx->defineByName(en->alias, Value((Collectable*)err));
                }
                result = eval(en->body.get(), ctx);
                break; // Only first matching except
            }
        } catch (...) {
            if (!tn->except_clauses.empty()) {
                result = eval(tn->except_clauses[0].get(), ctx);
            }
        }
        if (tn->finally_clause) eval(tn->finally_clause.get(), ctx);
        return result;
    }

    Value evalRaise(Node* n, Context* ctx) {
        auto* rn = static_cast<RaiseNode*>(n);
        if (rn->expr) {
            Value v = eval(rn->expr.get(), ctx);
            throw std::runtime_error(v.toString());
        }
        throw std::runtime_error("Exception");
    }

    Value evalAssert(Node* n, Context* ctx) {
        auto* an = static_cast<AssertNode*>(n);
        if (!eval(an->condition.get(), ctx).isTrue()) {
            std::string msg = an->message ? eval(an->message.get(), ctx).toString() : "Assertion failed";
            throw std::runtime_error(msg);
        }
        return NONE_VALUE;
    }

    // ─── Statements ─────────────────────────────────────────────────────
    Value evalPrint(Node* n, Context* ctx) {
        auto* pn = static_cast<PrintNode*>(n);
        evalPrintArgs(pn->args, ctx);
        return NONE_VALUE;
    }

    void evalPrintArgs(std::vector<node_ptr>& args, Context* ctx) {
        for (size_t i = 0; i < args.size(); i++) {
            if (i > 0) std::cout << " ";
            Value v = eval(args[i].get(), ctx);
            std::cout << v.toString();
        }
        std::cout << std::endl;
    }

    Value evalDelete(Node* n, Context* ctx) {
        auto* dn = static_cast<DeleteNode*>(n);
        if (dn->target->type() == NodeType::VARIABLE) {
            ctx->setByName(dn->target->value(), UNDEFINED_VALUE);
        }
        return NONE_VALUE;
    }

    Value evalImport(Node* n, Context* ctx) {
        // Placeholder — would load modules from filesystem
        return NONE_VALUE;
    }

    Value evalWith(Node* n, Context* ctx) {
        auto* wn = static_cast<WithNode*>(n);
        Value val = eval(wn->expr.get(), ctx);
        if (!wn->alias.empty()) ctx->defineByName(wn->alias, val);
        return eval(wn->body.get(), ctx);
    }

    // ─── Block ──────────────────────────────────────────────────────────
    Value evalBlock(Node* n, Context* ctx) {
        Value result = NONE_VALUE;
        for (auto& stmt : n->statements()) {
            result = eval(stmt.get(), ctx);
        }
        return result;
    }

    // ─── Function call registry (for user-defined functions) ────────────
    struct FuncEntry {
        FunctionNode* fn_node = nullptr;
        Context* closure_ctx = nullptr;
        LambdaNode* lambda_node = nullptr;
    };
    std::unordered_map<std::string, FuncEntry> funcRegistry_;
    int lambdaCounter_ = 0;

public:
    // Called from evalCall for user-defined functions
    Value callRegisteredFunc(const std::string& name, std::vector<node_ptr>& args, Context* call_ctx) {
        auto it = funcRegistry_.find(name);
        if (it == funcRegistry_.end()) return NONE_VALUE;
        auto& entry = it->second;

        Node* body = nullptr;
        std::vector<node_ptr>* params = nullptr;

        if (entry.fn_node) {
            body = entry.fn_node->body.get();
            params = &entry.fn_node->params;
        } else if (entry.lambda_node) {
            body = entry.lambda_node->body.get();
            params = &entry.lambda_node->params;
        }
        if (!body) return NONE_VALUE;

        // Create function scope
        Context* fn_ctx = new Context((Runnable*)runner_, name + "_scope", nullptr, nullptr, entry.closure_ctx ? entry.closure_ctx : global_ctx_);
        fn_ctx->inFunction = true;

        // Bind arguments to parameters
        if (params) {
            for (size_t i = 0; i < params->size() && i < args.size(); i++) {
                fn_ctx->defineByName((*params)[i]->value(), eval(args[i].get(), call_ctx));
            }
        }

        try {
            return eval(body, fn_ctx);
        } catch (ReturnSignal& rs) {
            return rs.value;
        }
    }
};

} // namespace nython::eval
#endif
