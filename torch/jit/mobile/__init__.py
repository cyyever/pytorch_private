import torch

from torch.jit._serialization import validate_map_location

import pathlib
import os

def _load_for_lite_interpreter(f, map_location=None):
    r"""
    Load a :class:`LiteScriptModule`
    saved with :func:`torch.jit._save_for_lite_interpreter`

    Args:
        f: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name
        map_location: a string or torch.device used to dynamically remap
            storages to an alternative set of devices.

    Returns:
        A :class:`LiteScriptModule` object.

    Example:

    .. testcode::

        import torch
        import io

        # Load LiteScriptModule from saved file path
        torch.jit._load_for_lite_interpreter('lite_script_module.pt')

        # Load LiteScriptModule from io.BytesIO object
        with open('lite_script_module.pt', 'rb') as f:
            buffer = io.BytesIO(f.read())

        # Load all tensors to the original device
        torch.jit.mobile._load_for_lite_interpreter(buffer)
    """
    if isinstance(f, str):
        if not os.path.exists(f):
            raise ValueError("The provided filename {} does not exist".format(f))
        if os.path.isdir(f):
            raise ValueError("The provided filename {} is a directory".format(f))
    zip_magic = b'PK\x03\x04'
    map_location = validate_map_location(map_location)
    if isinstance(f, str) or isinstance(f, pathlib.Path):
        is_flatbuffer = False
        with open(f, 'rb') as fi:
            magic_bytes = fi.read(4)
            is_flatbuffer = (magic_bytes != zip_magic)
        cpp_module = torch._C._load_for_lite_interpreter(f, map_location, is_flatbuffer)
    else:
        all_bytes = f.read()
        is_flatbuffer = (all_bytes[:4] != zip_magic)
        cpp_module = torch._C._load_for_lite_interpreter_from_buffer(
            all_bytes, map_location, is_flatbuffer)

    return LiteScriptModule(cpp_module)

class LiteScriptModule(object):
    def __init__(self, cpp_module):
        self._c = cpp_module
        super(LiteScriptModule, self).__init__()

    def __call__(self, *input):
        return self._c.forward(input)

    def find_method(self, method_name):
        return self._c.find_method(method_name)

    def forward(self, *input):
        return self._c.forward(input)

    def run_method(self, method_name, *input):
        return self._c.run_method(method_name, input)

def _export_operator_list(module: LiteScriptModule):
    r"""
        return a set of root operator names (with overload name) that are used by any method
        in this mobile module.
    """
    return torch._C._export_operator_list(module._c)

def _get_model_bytecode_version(f_input) -> int:
    r"""
    Args:
        f_input: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name

    Returns:
        version: An integer. If the integer is -1, the version is invalid. A warning
            will show in the log.

    Example:

    .. testcode::

        from torch.jit.mobile import _get_model_bytecode_version

        # Get bytecode version from a saved file path
        version = _get_model_bytecode_version("path/to/model.ptl")

    """
    if isinstance(f_input, str):
        if not os.path.exists(f_input):
            raise ValueError(f"The provided filename {f_input} does not exist")
        if os.path.isdir(f_input):
            raise ValueError(f"The provided filename {f_input} is a directory")

    if (isinstance(f_input, str) or isinstance(f_input, pathlib.Path)):
        return torch._C._get_model_bytecode_version(str(f_input))
    else:
        return torch._C._get_model_bytecode_version_from_buffer(f_input.read())

def _get_mobile_model_contained_types(f_input) -> int:
    r"""
    Args:
        f_input: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name

    Returns:
        type_list: A set of string, like ("int", "Optional"). These are types used in bytecode.

    Example:

    .. testcode::

        from torch.jit.mobile import _get_mobile_model_contained_types

        # Get type list from a saved file path
        type_list = _get_mobile_model_contained_types("path/to/model.ptl")

    """
    if isinstance(f_input, str):
        if not os.path.exists(f_input):
            raise ValueError(f"The provided filename {f_input} does not exist")
        if os.path.isdir(f_input):
            raise ValueError(f"The provided filename {f_input} is a directory")

    if (isinstance(f_input, str) or isinstance(f_input, pathlib.Path)):
        return torch._C._get_mobile_model_contained_types(str(f_input))
    else:
        return torch._C._get_mobile_model_contained_types_from_buffer(f_input.read())

