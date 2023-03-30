set(SOURCE_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../..)

# prepare gtest
set(GTEST_LIB "")
if (ENABLE_TESTS)
    set(GTEST_LIB _gtest _gtest_main)
endif()
add_custom_command(OUTPUT copy_deps
        COMMAND rm -rf deps && mkdir -p deps &&
        cp $<TARGET_FILE:dbms> deps/ &&
        cp $<TARGET_FILE:clickhouse_common_io> deps/ &&
        cp $<TARGET_FILE:clickhouse_aggregate_functions> deps/ &&
        cp $<TARGET_FILE:clickhouse_new_delete> deps/ &&
        cp $<TARGET_FILE:clickhouse_functions_jsonpath> deps/ &&
        cp $<TARGET_FILE:clickhouse_parsers> deps/ &&
        cp $<TARGET_FILE:clickhouse_common_zookeeper> deps/ &&
        cp $<TARGET_FILE:clickhouse_common_access> deps/ &&
        cp $<TARGET_FILE:clickhouse_common_config> deps/ &&
        cp $<TARGET_FILE:clickhouse_functions_gatherutils> deps/ &&
        cp $<TARGET_FILE:clickhouse_dictionaries_embedded> deps/ &&
        cp $<TARGET_FILE:clickhouse_common_access> deps/ &&
        cp $<TARGET_FILE:loggers> deps/ &&
        cp $<TARGET_FILE:common> deps/ &&
        cp $<TARGET_FILE:string_utils> deps/ &&
        cp $<TARGET_FILE:readpassphrase> deps/ &&

        cp $<TARGET_FILE:Poco::Foundation> deps/ &&
        cp ${CMAKE_BINARY_DIR}/contrib/boost-cmake/*.a deps/ &&
        cp ${CMAKE_BINARY_DIR}/contrib/abseil-cpp/absl/*/*.a deps/ &&
        cp ${CMAKE_BINARY_DIR}/contrib/icu-cmake/*.a deps/ &&
        cp $<TARGET_FILE:ch_contrib::cityhash> deps/ &&
        cp $<TARGET_FILE:ch_contrib::nuraft> deps/ &&
        cp $<TARGET_FILE:ch_contrib::aws_s3> deps/ &&
        cp $<TARGET_FILE:ch_contrib::krb5> deps/ &&
        cp $<TARGET_FILE:ch_contrib::rocksdb> deps/ &&
        cp $<TARGET_FILE:ch_contrib::snappy> deps/ &&
        cp $<TARGET_FILE:ch_contrib::cctz> deps/ &&
        cp $<TARGET_FILE:ch_contrib::xz> deps/ &&
        cp $<TARGET_FILE:ch_contrib::fmt> deps/ &&
        cp $<TARGET_FILE:ch_contrib::re2> deps/ &&
        cp $<TARGET_FILE:ch_contrib::re2_st> deps/ &&
        cp $<TARGET_FILE:ch_contrib::metrohash> deps/ &&
        cp $<TARGET_FILE:ch_contrib::lz4> deps/ &&
        cp $<TARGET_FILE:ch_contrib::cityhash> deps/ &&
        cp $<TARGET_FILE:ch_contrib::dragonbox_to_chars> deps/ &&
        cp $<TARGET_FILE:ch_contrib::roaring> deps/ &&
        cp $<TARGET_FILE:ch_contrib::double_conversion> deps/ &&
        cp $<TARGET_FILE:ch_contrib::zlib> deps/ &&
        cp $<TARGET_FILE:ch_contrib::zstd> deps/ &&
        cp $<TARGET_FILE:ch_contrib::farmhash> deps/ &&
        cp $<TARGET_FILE:ch_contrib::hashidsxx> deps/ &&
        cp $<TARGET_FILE:ch_contrib::murmurhash> deps/ &&
        cp $<TARGET_FILE:ch_contrib::fastops> deps/ &&
        cp $<TARGET_FILE:ch_contrib::simdjson> deps/ &&
        cp $<TARGET_FILE:ch_contrib::vectorscan> deps/ &&
        cp $<TARGET_FILE:ch_contrib::base64> deps/ &&
        cp $<TARGET_FILE:ch_contrib::consistent_hashing> deps/ &&
        cp $<TARGET_FILE:ch_contrib::jemalloc> deps/ &&
        cp $<TARGET_FILE:ch_contrib::c-ares> deps/ &&
        cp $<TARGET_FILE:ch_contrib::hdfs> deps/ &&
        cp $<TARGET_FILE:ch_contrib::yaml_cpp> deps/ &&
        cp $<TARGET_FILE:ch_contrib::parquet> deps/ &&
        cp $<TARGET_FILE:ch_contrib::avrocpp> deps/ &&
        cp $<TARGET_FILE:ch_contrib::nats_io> deps/ &&
        cp $<TARGET_FILE:ch_contrib::replxx> deps/ &&

        cp ${CMAKE_BINARY_DIR}/contrib/libunwind-cmake/*.a deps/ &&
        cp ${CMAKE_BINARY_DIR}/src/Functions/divide/*.a deps/ &&
        cp $<TARGET_FILE:Poco::Crypto> deps/ &&
        cp $<TARGET_FILE:Poco::Foundation> deps/ &&
        cp $<TARGET_FILE:Poco::Data> deps/ &&
        cp $<TARGET_FILE:Poco::JSON> deps/ &&
        cp $<TARGET_FILE:Poco::JSON::Pdjson> deps/ &&
        cp $<TARGET_FILE:Poco::Net> deps/ &&
        cp $<TARGET_FILE:Poco::Net::SSL> deps/ &&
        cp $<TARGET_FILE:Poco::Util> deps/ &&
        cp ${CMAKE_BINARY_DIR}/contrib/poco-cmake/XML/*.a deps/ &&
        cp $<TARGET_FILE:Poco::MongoDB> deps/ &&
        cp $<TARGET_FILE:ch_contrib::thrift> deps/ &&
        cp $<TARGET_FILE:OpenSSL::Crypto> deps/ &&
        cp $<TARGET_FILE:OpenSSL::SSL> deps/ &&
        cp $<TARGET_FILE:Poco::Foundation::PCRE> deps/ &&
        cp ${CMAKE_BINARY_DIR}/contrib/llvm-project/llvm/lib/*.a deps/ &&
        cp $<TARGET_FILE:_arrow> deps/ &&
        cp $<TARGET_FILE:_parquet> deps/ &&
        cp $<TARGET_FILE:_orc> deps/ &&
        cp $<TARGET_FILE:protobuf::libprotobuf> deps/ &&
        cp $<TARGET_FILE:protobuf::libprotoc> deps/ &&
        cp $<TARGET_FILE:ch_contrib::thrift> deps/ &&
        cp $<TARGET_FILE:ch_contrib::amqp_cpp> deps/ &&
        cp $<TARGET_FILE:ch_contrib::zlib> deps/ &&
        cp $<TARGET_FILE:ch_contrib::gsasl> deps/ &&
        cp $<TARGET_FILE:ch_contrib::libxml2> deps/ &&
        cp $<TARGET_FILE:ch_contrib::uv> deps/ &&
        cp $<TARGET_FILE:ch_contrib::minizip> deps/
        DEPENDS dbms
        clickhouse_parsers
        clickhouse_aggregate_functions
        clickhouse_common_io
        clickhouse_new_delete
        clickhouse_functions_jsonpath
        clickhouse_common_zookeeper
        ${GTEST_LIB}
        )

add_custom_command(OUTPUT copy_objects
        COMMAND rm -rf objects && mkdir -p objects &&
        cp ${CMAKE_BINARY_DIR}/src/Functions/URL/CMakeFiles/clickhouse_functions_url.dir/*.o objects/ &&
        cp ${CMAKE_BINARY_DIR}/src/Functions/array/CMakeFiles/clickhouse_functions_array.dir/*.o objects/ &&
        cp ${CMAKE_BINARY_DIR}/src/Functions/CMakeFiles/clickhouse_functions_obj.dir/*.o objects/
        DEPENDS clickhouse_functions_obj clickhouse_functions_array clickhouse_functions_url readpassphrase)

add_custom_target(build_clickhouse_dep ALL DEPENDS copy_objects copy_deps)


