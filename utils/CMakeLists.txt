if (USE_CLANG_TIDY)
    set (CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_PATH}")
endif ()

set(MAX_LINKER_MEMORY 3500)
include(../cmake/limit_jobs.cmake)

if (ENABLE_CLICKHOUSE_SELF_EXTRACTING)
    add_subdirectory (self-extracting-executable)
endif ()

# Utils used in package
add_subdirectory (config-processor)
add_subdirectory (report)

# Not used in package
if (ENABLE_UTILS)
    add_subdirectory (compressor)
#    add_subdirectory (iotest)
    add_subdirectory (corrector_utf8)
    add_subdirectory (zookeeper-cli)
    add_subdirectory (zookeeper-dump-tree)
    add_subdirectory (zookeeper-remove-by-list)
    add_subdirectory (wikistat-loader)
    add_subdirectory (check-marks)
    add_subdirectory (checksum-for-compressed-block)
    add_subdirectory (check-mysql-binlog)
    add_subdirectory (keeper-bench)
    add_subdirectory (keeper-data-dumper)
    add_subdirectory (memcpy-bench)
endif ()

if (ENABLE_EXTERN_LOCAL_ENGINE)
    add_subdirectory (extern-local-engine)
endif()
