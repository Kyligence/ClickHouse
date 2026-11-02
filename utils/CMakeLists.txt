if (USE_CLANG_TIDY)
    set (CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_PATH}")
endif ()

if (ENABLE_CLICKHOUSE_SELF_EXTRACTING)
    add_subdirectory (self-extracting-executable)
endif ()

if (USE_BINARY_HASH)
    add_subdirectory (hash-binary)
endif ()

if (ENABLE_EXTERN_LOCAL_ENGINE)
    add_subdirectory (extern-local-engine)

    if (TARGET _gluten_ch)
        # Make libchd.so relocatable: resolve dependent shared libraries
        # (libhdfs.so.0.0.0) relative to the library itself instead of baking
        # the build machine paths into RUNPATH.
        set_target_properties(_gluten_ch PROPERTIES
            BUILD_WITH_INSTALL_RPATH TRUE
            INSTALL_RPATH "\$ORIGIN"
            INSTALL_RPATH_USE_LINK_PATH FALSE)

        # Ship libhdfs.so next to libchd.so so that $ORIGIN works without
        # LD_LIBRARY_PATH or patchelf.
        if (HDFS_BACKEND STREQUAL "jni" AND HDFS_LIBRARY MATCHES "\\.(so|dylib)(\\.|$)")
            get_filename_component(_hdfs_library_real "${HDFS_LIBRARY}" REALPATH)
            get_filename_component(_hdfs_library_name "${_hdfs_library_real}" NAME)
            set(_hdfs_library_dest "${CMAKE_CURRENT_BINARY_DIR}/extern-local-engine/${_hdfs_library_name}")
            add_custom_target(copy_hdfs_lib_for_local_engine
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${_hdfs_library_real}" "${_hdfs_library_dest}"
                DEPENDS _gluten_ch
                COMMENT "Copying ${_hdfs_library_name} next to libchd.so")
            if (TARGET libch)
                add_dependencies(libch copy_hdfs_lib_for_local_engine)
            endif()
        endif()
    endif()
endif ()
    
# Not used in packages
if (ENABLE_UTILS)
    add_subdirectory (corrector_utf8)
    add_subdirectory (memcpy-bench)
endif ()
