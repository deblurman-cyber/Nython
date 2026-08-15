#ifndef __SCRIPT__HPP
#define __SCRIPT__HPP

#include "Node.hpp"

namespace nython::node {

struct Script extends Node {

    std::vector<node_ptr> decls;
    std::unique_ptr<Node> package;

    Script(): Script(Token()) {
    }

    Script(Token t):Node(t,NodeType::SCRIPT),decls{},package{} {
        root    = this;
        ////package = std::unique_ptr<Node>(new PackageNode(t));
    }

    virtual ~Script(){
        decls.clear();
    }

    Node* add(node_ptr node){
		if(node!=nullptr){
			decls.push_back(node);
		}
		return this;
	}

	void  set(int index,node_ptr node){
		if(index<int(decls.size())){
			decls[index] = node;
		} else exception::IndexOutOfRangeError(location(), utils::format("The index you have provided is out of range: maximun value should be ", size()-1));
	}

    std::vector<node_ptr> statements(){
		return decls;
    }

    Value _eval(Context* context,Value pkg){
    	Value obj = NONE_VALUE;
    	auto nodes = statements();
		if(pkg!=NONE_VALUE && pkg!=UNDEFINED_VALUE && pkg.isObject()){
			for(node_ptr node:nodes){
				obj = node->eval(context);
				pkg->add(obj,obj);
			}
		}else{
			for(node_ptr node:nodes){
				obj = node->eval(context);
			}
		}
		return obj;
    }

    /**
     * @inheritDoc
    */
    Value eval(Context* context){
		Value obj = NONE_VALUE;
		if(package!=nullptr){
			obj           = package->eval(context);
			obj->location = token().location();
		}
		obj = _eval(context,obj);
		return obj;
	}

	 /**
     * @inheritDoc
    */
    void writeToStdOut(PrettyPrinter p){
    	p.println("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
		p.printf("<Script line=\"%d\" column=\"%d\">\n", line(), column());
		p.indentRight();
		p.printf("<Source name=\"%s\"/>\n", file().c_str());
		if(package != nullptr){
			package->writeToStdOut(p);
		}else p.printf("<Package name=\"%s\"/>\n","nython");
		p.println("<Statements>");
		p.indentRight();
		for(node_ptr node : statements()){
			node->writeToStdOut(p);
		}
		p.indentLeft();
		p.println("</Statements>");
		p.indentLeft();
		p.println("</Script>");
    }

    /**
     * @inheritDoc
    */
    std::string toString(PrettyPrinter p){
    	std::string str;
    	p.println("<?xml version=\"1.0\" encoding=\"utf-8\"?>",&str);
		p.printf(&str,"<Script line=\"%d\" column=\"%d\">\n", line(), column());
		p.indentRight();
		p.printf(&str,"<Source name=\"%s\"/>\n", file().c_str());
		if(package != nullptr){
			str.append(package->toString(p));
		}else p.printf(&str,"<Package name=\"%s\"/>\n","nython");
		p.println("<Statements>",&str);
		p.indentRight();
		for(node_ptr node : statements()){
			str.append(node->toString(p));
		}
		p.indentLeft();
		p.println("</Statements>",&str);
		p.indentLeft();
		p.println("</Script>",&str);
    	return str;
    }

    /**
     * @inheritDoc
    */
    void accept(IVisitor* visitor){
    	if(package!=nullptr){
			package->accept(visitor);
		}
		auto nodes = statements();
		for(node_ptr node:nodes){
			node->accept(visitor);
		}
    }

};

}

#endif //__SCRIPT__HPP
