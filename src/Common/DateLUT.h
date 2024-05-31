#pragma once

#include <base/defines.h>
#include <base/types.h>

#include <boost/noncopyable.hpp>

#include <atomic>
#include <memory>
#include <mutex>
#include <unordered_map>

namespace DB
{
class Context;
using ContextPtr = std::shared_ptr<const Context>;
}

class DateLUTImpl;

static const std::unordered_map<std::string, std::string> JAVA_TIMEZONE_MAPPING
    = {{"GMT", "Etc/GMT"}, //
       {"GMT+1", "Etc/GMT-1"},     {"GMT+2", "Etc/GMT-2"},      {"GMT+3", "Etc/GMT-3"},      {"GMT+4", "Etc/GMT-4"},
       {"GMT+5", "Etc/GMT-5"},     {"GMT+6", "Etc/GMT-6"},      {"GMT+7", "Etc/GMT-7"},      {"GMT+8", "Etc/GMT-8"},
       {"GMT+9", "Etc/GMT-9"},     {"GMT+10", "Etc/GMT-10"},    {"GMT+11", "Etc/GMT-11"},    {"GMT+12", "Etc/GMT-12"}, //
       {"GMT-1", "Etc/GMT+1"},     {"GMT-2", "Etc/GMT+2"},      {"GMT-3", "Etc/GMT+3"},      {"GMT-4", "Etc/GMT+4"},
       {"GMT-5", "Etc/GMT+5"},     {"GMT-6", "Etc/GMT+6"},      {"GMT-7", "Etc/GMT+7"},      {"GMT-8", "Etc/GMT+8"},
       {"GMT-9", "Etc/GMT+9"},     {"GMT-10", "Etc/GMT+10"},    {"GMT-11", "Etc/GMT+11"},    {"GMT-12", "Etc/GMT+12"}, //
       {"GMT+00:00", "Etc/GMT"}, //
       {"GMT+01:00", "Etc/GMT-1"}, {"GMT+02:00", "Etc/GMT-2"},  {"GMT+03:00", "Etc/GMT-3"},  {"GMT+04:00", "Etc/GMT-4"},
       {"GMT+05:00", "Etc/GMT-5"}, {"GMT+06:00", "Etc/GMT-6"},  {"GMT+07:00", "Etc/GMT-7"},  {"GMT+08:00", "Etc/GMT-8"},
       {"GMT+09:00", "Etc/GMT-9"}, {"GMT+10:00", "Etc/GMT-10"}, {"GMT+11:00", "Etc/GMT-11"}, {"GMT+12:00", "Etc/GMT-12"}, //
       {"GMT-01:00", "Etc/GMT+1"}, {"GMT-02:00", "Etc/GMT+2"},  {"GMT-03:00", "Etc/GMT+3"},  {"GMT-04:00", "Etc/GMT+4"},
       {"GMT-05:00", "Etc/GMT+5"}, {"GMT-06:00", "Etc/GMT+6"},  {"GMT-07:00", "Etc/GMT+7"},  {"GMT-08:00", "Etc/GMT+8"},
       {"GMT-09:00", "Etc/GMT+9"}, {"GMT-10:00", "Etc/GMT+10"}, {"GMT-11:00", "Etc/GMT+11"}, {"GMT-12:00", "Etc/GMT+12"}};

/// This class provides lazy initialization and lookup of singleton DateLUTImpl objects for a given timezone.
class DateLUT : private boost::noncopyable
{
public:
    /// Return DateLUTImpl instance for session timezone.
    /// session_timezone is a session-level setting.
    /// If setting is not set, returns the server timezone.
    static const DateLUTImpl & instance();

    static ALWAYS_INLINE const DateLUTImpl & instance(const std::string & time_zone)
    {
        if (time_zone.empty())
            return instance();

        const auto & date_lut = getInstance();
        return date_lut.getImplementation(time_zone);
    }

    /// Return singleton DateLUTImpl for the server time zone.
    /// It may be set using 'timezone' server setting.
    static ALWAYS_INLINE const DateLUTImpl & serverTimezoneInstance()
    {
        const auto & date_lut = getInstance();
        return *date_lut.default_impl.load(std::memory_order_acquire);
    }

    static void setDefaultTimezone(const std::string & time_zone)
    {
        auto & date_lut = getInstance();
        const auto & impl = date_lut.getImplementation(time_zone);
        date_lut.default_impl.store(&impl, std::memory_order_release);
    }

    static ALWAYS_INLINE String mappingForJavaTimezone(const std::string & time_zone)
    {
        const auto it = JAVA_TIMEZONE_MAPPING.find(time_zone);
        return (it != JAVA_TIMEZONE_MAPPING.end()) ? it->second : time_zone;
    }

protected:
    DateLUT();

private:
    static DateLUT & getInstance();

    static std::string extractTimezoneFromContext(DB::ContextPtr query_context);

    const DateLUTImpl & getImplementation(const std::string & time_zone) const;

    using DateLUTImplPtr = std::unique_ptr<DateLUTImpl>;

    /// Time zone name -> implementation.
    mutable std::unordered_map<std::string, DateLUTImplPtr> impls;
    mutable std::mutex mutex;

    std::atomic<const DateLUTImpl *> default_impl;
};

inline UInt64 timeInMilliseconds(std::chrono::time_point<std::chrono::system_clock> timepoint)
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(timepoint.time_since_epoch()).count();
}

inline UInt64 timeInMicroseconds(std::chrono::time_point<std::chrono::system_clock> timepoint)
{
    return std::chrono::duration_cast<std::chrono::microseconds>(timepoint.time_since_epoch()).count();
}

inline UInt64 timeInSeconds(std::chrono::time_point<std::chrono::system_clock> timepoint)
{
    return std::chrono::duration_cast<std::chrono::seconds>(timepoint.time_since_epoch()).count();
}

inline UInt64 timeInNanoseconds(std::chrono::time_point<std::chrono::system_clock> timepoint)
{
    return std::chrono::duration_cast<std::chrono::nanoseconds>(timepoint.time_since_epoch()).count();
}