def _backport_for_mobile(f_input, f_output, to_version):
    r"""
    Args:
        f_input: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name
        f_output: path to new model destination
        to_version: the expected output model bytecode version
    Returns:
        success: A boolean. If backport success, return true, otherwise false
    """
    if isinstance(f_input, str):
        if not os.path.exists(f_input):
            raise ValueError(f"The provided filename {f_input} does not exist")
        if os.path.isdir(f_input):
            raise ValueError(f"The provided filename {f_input} is a directory")

    if ((isinstance(f_input, str) or isinstance(f_input, pathlib.Path)) and (
            isinstance(f_output, str) or isinstance(f_output, pathlib.Path))):
        return torch._C._backport_for_mobile(str(f_input), str(f_output), to_version)
    else:
        return torch._C._backport_for_mobile_from_buffer(f_input.read(), str(f_output), to_version)

def _backport_for_mobile_to_buffer(f_input, to_version):
    r"""
    Args:
        f_input: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name

    """
    if isinstance(f_input, str):
        if not os.path.exists(f_input):
            raise ValueError(f"The provided filename {f_input} does not exist")
        if os.path.isdir(f_input):
            raise ValueError(f"The provided filename {f_input} is a directory")

    if (isinstance(f_input, str) or isinstance(f_input, pathlib.Path)):
        return torch._C._backport_for_mobile_to_buffer(str(f_input), to_version)
    else:
        return torch._C._backport_for_mobile_from_buffer_to_buffer(f_input.read(), to_version)

def _get_model_ops_and_info(f_input):
    r"""
    A function to retrieve the root (top level) operators of a model and their corresponding
    compatibility info. These root operators can call other operators within them (traced ops), and
    a root op can call many different traced ops depending on internal code paths in the root op.
    These traced ops are not returned by this function. Those operators are abstracted into the
    runtime as an implementation detail (and the traced ops themselves can also call other operators)
    making retrieving them difficult and their value from this api negligible since they will differ
    between which runtime version the model is run on. Because of this, there is a false positive this
    api can't prevent in a compatibility usecase. All the root ops of a model are present in a
    target runtime, but not all the traced ops are which prevents a model from being able to run.
    Args:
        f_input: a file-like object (has to implement read, readline, tell, and seek),
            or a string containing a file name

    Returns:
        Operators and info: A Dictionary mapping strings (the qualified names of the root operators)
        of the model to their OperatorInfo structs.

    Example:

    .. testcode::

        from torch.jit.mobile import _get_model_ops_and_info

        # Get bytecode version from a saved file path
        ops_and_info = _get_model_ops_and_info("path/to/model.ptl")

    """
    if isinstance(f_input, str):
        if not os.path.exists(f_input):
            raise ValueError(f"The provided filename {f_input} does not exist")
        if os.path.isdir(f_input):
            raise ValueError(f"The provided filename {f_input} is a directory")

    if (isinstance(f_input, str) or isinstance(f_input, pathlib.Path)):
        return torch._C._get_model_ops_and_info(str(f_input))
    else:
        return torch._C._get_model_ops_and_info(f_input.read())


def save_mobile_module(m: LiteScriptModule, filename: str):
    torch._C._save_mobile_module(m._c, filename)

def jit_module_to_mobile(m):
    mobile_m = torch._C._jit_module_to_mobile(m._c)
    return LiteScriptModule(mobile_m)


def module_equals(lhs: LiteScriptModule, rhs: LiteScriptModule):
    torch._C._module_equals(lhs._c, rhs._c)
