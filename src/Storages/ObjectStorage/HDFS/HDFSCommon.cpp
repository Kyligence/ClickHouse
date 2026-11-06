#include <Storages/ObjectStorage/HDFS/HDFSCommon.h>
#include <Poco/URI.h>
#include <boost/algorithm/string/replace.hpp>
#include <filesystem>
#include <mutex>
#include <unordered_map>
#include <Common/re2.h>

#if USE_HDFS
#include <Common/ShellCommand.h>
#include <Common/Exception.h>
#include <IO/Operators.h>
#include <Common/logger_useful.h>

#if USE_KRB5
    #include <Access/KerberosInit.h>
#endif


namespace DB
{

namespace ErrorCodes
{
    extern const int BAD_ARGUMENTS;
    extern const int HDFS_ERROR;
    #if USE_KRB5
    extern const int EXCESSIVE_ELEMENT_IN_CONFIG;
    extern const int KERBEROS_ERROR;
    #endif // USE_KRB5
}

static constexpr std::string_view CONFIG_PREFIX = "hdfs";
static constexpr std::string_view HDFS_URL_REGEXP = "^hdfs://[^/]*/.*";

namespace
{

void logHDFSBackendOnce()
{
    static std::once_flag flag;
    std::call_once(flag, []
    {
#if USE_LIBHDFS_JNI
        LOG_INFO(getLogger("HDFSClient"), "HDFS backend: Hadoop libhdfs (JNI)");
#elif USE_LIBHDFS3
        LOG_INFO(getLogger("HDFSClient"), "HDFS backend: Bundled libhdfs3 (native)");
#else
        LOG_WARNING(getLogger("HDFSClient"), "HDFS backend: unknown");
#endif
    });
}

}


HDFSFileInfo::~HDFSFileInfo()
{
    hdfsFreeFileInfo(file_info, length);
}


void HDFSBuilderWrapper::loadFromConfig(
    const Poco::Util::AbstractConfiguration & config, const String & prefix, [[maybe_unused]] bool isUser)
{
    Poco::Util::AbstractConfiguration::Keys keys;

    config.keys(prefix, keys);
    for (const auto & key : keys)
    {
        const String key_path = prefix + "." + key;

        String key_name;
        if (key == "hadoop_kerberos_keytab")
        {
            #if USE_KRB5
            need_kinit = true;
            hadoop_kerberos_keytab = config.getString(key_path);
            #else // USE_KRB5
            LOG_WARNING(getLogger("HDFSClient"), "hadoop_kerberos_keytab parameter is ignored because ClickHouse was built without support of krb5 library.");
            #endif // USE_KRB5
            continue;
        }
        if (key == "hadoop_kerberos_principal")
        {
            #if USE_KRB5
            need_kinit = true;
            hadoop_kerberos_principal = config.getString(key_path);
            hdfsBuilderSetPrincipal(hdfs_builder, keepString(hadoop_kerberos_principal));
            #else // USE_KRB5
            LOG_WARNING(
                getLogger("HDFSClient"),
                "hadoop_kerberos_principal parameter is ignored because ClickHouse was built without support of krb5 library.");
            #endif // USE_KRB5
            continue;
        }
        if (key == "hadoop_security_kerberos_ticket_cache_path")
        {
            #if USE_KRB5
            if (isUser)
            {
                throw Exception(
                    ErrorCodes::EXCESSIVE_ELEMENT_IN_CONFIG, "hadoop.security.kerberos.ticket.cache.path cannot be set per user");
            }

            hadoop_security_kerberos_ticket_cache_path = config.getString(key_path);
        // standard param - pass further
            #else // USE_KRB5
            LOG_WARNING(
                getLogger("HDFSClient"),
                "hadoop.security.kerberos.ticket.cache.path parameter is ignored because ClickHouse was built without support of krb5 "
                "library.");
            #endif // USE_KRB5
        }

        key_name = boost::replace_all_copy(key, "_", ".");

        const auto & [k,v] = keep(key_name, config.getString(key_path));
        hdfsBuilderConfSetStr(hdfs_builder, k.c_str(), v.c_str());
    }
}

#if USE_KRB5
void HDFSBuilderWrapper::runKinit() const
{
    if (!need_kinit)
    {
        return;
    }

    LOG_DEBUG(getLogger("HDFSClient"), "Running KerberosInit");
    try
    {
        kerberosInit(hadoop_kerberos_keytab,hadoop_kerberos_principal,hadoop_security_kerberos_ticket_cache_path);
    }
    catch (const DB::Exception & e)
    {
        throw Exception(ErrorCodes::KERBEROS_ERROR, "KerberosInit failure: {}", getExceptionMessage(e, false));
    }
    LOG_DEBUG(getLogger("HDFSClient"), "Finished KerberosInit");
}
#endif // USE_KRB5

HDFSBuilderWrapper createHDFSBuilder(const String & uri_str, const Poco::Util::AbstractConfiguration & config)
{
    logHDFSBackendOnce();

    const Poco::URI uri(uri_str);
    const auto & host = uri.getHost();
    auto port = uri.getPort();
    if (host.empty())
        throw Exception(ErrorCodes::BAD_ARGUMENTS, "Illegal HDFS URI: {}", uri.toString());

    HDFSBuilderWrapper builder;
    if (builder.get() == nullptr)
        throw Exception(ErrorCodes::HDFS_ERROR, "Unable to create builder to connect to HDFS: {} {}",
            uri.toString(), String(hdfsGetLastError()));

    #if USE_LIBHDFS_JNI
    /// Hadoop's libhdfs connects through FileSystem.get() by default, which returns the
    /// JVM-wide cached FileSystem that is shared with Spark. hdfsDisconnect() closes that
    /// instance (FileSystem#close), so finishing a native read invalidates Spark's cached
    /// FileSystem and leads to "java.io.IOException: Filesystem closed".
    /// Force a private FileSystem instance so that closing it is isolated from the JVM.
    hdfsBuilderSetForceNewInstance(builder.get());
    #endif

    #if USE_LIBHDFS3
    hdfsBuilderConfSetStr(builder.get(), "input.read.timeout", "60000"); // 1 min
    hdfsBuilderConfSetStr(builder.get(), "input.write.timeout", "60000"); // 1 min
    hdfsBuilderConfSetStr(builder.get(), "input.connect.timeout", "60000"); // 1 min
    #elif USE_LIBHDFS_JNI
    hdfsBuilderConfSetStr(builder.get(), "dfs.client.socket-timeout", "60000"); // 1 min
    hdfsBuilderConfSetStr(builder.get(), "dfs.datanode.socket.write.timeout", "60000"); // 1 min
    hdfsBuilderConfSetStr(builder.get(), "ipc.client.connect.timeout", "60000"); // 1 min
    #endif

    const String & user_info = uri.getUserInfo();
    String user;
    if (!user_info.empty() && user_info.front() != ':')
    {
        size_t delim_pos = user_info.find(':');
        if (delim_pos != String::npos)
            user = user_info.substr(0, delim_pos);
        else
            user = user_info;

        hdfsBuilderSetUserName(builder.get(), builder.keepString(user));
    }

    hdfsBuilderSetNameNode(builder.get(), builder.keepString(host));
    if (port != 0)
    {
        hdfsBuilderSetNameNodePort(builder.get(), port);
    }

    builder.loadFromConfig(config, std::string(CONFIG_PREFIX));

    if (!user.empty())
    {
        String user_config_prefix = std::string(CONFIG_PREFIX) + "_" + user;
        if (config.has(user_config_prefix))
        {
            builder.loadFromConfig(config, user_config_prefix, true);
        }
    }

    #if USE_KRB5
    builder.runKinit();
    #if USE_LIBHDFS_JNI
    if (!builder.hadoop_security_kerberos_ticket_cache_path.empty())
        hdfsBuilderSetKerbTicketCachePath(builder.get(), builder.keepString(builder.hadoop_security_kerberos_ticket_cache_path));
    #endif
    #endif // USE_KRB5

#if USE_LIBHDFS_JNI
    /// Mirrors the key Hadoop uses for its FileSystem.CACHE: name node + user.
    /// The URI scheme is intentionally omitted: checkHDFSURL() only accepts
    /// "hdfs://", so the name node alone is unique within the process.
    /// The path is intentionally not part of the key, otherwise every file would
    /// get its own connection.
    String name_node = host;
    if (port != 0)
        name_node += ":" + std::to_string(port);
    builder.connection_key = name_node + "#" + user;
#endif

    return builder;
}

namespace
{

#if USE_LIBHDFS_JNI

/// Process-wide cache of HDFS connections for the JNI backend.
///
/// Hadoop's libhdfs keeps the corresponding FileSystem object inside the JVM,
/// and hdfsDisconnect() closes it. Creating one connection per file is expensive
/// (a new DFSClient plus NameNode RPC), while disconnecting it must not touch
/// Spark's FileSystem.CACHE. Connections are therefore created with
/// hdfsBuilderSetForceNewInstance() (see createHDFSBuilder) and kept alive for
/// the whole process.
///
/// The cache is intentionally never cleaned up: calling hdfsDisconnect() during
/// static destruction or JVM shutdown may race with a partially destroyed JVM.
std::mutex hdfs_fs_cache_mutex;
std::unordered_map<String, hdfsFS> hdfs_fs_cache;

#endif

}

HDFSFSPtr createHDFSFS(HDFSBuilderWrapper & builder)
{
#if USE_LIBHDFS_JNI
    const String & key = builder.getConnectionKey();

    {
        std::lock_guard lock(hdfs_fs_cache_mutex);
        auto it = hdfs_fs_cache.find(key);
        if (it != hdfs_fs_cache.end())
        {
            /// hdfsBuilderConnect() was not called, so the caller's builder is
            /// still alive and has to be released here.
            builder.resetBuilder();
            return HDFSFSPtr(it->second, detail::HDFSFsNoopDeleter{});
        }
    }

    /// The connection is created with FileSystem.newInstance(), so closing a
    /// concurrently created duplicate cannot affect other users of the cache.
    /// libhdfs frees the builder inside hdfsBuilderConnect().
    hdfsFS fs = hdfsBuilderConnect(builder.release());
    if (fs == nullptr)
        throw Exception(ErrorCodes::HDFS_ERROR, "Unable to connect to HDFS: {}", String(hdfsGetLastError()));

    std::lock_guard lock(hdfs_fs_cache_mutex);
    auto [it, inserted] = hdfs_fs_cache.emplace(key, fs);
    if (!inserted)
    {
        hdfsDisconnect(fs);
        fs = it->second;
    }

    return HDFSFSPtr(fs, detail::HDFSFsNoopDeleter{});
#else
    HDFSFSPtr fs(hdfsBuilderConnect(builder.get()));
    if (fs == nullptr)
        throw Exception(ErrorCodes::HDFS_ERROR, "Unable to connect to HDFS: {}", String(hdfsGetLastError()));

    return fs;
#endif
}

String getNameNodeUrl(const String & hdfs_url)
{
    const size_t pos = hdfs_url.find('/', hdfs_url.find("//") + 2);
    String namenode_url = hdfs_url.substr(0, pos) + "/";
    return namenode_url;
}

String getNameNodeCluster(const String &hdfs_url)
{
    auto pos1 = hdfs_url.find("//") + 2;
    auto pos2 = hdfs_url.find('/', pos1);

    return hdfs_url.substr(pos1, pos2 - pos1);
}

void checkHDFSURL(const String & url)
{
    if (!re2::RE2::FullMatch(url, std::string(HDFS_URL_REGEXP)))
        throw Exception(ErrorCodes::BAD_ARGUMENTS, "Bad HDFS URL: {}. It should have structure 'hdfs://<host_name>:<port>/<path>'", url);
}

}

#endif
