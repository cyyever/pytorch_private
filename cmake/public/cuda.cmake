# ---[ cuda
include_guard(GLOBAL)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

# Find CUDA.
find_package(CUDAToolkit)
if(NOT CUDAToolkit_FOUND)
  message(
    WARNING
      "Caffe2: CUDA cannot be found. Depending on whether you are building "
      "Caffe2 or a Caffe2 dependent library, the next warning / error will "
      "give you more info.")
  set(CAFFE2_USE_CUDA OFF)
  return()
endif()

# Enable CUDA language support
enable_language(CUDA)
set(CUDA_VERSION ${CUDAToolkit_VERSION_MAJOR}.${CUDAToolkit_VERSION_MINOR})
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

message(STATUS "Caffe2: CUDA detected: " ${CUDA_VERSION})
message(STATUS "Caffe2: CUDA nvcc is: " ${CUDA_NVCC_EXECUTABLE})
message(STATUS "Caffe2: CUDA toolkit directory: " ${CUDAToolkit_TARGET_DIR})

# Find cuDNN.
if(USE_STATIC_CUDNN)
  set(CUDNN_STATIC
      ON
      CACHE BOOL "")
else()
  set(CUDNN_STATIC
      OFF
      CACHE BOOL "")
endif()

find_package(CUDNN)

if(CAFFE2_USE_CUDNN AND NOT CUDNN_FOUND)
  message(WARNING "Caffe2: Cannot find cuDNN library. Turning the option off")
  set(CAFFE2_USE_CUDNN OFF)
endif()

# Optionally, find TensorRT
if(CAFFE2_USE_TENSORRT)
  find_path(
    TENSORRT_INCLUDE_DIR NvInfer.h
    HINTS ${TENSORRT_ROOT} ${CUDAToolkit_TARGET_DIR}
    PATH_SUFFIXES include)
  find_library(
    TENSORRT_LIBRARY nvinfer
    HINTS ${TENSORRT_ROOT} ${CUDAToolkit_TARGET_DIR}
    PATH_SUFFIXES lib lib64 lib/x64)
  find_package_handle_standard_args(TENSORRT DEFAULT_MSG TENSORRT_INCLUDE_DIR
                                    TENSORRT_LIBRARY)
  if(TENSORRT_FOUND)
    execute_process(
      COMMAND
        /bin/sh -c
        "[ -r \"${TENSORRT_INCLUDE_DIR}/NvInferVersion.h\" ] && awk '/^\#define NV_TENSORRT_MAJOR/ {print $3}' \"${TENSORRT_INCLUDE_DIR}/NvInferVersion.h\""
      OUTPUT_VARIABLE TENSORRT_VERSION_MAJOR)
    execute_process(
      COMMAND
        /bin/sh -c
        "[ -r \"${TENSORRT_INCLUDE_DIR}/NvInferVersion.h\" ] && awk '/^\#define NV_TENSORRT_MINOR/ {print $3}' \"${TENSORRT_INCLUDE_DIR}/NvInferVersion.h\""
      OUTPUT_VARIABLE TENSORRT_VERSION_MINOR)
    if(TENSORRT_VERSION_MAJOR)
      string(STRIP ${TENSORRT_VERSION_MAJOR} TENSORRT_VERSION_MAJOR)
      string(STRIP ${TENSORRT_VERSION_MINOR} TENSORRT_VERSION_MINOR)
      set(TENSORRT_VERSION
          "${TENSORRT_VERSION_MAJOR}.${TENSORRT_VERSION_MINOR}")
      # CAFFE2_USE_TRT is set in Dependencies
      set(CMAKE_CXX_FLAGS
          "${CMAKE_CXX_FLAGS} -DTENSORRT_VERSION_MAJOR=${TENSORRT_VERSION_MAJOR}"
      )
      set(CMAKE_CXX_FLAGS
          "${CMAKE_CXX_FLAGS} -DTENSORRT_VERSION_MINOR=${TENSORRT_VERSION_MINOR}"
      )
    else()
      message(
        WARNING
          "Caffe2: Cannot find ${TENSORRT_INCLUDE_DIR}/NvInferVersion.h. Assuming TRT 5.0 which is no longer supported. Turning the option off."
      )
      set(CAFFE2_USE_TENSORRT OFF)
    endif()
  else()
    message(
      WARNING "Caffe2: Cannot find TensorRT library. Turning the option off.")
    set(CAFFE2_USE_TENSORRT OFF)
  endif()
endif()

