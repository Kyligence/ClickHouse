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

    /// In the JNI backend connections are cached for the whole process (see
    /// createHDFSFS), so the handle owned by a reader is only a view of the
    /// cached connection and must not be disconnected on destruction.
    struct HDFSFsNoopDeleter
    {
        void operator()(hdfsFS /* fs_ptr */) {}
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
    #if USE_LIBHDFS_JNI
        connection_key = std::move(other.connection_key);
    #endif
    #if USE_KRB5
        hadoop_kerberos_keytab = std::move(other.hadoop_kerberos_keytab);
        hadoop_kerberos_principal = std::move(other.hadoop_kerberos_principal);
        hadoop_security_kerberos_ticket_cache_path = std::move(other.hadoop_security_kerberos_ticket_cache_path);
        need_kinit = std::move(other.need_kinit);
    #endif
        return *this;
    }

    hdfsBuilder * get() const { return hdfs_builder; }

#if USE_LIBHDFS_JNI
    /// Name node + user used to key the process-wide JNI connection cache.
    const String & getConnectionKey() const { return connection_key; }
#endif

    /// Release the builder without connecting. Needed when a cached connection is
    /// reused: hdfsBuilderConnect() frees the builder itself in the JNI backend,
    /// but it is not called in that case.
    void resetBuilder()
    {
        if (!hdfs_builder)
            return;
    #if USE_LIBHDFS_JNI
        hdfsFreeBuilder(hdfs_builder);
    #endif
        hdfs_builder = nullptr;
    }

    /// Give up ownership of the builder. Used by the JNI backend, where
    /// hdfsBuilderConnect() frees the builder internally.
    hdfsBuilder * release()
    {
        hdfsBuilder * result = hdfs_builder;
        hdfs_builder = nullptr;
        return result;
    }

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
#if USE_LIBHDFS_JNI
    String connection_key;
#endif

    #if USE_KRB5
    String hadoop_kerberos_keytab;
    String hadoop_kerberos_principal;
    String hadoop_security_kerberos_ticket_cache_path;
    bool need_kinit{false};
    #endif // USE_KRB5
};

#if USE_LIBHDFS_JNI
/// JNI connections live in a process-wide cache (see createHDFSFS), so destroying
/// a reader must not disconnect the shared connection.
using HDFSFSPtr = std::unique_ptr<std::remove_pointer_t<hdfsFS>, detail::HDFSFsNoopDeleter>;
#else
using HDFSFSPtr = std::unique_ptr<std::remove_pointer_t<hdfsFS>, detail::HDFSFsDeleter>;
#endif


// set read/connect timeout, default value in libhdfs3 is about 1 hour, and too large
/// TODO Allow to tune from query Settings.
HDFSBuilderWrapper createHDFSBuilder(const String & uri_str, const Poco::Util::AbstractConfiguration &);
HDFSFSPtr createHDFSFS(HDFSBuilderWrapper & builder);


String getNameNodeUrl(const String & hdfs_url);
String getNameNodeCluster(const String & hdfs_url);

/// Check that url satisfy structure 'hdfs://<host_name>:<port>/<path>'
/// and throw exception if it doesn't;
void checkHDFSURL(const String & url);

}
#endif
