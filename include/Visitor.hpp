#ifndef __VISITOR__HPP
#define __VISITOR__HPP

#include "Value.hpp"
#include "Object.hpp"


namespace nython{
namespace node{
struct INode;
}
}

using nython::node::INode;
using nython::kernel::Value;
using nython::kernel::Object;

namespace nython{

namespace node {
struct Node;

using node_ptr = std::shared_ptr<Node>;
}

namespace visitor{

using node::node_ptr;

struct IVisitor{
    virtual ~IVisitor() = default;
	virtual Value visit(node::Node* node) = 0;
};

template <class T, typename R = void>
struct Visitor: public IVisitor{

	virtual R visit(T* ast) {
		R r;
		return r;
	}

	virtual Value visit(node::Node* node) {
		return NONE_VALUE;
	}
};

}
}

#endif // __VISITOR__HPP