# ---[ Extract versions
if(CAFFE2_USE_CUDNN)
  # Get cuDNN version
  if(EXISTS ${CUDNN_INCLUDE_PATH}/cudnn_version.h)
    file(READ ${CUDNN_INCLUDE_PATH}/cudnn_version.h CUDNN_HEADER_CONTENTS)
  else()
    file(READ ${CUDNN_INCLUDE_PATH}/cudnn.h CUDNN_HEADER_CONTENTS)
  endif()
  string(REGEX MATCH "define CUDNN_MAJOR * +([0-9]+)" CUDNN_VERSION_MAJOR
               "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_MAJOR * +([0-9]+)" "\\1"
                       CUDNN_VERSION_MAJOR "${CUDNN_VERSION_MAJOR}")
  string(REGEX MATCH "define CUDNN_MINOR * +([0-9]+)" CUDNN_VERSION_MINOR
               "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_MINOR * +([0-9]+)" "\\1"
                       CUDNN_VERSION_MINOR "${CUDNN_VERSION_MINOR}")
  string(REGEX MATCH "define CUDNN_PATCHLEVEL * +([0-9]+)" CUDNN_VERSION_PATCH
               "${CUDNN_HEADER_CONTENTS}")
  string(REGEX REPLACE "define CUDNN_PATCHLEVEL * +([0-9]+)" "\\1"
                       CUDNN_VERSION_PATCH "${CUDNN_VERSION_PATCH}")
  # Assemble cuDNN version
  if(NOT CUDNN_VERSION_MAJOR)
    set(CUDNN_VERSION "?")
  else()
    set(CUDNN_VERSION
        "${CUDNN_VERSION_MAJOR}.${CUDNN_VERSION_MINOR}.${CUDNN_VERSION_PATCH}")
  endif()
  message(
    STATUS
      "Found cuDNN: v${CUDNN_VERSION}  (include: ${CUDNN_INCLUDE_PATH}, library: ${CUDNN_LIBRARY_PATH})"
  )
  if(CUDNN_VERSION VERSION_LESS "7.0.0")
    message(FATAL_ERROR "PyTorch requires cuDNN 7 and above.")
  endif()
endif()

# ---[ CUDA libraries wrapper

# Create new style imported libraries.

# cuda
add_library(caffe2::cuda UNKNOWN IMPORTED)
set_property(TARGET caffe2::cuda PROPERTY IMPORTED_LOCATION
                                          ${CUDAToolkit_LIBRARY_DIR})
set_property(TARGET caffe2::cuda PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                                          ${CUDAToolkit_INCLUDE_DIRS})

# cudart
add_library(torch::cudart INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET torch::cudart PROPERTY INTERFACE_LINK_LIBRARIES
                                             CUDA::cudart_static)
else()
  set_property(TARGET torch::cudart PROPERTY INTERFACE_LINK_LIBRARIES
                                             CUDA::cudart)
endif()

# cublas
add_library(caffe2::cublas INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET caffe2::cublas PROPERTY INTERFACE_LINK_LIBRARIES
                                              CUDA::cublas_static)
else()
  set_property(TARGET caffe2::cublas PROPERTY INTERFACE_LINK_LIBRARIES
                                              CUDA::cublas)
endif()

# cusparse
add_library(caffe2::cusparse INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET caffe2::cusparse PROPERTY INTERFACE_LINK_LIBRARIES
                                                CUDA::cusparse_static)
else()
  set_property(TARGET caffe2::cusparse PROPERTY INTERFACE_LINK_LIBRARIES
                                                CUDA::cusparse)
endif()

# cusolver
add_library(caffe2::cusolver INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET caffe2::cusolver PROPERTY INTERFACE_LINK_LIBRARIES
                                                CUDA::cusolver_static)
else()
  set_property(TARGET caffe2::cusolver PROPERTY INTERFACE_LINK_LIBRARIES
                                                CUDA::cusolver)
endif()

