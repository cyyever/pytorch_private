#include <torch/csrc/autograd/generated/python_functions.h>

// ${generated_comment}

#include <Python.h>
#include <ATen/ATen.h>

#include "torch/csrc/autograd/generated/Functions.h"
#include "torch/csrc/autograd/python_cpp_function.h"
#include <torch/csrc/autograd/python_variable.h>
#include <torch/csrc/autograd/saved_variable.h>
#include <pybind11/pybind11.h>

// NOTE: See [Sharded File] comment in VariableType

namespace torch { namespace autograd { namespace generated {

template<typename C>
static void addClass(PyTypeObject& type, const char* name,
  PyGetSetDef* function_properties=NULL, PyMethodDef* function_methods=NULL)
{
  _initFunctionPyTypeObject(type, name, function_properties, function_methods);
  Py_INCREF(&type);
  registerCppFunction(typeid(C), &type);
}

${py_function_props_and_getters}

void initialize_autogenerated_functions${shard_id}() {
  ${py_function_initializers}
}

}}} // namespace torch::autograd::generated
