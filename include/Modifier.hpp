
#ifndef __MODIFIER__HPP
#define __MODIFIER__HPP


namespace nython{
namespace kernel{

static class Modifier{

public:

    static const int REF                   = 0x00000010;
    static const int FINAL                 = 0x00000020;
    static const int IMMUTABLE             = 0x00000040;
    static const int MUTABLE               = 0x00000080;
    static const int PUBLIC                = 0x00000001;
    static const int PRIVATE               = 0x00000002;
    static const int PROTECTED             = 0x00000004;
    static const int STATIC                = 0x00000008;
    static const int SYNCHRONIZED          = 0x00000100;
    static const int CLASS                 = 0x00000200;
    static const int INTERFACE             = 0x00000400;
    static const int ABSTRACT              = 0x00000800;
    static const int VARARGS               = 0x00001000;
    static const int ANNOTATION            = 0x00002000;
    static const int ENUM                  = 0x00004000;
    static const int FUNCTION              = 0x00008000;
    static const int ARRAY                 = 0x00010000;
    static const int LIST                  = 0x00020000;
    static const int TUPLE                 = 0x00040000;
    static const int MAP                   = 0x00080000;
    static const int PRIMITIVE             = 0x00100000;
    static const int LAMBDA                = 0x00200000;

private:

    static const int PARAMETER_MODIFIERS   = REF|FINAL;
    static const int ACCESS_MODIFIERS      = PUBLIC|PROTECTED|PRIVATE;
    static const int CONSTRUCTOR_MODIFIERS = PUBLIC|PROTECTED|PRIVATE;
    static const int FUNCTION_MODIFIERS    = PUBLIC|PROTECTED|PRIVATE|STATIC;
    static const int INTERFACE_MODIFIERS   = PUBLIC|PROTECTED|PRIVATE|ABSTRACT|STATIC;
    static const int CLASS_MODIFIERS       = PUBLIC|PROTECTED|PRIVATE|ABSTRACT|STATIC|FINAL;
    static const int METHOD_MODIFIERS      = PUBLIC|PROTECTED|PRIVATE|ABSTRACT|STATIC|FINAL|SYNCHRONIZED;
    static const int FIELD_MODIFIERS       = PUBLIC|PROTECTED|PRIVATE|STATIC|FINAL|IMMUTABLE|MUTABLE;

public:

    Modifier(){
    }

    static bool isPublic(int mod){
        return (mod & PUBLIC) != 0;
    }

    static bool isPrivate(int mod) {
        return (mod & PRIVATE) != 0;
    }

    static bool isProtected(int mod) {
        return (mod & PROTECTED) != 0;
    }

    static bool isAbstract(int mod) {
        return (mod & ABSTRACT) != 0;
    }

    static bool isStatic(int mod) {
        return (mod & STATIC) != 0;
    }

    static bool isFinal(int mod) {
        return (mod & FINAL) != 0;
    }

    static bool isSynchronized(int mod) {
        return (mod & SYNCHRONIZED) != 0;
    }

    static bool isRef(int mod) {
        return (mod & REF) != 0;
    }

    static bool isImmutable(int mod) {
        return (mod & IMMUTABLE) != 0;
    }

    static bool isMutable(int mod) {
        return (mod & MUTABLE) != 0;
    }

    static bool isInterface(int mod) {
        return (mod & INTERFACE) != 0;
    }

    static bool isClass(int mod) {
        return (mod & CLASS) != 0;
    }

    static bool isFunction(int mod) {
        return (mod & FUNCTION) != 0;
    }

    static bool isLambda(int mod) {
        return (mod & LAMBDA) != 0;
    }

    static bool isArray(int mod) {
      return (mod & ARRAY) != 0;
    }

    static bool isList(int mod) {
      return (mod & LIST) != 0;
    }

    static bool isTuple(int mod) {
      return (mod & TUPLE) != 0;
    }

    static bool isMap(int mod) {
      return (mod & MAP) != 0;
    }

    static bool isVarArgs(int mod){
        return (mod & VARARGS) != 0;
    }

    static bool isAnnotation(int mod) {
      return (mod & ANNOTATION) != 0;
    }

    static bool isPrimitive(int mod) {
      return (mod & PRIMITIVE) != 0;
    }

    static bool isEnum(int mod){
      return (mod & ENUM) != 0;
    }

    static int classModifiers() {
        return CLASS_MODIFIERS;
    }

    static int accessModifiers(){
        return ACCESS_MODIFIERS;
    }

    static int interfaceModifiers() {
        return INTERFACE_MODIFIERS;
    }

    static int constructorModifiers() {
        return CONSTRUCTOR_MODIFIERS;
    }

    static int methodModifiers() {
        return METHOD_MODIFIERS;
    }

    static int functionModifiers() {
        return FUNCTION_MODIFIERS;
    }

    static int fieldModifiers() {
        return FIELD_MODIFIERS;
    }

    static int parameterModifiers() {
        return PARAMETER_MODIFIERS;
    }

    static std::string toString(int mod){
        std::string sb;
        size_t len = 0;
        if((mod & PUBLIC) != 0)        sb.append("public ");
        if((mod & PROTECTED) != 0)     sb.append("protected ");
        if((mod & PRIVATE) != 0)       sb.append("private ");
        /* Canonical order */
        if((mod & ABSTRACT) != 0)      sb.append("abstract ");
        if((mod & STATIC) != 0)        sb.append("static ");
        if((mod & FINAL) != 0)         sb.append("final ");
        if((mod & REF) != 0)           sb.append("ref ");
        if((mod & ENUM) != 0)          sb.append("enum ");
        if((mod & CLASS) != 0)         sb.append("class ");
        if((mod & MUTABLE) != 0)       sb.append("mutable ");
        if((mod & FUNCTION) != 0)      sb.append("function ");
        if((mod & INTERFACE) != 0)     sb.append("interface ");
        if((mod & IMMUTABLE) != 0)     sb.append("immutable ");
        if((mod & SYNCHRONIZED) != 0)  sb.append("synchronized ");
        if((mod & PRIMITIVE) != 0)     sb.append("primitive ");
        if((mod & LAMBDA) != 0)        sb.append("lambda ");
        if((len = sb.length()) > 0)    return sb.substr(0,len-1);
        return "";
    }
}Modifier;

}

}

#endif // __MODIFIER__HPP