# cudnn public and private interfaces static linking is handled by
# USE_STATIC_CUDNN environment variable If library is linked dynamically, than
# private interface is no-op If library is linked statically: - public interface
# would only reference headers - private interface will contain the actual link
# instructions
if(CAFFE2_USE_CUDNN)
  add_library(caffe2::cudnn-public INTERFACE IMPORTED)
  set_property(TARGET caffe2::cudnn-public
               PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${CUDNN_INCLUDE_PATH})
  add_library(caffe2::cudnn-private INTERFACE IMPORTED)
  set_property(TARGET caffe2::cudnn-private
               PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${CUDNN_INCLUDE_PATH})
  if(CUDNN_STATIC)
    target_link_libraries(caffe2::cudnn-private INTERFACE ${CUDNN_LIBRARY_PATH}
                                                          CUDA::culibos)
    # Add explicit dependency on cublas to cudnn
    target_link_libraries(caffe2::cudnn-private INTERFACE caffe2::cublas)
    target_link_options(caffe2::cudnn-private INTERFACE
                        "-Wl,--exclude-libs,libcudnn_static.a")
  else()
    set_property(TARGET caffe2::cudnn-public PROPERTY INTERFACE_LINK_LIBRARIES
                                                      ${CUDNN_LIBRARY_PATH})
  endif()
endif()

# curand
add_library(caffe2::curand INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET caffe2::curand PROPERTY INTERFACE_LINK_LIBRARIES
                                              CUDA::curand_static)
else()
  set_property(TARGET caffe2::curand PROPERTY INTERFACE_LINK_LIBRARIES
                                              CUDA::curand)
endif()

# cufft. CUDA_CUFFT_LIBRARIES is actually a list, so we will make an interface
# library similar to cudart.
add_library(caffe2::cufft INTERFACE IMPORTED)
if(CAFFE2_STATIC_LINK_CUDA)
  set_property(TARGET caffe2::cufft PROPERTY INTERFACE_LINK_LIBRARIES
                                             CUDA::cufft_static)
else()
  set_property(TARGET caffe2::cufft PROPERTY INTERFACE_LINK_LIBRARIES
                                             CUDA::cufft)
endif()

# TensorRT
if(CAFFE2_USE_TENSORRT)
  add_library(caffe2::tensorrt UNKNOWN IMPORTED)
  set_property(TARGET caffe2::tensorrt PROPERTY IMPORTED_LOCATION
                                                ${TENSORRT_LIBRARY})
  set_property(TARGET caffe2::tensorrt PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                                                ${TENSORRT_INCLUDE_DIR})
endif()

# CUB
list(PREPEND CMAKE_PREFIX_PATH "${CUDAToolkit_TARGET_DIR}/lib64/cmake")
find_package(cub REQUIRED)
find_package(Thrust REQUIRED CONFIG)

# Note: in theory, we can add similar dependent library wrappers. For now,
# Caffe2 only uses the above libraries, so we will only wrap these.

# Add onnx namepsace definition to nvcc
if(ONNX_NAMESPACE)
  list(APPEND CMAKE_CUDA_FLAGS "-DONNX_NAMESPACE=${ONNX_NAMESPACE}")
else()
  list(APPEND CMAKE_CUDA_FLAGS "-DONNX_NAMESPACE=onnx_c2")
endif()

# # disable some nvcc diagnostic that appears in boost, glog, glags, opencv,
# etc. foreach(diag cc_clobber_ignored integer_sign_change
# useless_using_declaration set_but_not_used field_without_dll_interface
# base_class_has_different_dll_interface dll_interface_conflict_none_assumed
# dll_interface_conflict_dllexport_assumed
# implicit_return_from_non_void_function unsigned_compare_with_zero
# declared_but_not_referenced bad_friend_decl) list(APPEND
# SUPPRESS_WARNING_FLAGS --diag_suppress=${diag}) endforeach() string(REPLACE
# ";" "," SUPPRESS_WARNING_FLAGS "${SUPPRESS_WARNING_FLAGS}") list(APPEND
# CMAKE_CUDA_FLAGS -Xcudafe ${SUPPRESS_WARNING_FLAGS})

set(CUDA_PROPAGATE_HOST_FLAGS_BLOCKLIST "-Werror")
if(MSVC)
  list(APPEND CMAKE_CUDA_FLAGS "--Werror" "cross-execution-space-call")
  list(APPEND CMAKE_CUDA_FLAGS "--no-host-device-move-forward")
endif()

# Debug and Release symbol support
if(CUDA_DEVICE_DEBUG)
  list(APPEND CMAKE_CUDA_FLAGS "-g" "-G") # -G enables device code debugging
                                          # symbols
endif()

# Set expt-relaxed-constexpr to suppress Eigen warnings
list(APPEND CMAKE_CUDA_FLAGS "--expt-relaxed-constexpr")

# Set expt-extended-lambda to support lambda on device
list(APPEND CMAKE_CUDA_FLAGS "--expt-extended-lambda")

# list(APPEND CMAKE_CUDA_FLAGS "-dlto")

string(REPLACE ";" " " CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS}")

# add_link_options($<DEVICE_LINK:-dlto>)
