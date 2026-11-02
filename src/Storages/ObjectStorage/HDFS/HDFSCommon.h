#pragma once

#include "config.h"

#if USE_HDFS
#include <deque>
#include <memory>
#include <type_traits>

#include <Storages/ObjectStorage/HDFS/HDFSBackendCompat.h>
#include <base/types.h>

#include <Poco/Util/AbstractConfiguration.h>


namespace DB
{

namespace detail
{
    struct HDFSFsDeleter
    {
        void operator()(hdfsFS fs_ptr)
        {
            hdfsDisconnect(fs_ptr);
        }
    };
}


struct HDFSFileInfo
{
    hdfsFileInfo * file_info;
    int length;

    HDFSFileInfo() : file_info(nullptr) , length(0) {}

    HDFSFileInfo(const HDFSFileInfo & other) = delete;
    HDFSFileInfo(HDFSFileInfo && other) = default;
    HDFSFileInfo & operator=(const HDFSFileInfo & other) = delete;
    HDFSFileInfo & operator=(HDFSFileInfo && other) = default;
    ~HDFSFileInfo();
};


class HDFSBuilderWrapper
{

friend HDFSBuilderWrapper createHDFSBuilder(const String & uri_str, const Poco::Util::AbstractConfiguration &);

static const String CONFIG_PREFIX;

public:
    HDFSBuilderWrapper() : hdfs_builder(hdfsNewBuilder()) {}

    /// Hadoop's libhdfs frees the builder inside hdfsBuilderConnect, while libhdfs3
    /// leaves it to the caller. Avoid a double free in the JNI case.
    ~HDFSBuilderWrapper()
    {
#if USE_LIBHDFS3
        if (hdfs_builder)
            hdfsFreeBuilder(hdfs_builder);
#endif
    }

    HDFSBuilderWrapper(const HDFSBuilderWrapper &) = delete;
    HDFSBuilderWrapper & operator=(const HDFSBuilderWrapper &) = delete;

    HDFSBuilderWrapper(HDFSBuilderWrapper && other) noexcept
    {
        *this = std::move(other);
    }

    HDFSBuilderWrapper & operator=(HDFSBuilderWrapper && other) noexcept
    {
        std::swap(hdfs_builder, other.hdfs_builder);
        string_stor = std::move(other.string_stor);
        config_stor = std::move(other.config_stor);
    #if USE_KRB5
        hadoop_kerberos_keytab = std::move(other.hadoop_kerberos_keytab);
        hadoop_kerberos_principal = std::move(other.hadoop_kerberos_principal);
        hadoop_security_kerberos_ticket_cache_path = std::move(other.hadoop_security_kerberos_ticket_cache_path);
        need_kinit = std::move(other.need_kinit);
    #endif
        return *this;
    }

    hdfsBuilder * get() const { return hdfs_builder; }

    #if USE_KRB5
    void runKinit() const;
    #endif // USE_KRB5

private:
    void loadFromConfig(const Poco::Util::AbstractConfiguration & config, const String & prefix, bool isUser = false);

    /// Hadoop's libhdfs shallow-copies strings passed to the builder setters, so they
    /// must stay alive until hdfsBuilderConnect. std::deque keeps element addresses
    /// stable on insertion and on move.
    const char * keepString(String value)
    {
        string_stor.emplace_back(std::move(value));
        return string_stor.back().c_str();
    }

    // hdfs builder relies on an external config data storage
    std::pair<String, String>& keep(const String & k, const String & v)
    {
        return config_stor.emplace_back(std::make_pair(k, v));
    }

    hdfsBuilder * hdfs_builder = nullptr;
    std::deque<String> string_stor;
    std::deque<std::pair<String, String>> config_stor;

    #if USE_KRB5
    String hadoop_kerberos_keytab;
    String hadoop_kerberos_principal;
    String hadoop_security_kerberos_ticket_cache_path;
    bool need_kinit{false};
    #endif // USE_KRB5
};

using HDFSFSPtr = std::unique_ptr<std::remove_pointer_t<hdfsFS>, detail::HDFSFsDeleter>;


// set read/connect timeout, default value in libhdfs3 is about 1 hour, and too large
/// TODO Allow to tune from query Settings.
HDFSBuilderWrapper createHDFSBuilder(const String & uri_str, const Poco::Util::AbstractConfiguration &);
HDFSFSPtr createHDFSFS(hdfsBuilder * builder);


String getNameNodeUrl(const String & hdfs_url);
String getNameNodeCluster(const String & hdfs_url);

/// Check that url satisfy structure 'hdfs://<host_name>:<port>/<path>'
/// and throw exception if it doesn't;
void checkHDFSURL(const String & url);

}
#endif
