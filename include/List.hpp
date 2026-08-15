#ifndef __LIST__HPP
#define __LIST__HPP

#include <sstream>
#include "Value.hpp"
#include "Collectable.hpp"

namespace nython {

namespace interpreter {
struct Interpreter;
}

using nython::interpreter::Interpreter;

namespace kernel {

struct List extends Collectable {

};
}
}
#endif /// __LIST__
