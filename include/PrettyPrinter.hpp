
#ifndef __PRETTY_PRINTER__HPP
#define __PRETTY_PRINTER__HPP

#include <string>
#include <vector>
#include <iostream>

namespace nython::utils {

class PrettyPrinter {

private:

    /** Width of an indentation. */
    int indentWidth;

    /** Current indentation (number of blank spaces). */
    int indent;

    int pos = -1;

    /**
     * Indent by printing spaces to STDOUT.
     */

    void doIndent(){
        for(int i = 0; i < indent; i++){
            std::cout<<" ";
        }
    }

    void doIndent(std::string* str){
        for(int i = 0; i < indent; i++){
            str->append(" ");
        }
    }

    long long length(){
        return 0;
    }

    template<typename T>
    long long length(T t){
        return std::to_string(t).size();
    }

    long long length(const char* t){
        return std::string(t).size();
    }

    template<typename T, typename... Args>
    long long length(T t,Args... args){
        return length(t)+length(args...);
    }

public:

    /**
     * Construct a PrettyPrinter with an indentation width of 2.
     */

    PrettyPrinter():PrettyPrinter(3){
    }

    /**
     * Construct a PrettyPrinter given the indentation width.
     *
     * @param indentWidth number of blank spaces for an indent.
     *
     */

    PrettyPrinter(int width):indentWidth{width},indent{0},pos{-1} {
    }

    /**
     * Indent right.
     */

    void indentRight(){
        indent += indentWidth;
    }

    /**
     * Indent left.
     */

    void indentLeft(){
        if(indent > 0){
            indent -= indentWidth;
        }
    }

    /**
     * Print an empty line to STDOUT.
     */

    void println(){
        doIndent();
        std::cout<<std::endl;
    }

    /**
     * Print the specified std::string (followed by a newline) to STDOUT.
     *
     * @param s std::string to print.
     *
     */

    void println(const std::string& s){
        doIndent();
        std::cout<<s<<std::endl;
    }

    /**
     * Print the specified std::string to STDOUT.
     *
     * @param s
     *            std::string to print.
     */

    void print(const std::string& s){
        doIndent();
        std::cout<<s;
    }

    /**
     * Print args to STDOUT according to the specified format.
     *
     * @param format format specifier.
     * @param args values to print.
     */

    template<typename...Args>
    void printf(const char* format,Args...args){
        int len = length(format,args...);
        std::vector<char> buf(len); char* str = buf.data();
        doIndent();
        len = sprintf(str,format,args...);
        std::cout<<str;
    }

    template<typename...Args>
    void printf(std::string* s,const char* format,Args...args){
        int len = length(format,args...);
        std::vector<char> buf(len + 1);
        doIndent(s);
        snprintf(buf.data(), buf.size(), format, args...);
        s->append(buf.data());
    }

    void printf(std::string* s, const char* msg){
        doIndent(s);
        s->append(msg);
    }

    void printf(const char* msg){
        doIndent();
        std::cout<<msg;
    }

    void println(std::string* str){
        doIndent(str);
        str->append("\n");
    }

    void println(const std::string& s,std::string* str){
        doIndent(str);
        str->append(s).append("\n");
    }

    void print(const std::string& s,std::string* str){
        doIndent(str);
        str->append(s);
    }

    template<typename...Args>
    void print(std::string* chr,const char* format,Args...args){
        int len = length(format,args...);
        std::vector<char> buf(len); char* str = buf.data();
        doIndent(chr);
        len = sprintf(str,format,args...);
        chr->append(str);
    }

    void position(int _pos){
        pos = _pos;
    }

    int position(){
        return pos;
    }

};

}

#endif // __PRETTY_PRINTER__HPP
