#pragma once

#include "config.h"

#if USE_HDFS
#include <hdfs/hdfs.h>

/// Hadoop's libhdfs (JNI) does not provide a few functions implemented by libhdfs3.
/// Keep the call sites independent of the selected backend.
#if USE_LIBHDFS_JNI

#include <cerrno>
#include <cstring>

inline const char * hdfsGetLastError()
{
    return std::strerror(errno);
}

inline void hdfsBuilderSetPrincipal(struct hdfsBuilder *, const char *)
{
    /// libhdfs takes the principal from core-site.xml or from the UGI of the process.
}

inline int hdfsSync(hdfsFS fs, hdfsFile file)
{
    return hdfsHSync(fs, file);
}

#endif // USE_LIBHDFS_JNI

/// libhdfs3 places the offset after the buffer, libhdfs places it before it.
inline tSize hdfsPreadCompat(hdfsFS fs, hdfsFile file, void * buffer, tSize length, tOffset position)
{
#if USE_LIBHDFS_JNI
    return ::hdfsPread(fs, file, position, buffer, length);
#else
    return ::hdfsPread(fs, file, buffer, length, position);
#endif
}

#endif // USE_HDFS
