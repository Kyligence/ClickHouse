# Hadoop's libhdfs is the JNI-based HDFS client shipped with a Hadoop distribution.
# Unlike contrib/libhdfs3 it is not bundled with ClickHouse: point HADOOP_HOME
# (or HDFS_INCLUDE_DIR / HDFS_LIBRARY) at an existing Hadoop installation.

set(HADOOP_HOME "$ENV{HADOOP_HOME}" CACHE PATH "Hadoop installation prefix")

find_path(HDFS_INCLUDE_DIR
    NAMES hdfs.h
    HINTS "${HADOOP_HOME}/include" "$ENV{HADOOP_HOME}/include")

# ClickHouse reverses CMAKE_FIND_LIBRARY_SUFFIXES to prefer static libraries, but
# Hadoop's prebuilt libhdfs.a is not PIC and cannot be linked into a shared library
# (e.g. the Gluten local engine). Prefer the shared library unless explicitly asked.
option(HDFS_PREFER_STATIC "Link Hadoop libhdfs statically (the archive must be built with -fPIC)" OFF)

find_file(HDFS_SHARED_LIBRARY
    NAMES libhdfs.so libhdfs.dylib
    HINTS "${HADOOP_HOME}/lib/native" "$ENV{HADOOP_HOME}/lib/native"
          "${HADOOP_HOME}/lib" "$ENV{HADOOP_HOME}/lib")

find_library(HDFS_STATIC_LIBRARY
    NAMES hdfs
    HINTS "${HADOOP_HOME}/lib/native" "$ENV{HADOOP_HOME}/lib/native"
          "${HADOOP_HOME}/lib" "$ENV{HADOOP_HOME}/lib")

if (HDFS_PREFER_STATIC)
    set(_hdfs_library "${HDFS_STATIC_LIBRARY}")
elseif (HDFS_LIBRARY AND EXISTS "${HDFS_LIBRARY}" AND NOT HDFS_LIBRARY STREQUAL HDFS_STATIC_LIBRARY)
    # Explicit user-provided library (e.g. a custom -fPIC archive).
    set(_hdfs_library "${HDFS_LIBRARY}")
elseif (HDFS_SHARED_LIBRARY)
    set(_hdfs_library "${HDFS_SHARED_LIBRARY}")
elseif (HDFS_STATIC_LIBRARY)
    set(_hdfs_library "${HDFS_STATIC_LIBRARY}")
    message(WARNING "Only a static libhdfs was found; it must be built with -fPIC to link into shared libraries")
else()
    set(_hdfs_library "")
endif()

if (NOT HDFS_INCLUDE_DIR)
    message(FATAL_ERROR "Cannot find Hadoop hdfs.h. Set -DHADOOP_HOME=... or -DHDFS_INCLUDE_DIR=...")
endif()
if (NOT _hdfs_library)
    message(FATAL_ERROR "Cannot find Hadoop libhdfs. Set -DHADOOP_HOME=... or -DHDFS_LIBRARY=...")
endif()

set(HDFS_LIBRARY "${_hdfs_library}" CACHE FILEPATH "Hadoop libhdfs library" FORCE)

# ClickHouse sources include <hdfs/hdfs.h>, while Hadoop installs <prefix>/include/hdfs.h.
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include/hdfs")
configure_file("${HDFS_INCLUDE_DIR}/hdfs.h"
               "${CMAKE_CURRENT_BINARY_DIR}/include/hdfs/hdfs.h" COPYONLY)

add_library(_hdfs_jni UNKNOWN IMPORTED GLOBAL)
set_target_properties(_hdfs_jni PROPERTIES
    IMPORTED_LOCATION "${HDFS_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_BINARY_DIR}/include")

# libhdfs.so starts a JVM through JNI; a static libhdfs.a additionally needs JVM symbols at link time.
find_package(JNI QUIET)
find_package(Threads REQUIRED)
set(_hdfs_jni_link_libraries Threads::Threads)
if (HDFS_LIBRARY MATCHES "\\.(a|lib)$")
    if (JNI_FOUND AND JAVA_JVM_LIBRARY)
        # JNI_LIBRARIES also contains libjawt, which is not needed by libhdfs.
        list(APPEND _hdfs_jni_link_libraries "${JAVA_JVM_LIBRARY}")
    elseif (JNI_FOUND)
        list(APPEND _hdfs_jni_link_libraries "${JNI_LIBRARIES}")
    else()
        message(STATUS "JNI not found: assuming libhdfs is linked against libjvm")
    endif()
endif()
set_property(TARGET _hdfs_jni PROPERTY
    INTERFACE_LINK_LIBRARIES "${_hdfs_jni_link_libraries}")

add_library(ch_contrib::hdfs ALIAS _hdfs_jni)

message(STATUS "Using Hadoop libhdfs (JNI): ${HDFS_LIBRARY}, headers: ${HDFS_INCLUDE_DIR}")
